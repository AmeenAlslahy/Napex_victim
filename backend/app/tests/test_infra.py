"""اختبارات مخزن OTP ونقطة الاحتفاظ"""
import time

from app.services.otp_store import MemoryOtpStore, create_otp_store, generate_otp


def test_otp_store_roundtrip():
    store = MemoryOtpStore()
    store.set("+967770000001", "123456", ttl_seconds=60)

    assert store.verify("+967770000001", "123456") is True
    assert store.verify("+967770000001", "654321") is False
    assert store.verify("+967770000999", "123456") is False


def test_otp_store_expires():
    store = MemoryOtpStore()
    store.set("+967770000002", "654321", ttl_seconds=0)
    time.sleep(0.01)
    assert store.verify("+967770000002", "654321") is False


def test_otp_store_pop_removes():
    store = MemoryOtpStore()
    store.set("+967770000003", "111222", ttl_seconds=60)
    store.pop("+967770000003")
    assert store.verify("+967770000003", "111222") is False


def test_generate_otp_format():
    code = generate_otp()
    assert len(code) == 6
    assert code.isdigit()


def test_retention_endpoint_admin_only_and_runs(client):
    # الضحية ممنوعة
    tokens = register_and_verify_local(client, "+967779970001")
    victim_headers = {"Authorization": f"Bearer {tokens['access_token']}"}
    assert (
        client.post("/api/v1/admin/system/retention", headers=victim_headers).status_code
        == 403
    )

    # المدير يشغّلها وتُعيد العدّادات
    from app.tests.conftest import dashboard_token

    admin = {"Authorization": f"Bearer {dashboard_token(client, '+967000000000', 'Admin@123')}"}
    result = client.post("/api/v1/admin/system/retention", headers=admin)
    assert result.status_code == 200
    body = result.json()
    assert "archived_reports" in body
    assert "purged_audit_logs" in body
    assert "purged_notifications" in body


def register_and_verify_local(client, phone: str):
    from app.tests.conftest import register_and_verify

    return register_and_verify(client, phone)
