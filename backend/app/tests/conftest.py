"""إعداد الاختبارات — قاعدة بيانات مؤقتة + عملاء مساعدون"""
import os
import tempfile
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

# يجب ضبط البيئة قبل استيراد أي وحدة من التطبيق
_TMP = tempfile.mkdtemp(prefix="napex_test_")
os.environ["DATABASE_URL"] = f"sqlite:///{_TMP}/test_napex.db"
os.environ["UPLOAD_DIR"] = str(Path(_TMP) / "uploads")
os.environ["DEV_ACCEPT_ANY_OTP"] = "true"

from app.main import app  # noqa: E402
from app.db.base import init_db  # noqa: E402
from app.db.seed import seed_dashboard_users  # noqa: E402
from app.db.base import SessionLocal  # noqa: E402

init_db()
_seed_db = SessionLocal()
try:
    seed_dashboard_users(_seed_db)
finally:
    _seed_db.close()


@pytest.fixture()
def client() -> TestClient:
    with TestClient(app) as test_client:
        yield test_client


VICTIM_PHONE = "+967771111111"


def register_and_verify(client: TestClient, phone: str) -> dict:
    """تسجيل ضحية جديدة وإرجاع توكناتها"""
    response = client.post(
        "/api/v1/auth/register",
        json={"phone_number": phone, "full_name": "ضحية اختبار"},
    )
    assert response.status_code == 200, response.text
    verify = client.post(
        "/api/v1/auth/verify-otp",
        json={"phone_number": phone, "otp": "123456"},
    )
    assert verify.status_code == 200, verify.text
    return verify.json()


def dashboard_token(client: TestClient, phone: str, password: str) -> str:
    response = client.post(
        "/api/v1/auth/login",
        json={"phone_number": phone, "password": password},
    )
    assert response.status_code == 200, response.text
    return response.json()["access_token"]


def make_report(
    local_id: str,
    sender_hash: str = "hash-A",
    phone: str | None = "+967700111222",
    content: str = "عندي صورك سأنشرها إذا ما ادفعت",
) -> dict:
    return {
        "local_id": local_id,
        "sender": {
            "raw": phone or "unknown",
            "display_name": "المبتز",
            "phone_number": phone,
            "sender_hash": sender_hash,
        },
        "content": content,
        "source_app": "com.whatsapp",
        "analysis": {
            "category": "extortion",
            "confidence": 0.92,
            "risk_level": "high",
            "is_extortion": True,
            "probabilities": {"extortion": 0.92},
            "keywords": ["عندي صورك"],
            "threat_phrases": ["عندي صورك"],
        },
        "message_timestamp": "2026-10-05T10:00:00Z",
        "created_at": "2026-10-05T10:01:00Z",
        "status": "pending",
    }
