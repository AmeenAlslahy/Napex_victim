"""اختبارات القضايا الموحدة: إنشاء، ربط تلقائي، تنبيه المحترفين، ملاحظات وتحديثات"""
import itertools

from app.tests.conftest import (
    dashboard_token,
    make_report,
    register_and_verify,
)

_counter = itertools.count(1)


def _staff(client, phone: str, password: str) -> dict:
    return {
        "Authorization": f"Bearer {dashboard_token(client, phone, password)}"
    }


def _admin(client) -> dict:
    return _staff(client, "+967000000000", "Admin@123")


def _investigator(client) -> dict:
    return _staff(client, "+967000000001", "Inv@123")


def _submit(client, phone: str, sender_hash: str) -> dict:
    tokens = register_and_verify(client, phone)
    return client.post(
        "/api/v1/reports",
        json=make_report(
            f"local-case-{next(_counter)}", sender_hash=sender_hash
        ),
        headers={"Authorization": f"Bearer {tokens['access_token']}"},
    ).json()


def test_create_case_and_attach_reports(client):
    n = next(_counter)
    victim_phone = f"+9677740{n:05d}"
    tokens = register_and_verify(client, victim_phone)
    report = client.post(
        "/api/v1/reports",
        json=make_report(f"local-cm-{n}", sender_hash=f"hash-cm-{n}"),
        headers={"Authorization": f"Bearer {tokens['access_token']}"},
    ).json()

    headers = _investigator(client)
    created = client.post(
        "/api/v1/cases",
        json={
            "title": "قضية ابتزاز مالي",
            "report_id": report["id"],
            "priority": "high",
        },
        headers=headers,
    )
    assert created.status_code == 201, created.text
    case = created.json()
    assert case["case_number"].startswith("CASE-")
    assert case["reports_count"] == 1
    assert case["primary_victim_id"] is not None

    # إرفاق بلاغ ثانٍ يدوياً
    other_tokens = register_and_verify(client, f"+9677741{n:05d}")
    other_report = client.post(
        "/api/v1/reports",
        json=make_report(f"local-cm2-{n}", sender_hash=f"hash-other-{n}"),
        headers={"Authorization": f"Bearer {other_tokens['access_token']}"},
    ).json()
    attached = client.post(
        f"/api/v1/cases/{case['id']}/reports",
        json={"report_id": other_report["id"]},
        headers=headers,
    )
    assert attached.status_code == 200
    assert attached.json()["reports_count"] == 2


def test_auto_link_report_to_active_case(client):
    n = next(_counter)
    sender_hash = f"hash-auto-{n}"

    tokens = register_and_verify(client, f"+9677742{n:05d}")
    first = client.post(
        "/api/v1/reports",
        json=make_report(f"local-auto-{n}-a", sender_hash=sender_hash),
        headers={"Authorization": f"Bearer {tokens['access_token']}"},
    ).json()

    headers = _investigator(client)
    case = client.post(
        "/api/v1/cases",
        json={"title": "قضية الربط التلقائي", "report_id": first["id"]},
        headers=headers,
    ).json()

    # بلاغ جديد بنفس المرسل → يُربط تلقائياً بالقضية النشطة
    tokens_b = register_and_verify(client, f"+9677743{n:05d}")
    client.post(
        "/api/v1/reports",
        json=make_report(f"local-auto-{n}-b", sender_hash=sender_hash),
        headers={"Authorization": f"Bearer {tokens_b['access_token']}"},
    )

    detail = client.get(f"/api/v1/cases/{case['id']}", headers=headers).json()
    assert detail["reports_count"] == 2


