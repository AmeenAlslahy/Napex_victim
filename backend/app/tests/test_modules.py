"""اختبارات الموديولات التشغيلية: جنائي، قانوني، سحابي، ضحية، حظر"""
import itertools

from app.tests.conftest import (
    dashboard_token,
    make_report,
    register_and_verify,
)

_counter = itertools.count(1)


def _staff(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def _setup_report_with_victim(client) -> tuple[str, str, str]:
    """بلاغ مضبوط بأرقام فريدة لكل استدعاء → (report_id, توكن الضحية, sender_hash)"""
    n = next(_counter)
    phone = f"+9677780{n:05d}"
    local_id = f"local-ops-{n}"
    sender_hash = f"hash-ops-{n}"

    tokens = register_and_verify(client, phone)
    submitted = client.post(
        "/api/v1/reports",
        json=make_report(local_id, sender_hash=sender_hash),
        headers={"Authorization": f"Bearer {tokens['access_token']}"},
    ).json()
    return submitted["id"], tokens["access_token"], sender_hash


def _investigator_headers(client) -> dict:
    token = dashboard_token(client, "+967000000001", "Inv@123")
    return _staff(token)


# ============ الموديول الجنائي ============

def test_forensic_full_workflow_and_victim_notification(client):
    report_id, _, _ = _setup_report_with_victim(client)
    headers = _investigator_headers(client)

    # فتح القضية
    created = client.post(
        "/api/v1/forensic/cases",
        json={"report_id": report_id},
        headers=headers,
    )
    assert created.status_code == 201, created.text
    case = created.json()
    assert case["case_number"].startswith("FC-")
    assert case["status"] == "opened"

    # الضبط → التصوير → الاستخراج → الحذف الآمن
    seized = client.post(
        f"/api/v1/forensic/cases/{case['id']}/seize",
        json={
            "device_type": "phone",
            "device_identifier": "IMEI-123456",
            "seizure_location": "صنعاء",
            "officers": "العميل أحمد، العميل خالد",
        },
        headers=headers,
    )
    assert seized.status_code == 200
    assert seized.json()["status"] == "seized"

    imaged = client.post(
        f"/api/v1/forensic/cases/{case['id']}/image",
        json={"imaging_tool": "Cellebrite UFED", "image_hash": "a" * 64},
        headers=headers,
    )
    assert imaged.status_code == 200

    # التصوير قبل الضبط مرفوض
    fresh = client.post(
        "/api/v1/forensic/cases",
        json={"report_id": None},
        headers=headers,
    ).json()
    early_image = client.post(
        f"/api/v1/forensic/cases/{fresh['id']}/image",
        json={"imaging_tool": "FTK", "image_hash": "b" * 64},
        headers=headers,
    )
    assert early_image.status_code == 422

    extracted = client.post(
        f"/api/v1/forensic/cases/{case['id']}/extract",
        json={"extracted_files_count": 12, "notes": "صور وفيديوهات"},
        headers=headers,
    )
    assert extracted.status_code == 200

    erased = client.post(
        f"/api/v1/forensic/cases/{case['id']}/erase",
        json={"erase_method": "DOD 5220.22-M", "verification_hash": "c" * 64},
        headers=headers,
    )
    assert erased.status_code == 200
    assert erased.json()["status"] == "erased"

    report_summary = client.get(
        f"/api/v1/forensic/cases/{case['id']}/report", headers=headers
    )
    assert report_summary.status_code == 200
    workflow = report_summary.json()["workflow"]
    assert workflow == {
        "seized": True,
        "imaged": True,
        "extracted": True,
        "erased": True,
    }


def test_victim_gets_auto_notifications_and_reads_them(client):
    report_id, victim_token, _ = _setup_report_with_victim(client)
    headers = _investigator_headers(client)

    case = client.post(
        "/api/v1/forensic/cases",
        json={"report_id": report_id},
        headers=headers,
    ).json()
    client.post(
        f"/api/v1/forensic/cases/{case['id']}/seize",
        json={
            "device_type": "phone",
            "device_identifier": "IMEI-99",
            "seizure_location": "عدن",
            "officers": "فريق أ",
        },
        headers=headers,
    )
    client.post(
        f"/api/v1/forensic/cases/{case['id']}/erase",
        json={"erase_method": "NIST 800-88", "verification_hash": "d" * 64},
        headers=headers,
    )

    # الضحية ترى إشعار "تم الحذف"
    notifications = client.get(
        "/api/v1/victim/notifications",
        headers={"Authorization": f"Bearer {victim_token}"},
    )
    assert notifications.status_code == 200
    items = notifications.json()
    assert any(n["type"] == "files_deleted" for n in items)

    # تعليم الإشعار كمقروء
    first = items[0]
    read = client.patch(
        f"/api/v1/victim/notifications/{first['id']}/read",
        headers={"Authorization": f"Bearer {victim_token}"},
    )
    assert read.status_code == 200
    assert read.json()["read_at"] is not None


# ============ الموديول القانوني + التكامل السحابي ============

def test_legal_order_document_and_cloud_auto_creation(client):
    report_id, _, _ = _setup_report_with_victim(client)
    headers = _investigator_headers(client)

    order = client.post(
        "/api/v1/legal/orders",
        json={
            "order_type": "takedown",
            "court_number": "الجنائية 3",
            "judge_name": "القاضي سميع",
            "target_type": "cloud",
            "related_report_id": report_id,
        },
        headers=headers,
    )
    assert order.status_code == 201
    order_data = order.json()
    assert order_data["order_number"].startswith("LO-")

    invalid_type = client.post(
        "/api/v1/legal/orders",
        json={"order_type": "hack", "court_number": "x", "judge_name": "y"},
        headers=headers,
    )
    assert invalid_type.status_code == 422

    # المستند الرسمي HTML
    document = client.get(
        f"/api/v1/legal/orders/{order_data['id']}/document", headers=headers
    )
    assert document.status_code == 200
    assert order_data["order_number"] in document.text
    assert "dir=\"rtl\"" in document.text

    # التنفيذ — هدف سحابي → طلب إزالة تلقائي
    executed = client.post(
        f"/api/v1/legal/orders/{order_data['id']}/execute",
        json={"notes": "نفذ بأمر المحكمة", "cloud_provider": "google"},
        headers=headers,
    )
    assert executed.status_code == 200
    assert executed.json()["cloud_order_number"].startswith("CO-")

    again = client.post(
        f"/api/v1/legal/orders/{order_data['id']}/execute",
        json={"notes": None},
        headers=headers,
    )
    assert again.status_code == 409

    # طلب الإزالة السحابي ظهر في القائمة
    cloud_orders = client.get("/api/v1/cloud/orders", headers=headers)
    assert cloud_orders.status_code == 200
    assert any(
        co["order_number"] == executed.json()["cloud_order_number"]
        for co in cloud_orders.json()
    )

    return cloud_orders.json()[0]["id"]


def test_cloud_order_actioned_notifies_victim(client):
    report_id, victim_token, _ = _setup_report_with_victim(client)
    headers = _investigator_headers(client)

    created = client.post(
        "/api/v1/cloud/orders",
        json={"provider": "meta", "report_id": report_id, "files_count": 3},
        headers=headers,
    )
    assert created.status_code == 201
    order_id = created.json()["id"]

    invalid_status = client.patch(
        f"/api/v1/cloud/orders/{order_id}/status",
        json={"status": "hacked"},
        headers=headers,
    )
    assert invalid_status.status_code == 422

    actioned = client.patch(
        f"/api/v1/cloud/orders/{order_id}/status",
        json={"status": "actioned", "notes": "أكملت ميتا الإزالة"},
        headers=headers,
    )
    assert actioned.status_code == 200

    victim_notifications = client.get(
        "/api/v1/victim/notifications",
        headers={"Authorization": f"Bearer {victim_token}"},
    ).json()
    assert any(n["type"] == "cloud_cleaned" for n in victim_notifications)


# ============ قائمة الحظر ============

def test_blocklist_add_from_report_sync_and_deactivate(client):
    report_id, victim_token, sender_hash = _setup_report_with_victim(client)
    headers = _investigator_headers(client)

    added = client.post(
        "/api/v1/blocklist",
        json={"related_report_id": report_id, "reason": "convicted_extortion"},
        headers=headers,
    )
    assert added.status_code == 201, added.text
    entry = added.json()
    assert entry["sender_hash"] == sender_hash

    duplicate = client.post(
        "/api/v1/blocklist",
        json={"sender_hash": sender_hash},
        headers=headers,
    )
    assert duplicate.status_code == 409

    # الضحية (أي مستخدم مصادق) يزامن القائمة
    synced = client.get(
        "/api/v1/blocklist",
        headers={"Authorization": f"Bearer {victim_token}"},
    )
    assert synced.status_code == 200
    assert any(e["id"] == entry["id"] for e in synced.json())

    # الإيقاف يخفيها من المزامنة
    deactivated = client.delete(
        f"/api/v1/blocklist/{entry['id']}", headers=headers
    )
    assert deactivated.status_code == 200
    synced_after = client.get(
        "/api/v1/blocklist",
        headers={"Authorization": f"Bearer {victim_token}"},
    ).json()
    assert all(e["id"] != entry["id"] for e in synced_after)


def test_victim_cannot_use_operational_modules(client):
    tokens = register_and_verify(client, "+967778999999")
    victim_headers = {"Authorization": f"Bearer {tokens['access_token']}"}

    assert client.post("/api/v1/forensic/cases", json={}, headers=victim_headers).status_code == 403
    assert client.get("/api/v1/legal/orders", headers=victim_headers).status_code == 403
    assert client.get("/api/v1/cloud/orders", headers=victim_headers).status_code == 403
