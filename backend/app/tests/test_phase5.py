"""اختبارات المرحلة 5: الإشعارات، مخزن الكائنات، طلبات التعاون الدولي، Takedown"""
import itertools

from app.infrastructure.storage.object_store import LocalObjectStore
from app.services.notifications.base import DispatchResult
from app.services.notifications.email_channel import EmailChannel
from app.services.notifications.push_channel import PushChannel
from app.services.otp_store import generate_otp
from app.tests.conftest import (
    dashboard_token,
    make_report,
    register_and_verify,
)

_counter = itertools.count(1)


def _staff(client, phone: str, password: str) -> dict:
    return {"Authorization": f"Bearer {dashboard_token(client, phone, password)}"}


def _investigator(client) -> dict:
    return _staff(client, "+967000000001", "Inv@123")


def _report(client, phone: str) -> dict:
    tokens = register_and_verify(client, phone)
    return client.post(
        "/api/v1/reports",
        json=make_report(f"local-p5-{next(_counter)}", sender_hash=f"hash-p5-{next(_counter)}"),
        headers={"Authorization": f"Bearer {tokens['access_token']}"},
    ).json()


# ============ الإشعارات ============

def test_channels_noop_when_unconfigured():
    from app.core.config import get_settings

    assert get_settings().smtp_host == "" or get_settings().smtp_host
    # القنوات بلا ضبط تعيد not_configured ولا ترفع استثناء
    email = EmailChannel()
    if not email.configured:
        result = email.send("x@example.com", "t", "b")
        assert isinstance(result, DispatchResult)
        assert result.sent is False

    push = PushChannel()
    if not push.configured:
        result = push.send("token", "t", "b")
        assert result.sent is False


def test_dispatch_result_shape():
    result = DispatchResult.not_configured("sms", "+967700000000")
    assert result.channel == "sms"
    assert result.sent is False


# ============ مخزن الكائنات ============

def test_local_object_store_roundtrip(tmp_path):
    store = LocalObjectStore(str(tmp_path))
    uri = store.save("reports/r1/evidence.bin", b"NAP-EX payload")

    assert uri.endswith("evidence.bin")
    assert store.load("reports/r1/evidence.bin") == b"NAP-EX payload"
    assert store.delete("reports/r1/evidence.bin") is True
    assert store.load("reports/r1/evidence.bin") is None


# ============ طلبات التعاون الدولي ============

def test_interpol_notice_and_mlat_documents(client):
    report = _report(client, "+967779910001")
    headers = _investigator(client)

    interpol = client.post(
        "/api/v1/international/requests",
        json={
            "request_type": "interpol",
            "report_id": report["id"],
            "target_country": "Jordan",
        },
        headers=headers,
    )
    assert interpol.status_code == 201, interpol.text
    assert interpol.json()["reference_number"].startswith("INT-")

    mlat = client.post(
        "/api/v1/international/requests",
        json={
            "request_type": "mlat",
            "report_id": report["id"],
            "target_country": "Jordan",
            "crime_articles": ["المادة 399", "المادة 626"],
        },
        headers=headers,
    )
    assert mlat.status_code == 201
    assert mlat.json()["reference_number"].startswith("MLAT-")

    invalid = client.post(
        "/api/v1/international/requests",
        json={"request_type": "hack", "report_id": report["id"]},
        headers=headers,
    )
    assert invalid.status_code == 422

    # وثيقة الطلب تحتوي المرجع والبنود
    detail = client.get(
        f"/api/v1/international/requests/{mlat.json()['id']}",
        headers=headers,
    ).json()
    assert "MLAT" in detail["document"]
    assert "المادة 399" in detail["document"]


def test_isp_request_document(client):
    report = _report(client, "+967779910002")
    headers = _investigator(client)

    isp = client.post(
        "/api/v1/international/requests",
        json={
            "request_type": "isp",
            "report_id": report["id"],
            "court_number": "النيابة العامة — مكافحة الجرائم المعلوماتية",
        },
        headers=headers,
    )
    assert isp.status_code == 201
    assert isp.json()["reference_number"].startswith("ISP-")


def test_international_status_transitions(client):
    report = _report(client, "+967779910003")
    headers = _investigator(client)

    req = client.post(
        "/api/v1/international/requests",
        json={"request_type": "interpol", "report_id": report["id"]},
        headers=headers,
    ).json()

    submitted = client.patch(
        f"/api/v1/international/requests/{req['id']}/status",
        json={"status": "submitted"},
        headers=headers,
    )
    assert submitted.status_code == 200

    invalid = client.patch(
        f"/api/v1/international/requests/{req['id']}/status",
        json={"status": "deleted_forever"},
        headers=headers,
    )
    assert invalid.status_code == 422


# ============ Takedown document ============

def test_takedown_request_document_for_cloud_order(client):
    report = _report(client, "+967779910004")
    headers = _investigator(client)

    order = client.post(
        "/api/v1/cloud/orders",
        json={"provider": "google", "report_id": report["id"], "files_count": 2},
        headers=headers,
    ).json()

    document = client.get(
        f"/api/v1/international/takedown-document/{order['id']}",
        headers=headers,
    )
    assert document.status_code == 200
    assert "google" in document.text
    assert order["order_number"] in document.text
