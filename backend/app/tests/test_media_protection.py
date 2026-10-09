"""اختبارات حماية الوسائط والإنذارات القانونية"""
import io
import itertools

from PIL import Image, ImageEnhance

from app.services.media_protection import (
    embed_watermark,
    extract_watermark,
    hamming_distance,
    perceptual_hash,
    sha256_hex,
)
from app.tests.conftest import (
    dashboard_token,
    make_report,
    register_and_verify,
)

_counter = itertools.count(1)


def _png(color=(200, 30, 40), size=(300, 200)) -> bytes:
    image = Image.new("RGB", size, color)
    buffer = io.BytesIO()
    image.save(buffer, format="PNG")
    return buffer.getvalue()


def _victim(client, phone: str):
    tokens = register_and_verify(client, phone)
    headers = {"Authorization": f"Bearer {tokens['access_token']}"}
    n = next(_counter)
    report = client.post(
        "/api/v1/reports",
        json=make_report(f"local-media-{n}", sender_hash=f"hash-media-{n}"),
        headers=headers,
    ).json()
    return headers, report


def _investigator(client) -> dict:
    return {
        "Authorization": f"Bearer {dashboard_token(client, '+967000000001', 'Inv@123')}"
    }


# ============ خدمة الحماية (وحدات) ============

def test_watermark_roundtrip():
    original = _png()
    payload = {"reference": "EXT-2026-TEST", "registered_by": "inv1"}

    watermarked = embed_watermark(original, payload)
    extracted = extract_watermark(watermarked)

    assert extracted is not None
    assert extracted["reference"] == "EXT-2026-TEST"


def test_clean_image_has_no_watermark():
    assert extract_watermark(_png(color=(10, 200, 30))) is None


def test_phash_identical_image_identical_hash():
    a = perceptual_hash(_png(color=(120, 60, 30)))
    b = perceptual_hash(_png(color=(120, 60, 30)))
    assert a == b
    assert len(a) == 16


def test_phash_robust_to_mild_changes():
    from PIL import Image, ImageEnhance
    import io as _io

    base = _png(color=(90, 120, 150))
    base_img = Image.open(_io.BytesIO(base)).convert("RGB")
    brightened = ImageEnhance.Brightness(base_img).enhance(1.15)
    buf = _io.BytesIO()
    brightened.save(buf, format="PNG")

    h1 = perceptual_hash(base)
    h2 = perceptual_hash(buf.getvalue())
    assert hamming_distance(h1, h2) <= 8


def test_content_hash_differs_from_watermarked():
    from app.services.media_protection import embed_watermark as embed

    original = _png()
    marked = embed(original, {"reference": "r"})
    assert sha256_hex(original) != sha256_hex(marked)


# ============ الواجهات ============

def test_watermark_endpoint_registers_phash(client):
    headers = _investigator(client)
    response = client.post(
        "/api/v1/media/watermark",
        files={"file": ("photo.png", _png(), "image/png")},
        data={"reference": "EXT-2026-XYZ", "report_id": None},
        headers=headers,
    )
    assert response.status_code == 200
    assert response.headers["content-type"] == "image/png"
    assert len(response.headers["X-Napex-Phash"]) == 16

    # الصورة المُعادة تحمل البصمة القابلة للاستخراج
    extracted = extract_watermark(response.content)
    assert extracted is not None
    assert extracted["reference"] == "EXT-2026-XYZ"

    # سُجلت في السجل الوطني
    lookup = client.get(
        f"/api/v1/media/phash/{response.headers['X-Napex-Phash']}/lookup",
        headers=headers,
    )
    assert lookup.status_code == 200
    assert len(lookup.json()["exact"]) == 1


def test_verify_endpoint_detects_watermark_and_near_matches(client):
    headers = _investigator(client)

    first = client.post(
        "/api/v1/media/watermark",
        files={"file": ("a.png", _png((10, 10, 10)), "image/png")},
        data={"reference": "EXT-2026-CASE"},
        headers=headers,
    )

    # 1) نسخة مطابقة تماماً → البصمة تُستخرج (LSB يبقى في PNG lossless)
    verified = client.post(
        "/api/v1/media/verify",
        files={"file": ("copy.png", first.content, "image/png")},
        headers=headers,
    ).json()
    assert verified["watermark"] is not None
    assert verified["watermark"]["reference"] == "EXT-2026-CASE"
    assert verified["registry_match"] is True

    # 2) نسخة سطوعها معدّل → LSB يتشوه (فيزيائياً)، لكن aHash يطابق
    base_img = Image.open(io.BytesIO(first.content)).convert("RGB")
    brightened = ImageEnhance.Brightness(base_img).enhance(1.1)
    buf = io.BytesIO()
    brightened.save(buf, format="PNG")

    verified2 = client.post(
        "/api/v1/media/verify",
        files={"file": ("bright.png", buf.getvalue(), "image/png")},
        headers=headers,
    ).json()
    assert verified2["phash"]
    assert verified2["registry_match"] or verified2["near_matches"]


# ============ الإنذارات القانونية ============

def test_legal_notices_documents(client):
    headers, report = _victim(client, "+967779920001")

    cease = client.get(
        f"/api/v1/reports/{report['id']}/legal-notices/cease_desist",
        headers=_investigator(client),
    )
    assert cease.status_code == 200
    assert report["report_number"] in cease.json()["document"]
    assert "توقف" in cease.json()["document"]

    notice = client.get(
        f"/api/v1/reports/{report['id']}/legal-notices/preemptive_notice",
        headers=_investigator(client),
    )
    assert notice.status_code == 200

    invalid = client.get(
        f"/api/v1/reports/{report['id']}/legal-notices/love_letter",
        headers=_investigator(client),
    )
    assert invalid.status_code == 422
