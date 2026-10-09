"""اختبارات الإضافة التشغيلية: تغذية راجعة، إدارة، حظر شخصي، تصدير"""
from app.tests.conftest import (
    dashboard_token,
    make_report,
    register_and_verify,
)


def _victim(client, phone: str) -> tuple[dict, str]:
    tokens = register_and_verify(client, phone)
    headers = {"Authorization": f"Bearer {tokens['access_token']}"}
    report = client.post(
        "/api/v1/reports",
        json=make_report(f"local-prod-{phone[-3:]}", sender_hash=f"hash-{phone[-3:]}"),
        headers=headers,
    ).json()
    return headers, report["id"]


def _admin(client) -> dict:
    token = dashboard_token(client, "+967000000000", "Admin@123")
    return {"Authorization": f"Bearer {token}"}


def test_feedback_flow_and_precision_summary(client):
    headers, report_id = _victim(client, "+967779100001")

    invalid = client.post(
        f"/api/v1/reports/{report_id}/feedback",
        json={"feedback_type": "maybe"},
        headers=headers,
    )
    assert invalid.status_code == 422

    confirmed = client.post(
        f"/api/v1/reports/{report_id}/feedback",
        json={"feedback_type": "confirmed", "extortion_kind": "financial"},
        headers=headers,
    )
    assert confirmed.status_code == 201

    false_positive = client.post(
        f"/api/v1/reports/{report_id}/feedback",
        json={"feedback_type": "false_positive", "reason": "رسالة عادية"},
        headers=headers,
    )
    assert false_positive.status_code == 201

    summary = client.get(
        "/api/v1/reports/feedback/summary",
        headers=_admin(client),
    )
    assert summary.status_code == 200
    body = summary.json()
    assert body["total"] >= 2
    assert body["confirmed_precision"] == 0.5

    # الضحية لا ترى ملخص الكشف
    assert (
        client.get(
            "/api/v1/reports/feedback/summary",
            headers=headers,
        ).status_code
        == 403
    )


def test_admin_users_and_audit(client):
    headers, _ = _victim(client, "+967779100002")
    admin = _admin(client)

    users = client.get("/api/v1/admin/users", headers=admin)
    assert users.status_code == 200
    victim_entry = next(
        u for u in users.json() if u["phone_number"] == "+967779100002"
    )

    # ترقية ضحية إلى محقق
    promoted = client.patch(
        f"/api/v1/admin/users/{victim_entry['id']}/role",
        json={"role": "investigator"},
        headers=admin,
    )
    assert promoted.status_code == 200
    assert promoted.json()["role"] == "investigator"

    invalid_role = client.patch(
        f"/api/v1/admin/users/{victim_entry['id']}/role",
        json={"role": "superhacker"},
        headers=admin,
    )
    assert invalid_role.status_code == 422

    # الضحية لا تصل لإدارة المستخدمين
    assert (
        client.get("/api/v1/admin/users", headers=headers).status_code == 403
    )

    # سجل التدقيق يوثق ترقية الدور
    audit = client.get(
        "/api/v1/admin/audit",
        params={"action": "user_role_changed"},
        headers=admin,
    )
    assert audit.status_code == 200
    assert any(
        log["entity_id"] == victim_entry["id"] for log in audit.json()
    )

    deactivated = client.patch(
        f"/api/v1/admin/users/{victim_entry['id']}/deactivate",
        headers=admin,
    )
    assert deactivated.status_code == 200
    assert deactivated.json()["is_active"] is False


def test_data_export(client):
    headers, report_id = _victim(client, "+967779100003")

    # تصدير بيانات الضحية
    export = client.get("/api/v1/me/export", headers=headers)
    assert export.status_code == 200
    assert export.headers["content-type"].startswith("application/json")
    assert "napex_my_data.json" in export.headers.get("content-disposition", "")
    assert "+967779100003" in export.text or "local-prod" in export.text