def test_professional_sender_triggers_auto_case_and_alert(client):
    n = next(_counter)
    sender_hash = f"hash-pro-{n}"

    # ضحية أولى: بلاغان
    tokens_a = register_and_verify(client, f"+9677744{n:05d}")
    for suffix in ("a", "b"):
        client.post(
            "/api/v1/reports",
            json=make_report(f"local-pro-{n}-{suffix}", sender_hash=sender_hash),
            headers={"Authorization": f"Bearer {tokens_a['access_token']}"},
        )

    # ضحية ثانية: بلاغان → 2 ضحايا و 4 بلاغات = محترف
    tokens_b = register_and_verify(client, f"+9677745{n:05d}")
    for suffix in ("c", "d"):
        response = client.post(
            "/api/v1/reports",
            json=make_report(f"local-pro-{n}-{suffix}", sender_hash=sender_hash),
            headers={"Authorization": f"Bearer {tokens_b['access_token']}"},
        )
        assert response.status_code == 201

    headers = _investigator(client)

    # تنبيه النمط سُجل في audit (للمدير فقط)
    audit = client.get(
        "/api/v1/admin/audit",
        params={"action": "pattern_alert_raised"},
        headers=_admin(client),
    )
    assert audit.status_code == 200
    assert any(
        log["details"] and log["details"].get("sender_hash") == sender_hash
        for log in audit.json()
    )

    # قضية أُنشئت تلقائياً للمحترف (2 ضحايا و 4 بلاغات)
    cases = client.get("/api/v1/cases", headers=headers).json()
    auto_case = next(
        c
        for c in cases["items"]
        if c["victims_count"] == 2 and c["reports_count"] == 4
    )
    assert auto_case["priority"] in ("high", "critical")


def test_notes_updates_and_status_workflow(client):
    n = next(_counter)
    tokens = register_and_verify(client, f"+9677746{n:05d}")
    report = client.post(
        "/api/v1/reports",
        json=make_report(f"local-flow-{n}", sender_hash=f"hash-flow-{n}"),
        headers={"Authorization": f"Bearer {tokens['access_token']}"},
    ).json()
    headers = _investigator(client)

    case = client.post(
        "/api/v1/cases",
        json={"title": "قضية سير العمل", "report_id": report["id"]},
        headers=headers,
    ).json()

    # ملاحظة
    note = client.post(
        f"/api/v1/cases/{case['id']}/notes",
        json={"content": "تمت مقابلة الضحية", "is_internal": True},
        headers=headers,
    )
    assert note.status_code == 201

    # تحديث + إشعار الضحية
    update = client.post(
        f"/api/v1/cases/{case['id']}/updates",
        json={
            "type": "case_update",
            "title": "بدأ التحقيق",
            "message": "تم إسناد قضيتك لمحقق مختص",
            "notify_victim": True,
        },
        headers=headers,
    )
    assert update.status_code == 201

    victim_notifications = client.get(
        "/api/v1/victim/notifications",
        headers={
            "Authorization": (
                f"Bearer {register_and_verify(client, '+967774700001')['access_token']}"
            )
        },
    )
    # الضحية الأصلية (tokens) ترى الإشعار — نتحقق بتوكن الضحية الأصلية
    victim_headers = {"Authorization": f"Bearer {tokens['access_token']}"}
    victim_items = client.get(
        "/api/v1/victim/notifications", headers=victim_headers
    ).json()
    assert any(u["title"] == "بدأ التحقيق" for u in victim_items)

    # إسناد + حالة
    patched = client.patch(
        f"/api/v1/cases/{case['id']}",
        json={"status": "investigating", "priority": "high"},
        headers=headers,
    )
    assert patched.status_code == 200
    assert patched.json()["status"] == "investigating"

    invalid = client.patch(
        f"/api/v1/cases/{case['id']}",
        json={"status": "under_the_bed"},
        headers=headers,
    )
    assert invalid.status_code == 422


def test_case_soft_delete_supervisor_only(client):
    n = next(_counter)
    tokens = register_and_verify(client, f"+9677748{n:05d}")
    report = client.post(
        "/api/v1/reports",
        json=make_report(f"local-del-{n}", sender_hash=f"hash-del-{n}"),
        headers={"Authorization": f"Bearer {tokens['access_token']}"},
    ).json()
    headers = _investigator(client)
    case = client.post(
        "/api/v1/cases",
        json={"title": "قضية للحذف", "report_id": report["id"]},
        headers=headers,
    ).json()

    # المحقق لا يملك الحذف
    forbidden = client.delete(
        f"/api/v1/cases/{case['id']}", headers=headers
    )
    assert forbidden.status_code == 403

    supervisor = _staff(client, "+967000000002", "Sup@123")
    deleted = client.delete(f"/api/v1/cases/{case['id']}", headers=supervisor)
    assert deleted.status_code == 200

    assert (
        client.get(f"/api/v1/cases/{case['id']}", headers=headers).status_code
        == 404
    )
