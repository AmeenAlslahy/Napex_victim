"""اختبارات المصادقة"""
from app.tests.conftest import VICTIM_PHONE, dashboard_token, register_and_verify


def test_register_returns_user(client):
    response = client.post(
        "/api/v1/auth/register",
        json={"phone_number": VICTIM_PHONE, "full_name": "سارة", "governorate": "تعز"},
    )
    assert response.status_code == 200
    user = response.json()["user"]
    assert user["phone_number"] == VICTIM_PHONE
    assert user["role"] == "victim"
    assert user["is_verified"] is False


def test_register_duplicate_rejected(client):
    register_and_verify(client, "+967772222222")
    duplicate = client.post(
        "/api/v1/auth/register",
        json={"phone_number": "+967772222222"},
    )
    assert duplicate.status_code == 409


def test_verify_otp_issues_tokens(client):
    client.post(
        "/api/v1/auth/register",
        json={"phone_number": "+967773333333"},
    )
    response = client.post(
        "/api/v1/auth/verify-otp",
        json={"phone_number": "+967773333333", "otp": "123456"},
    )
    assert response.status_code == 200
    tokens = response.json()
    assert tokens["access_token"]
    assert tokens["refresh_token"]
    assert tokens["user"]["is_verified"] is True


def test_me_requires_auth(client):
    assert client.get("/api/v1/auth/me").status_code == 401


def test_me_with_token(client):
    tokens = register_and_verify(client, "+967774444444")
    me = client.get(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {tokens['access_token']}"},
    )
    assert me.status_code == 200
    assert me.json()["phone_number"] == "+967774444444"


def test_dashboard_login_seeded_admin(client):
    token = dashboard_token(client, "+967000000000", "Admin@123")
    assert token
    me = client.get(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert me.status_code == 200
    assert me.json()["role"] == "admin"


def test_login_wrong_password(client):
    response = client.post(
        "/api/v1/auth/login",
        json={"phone_number": "+967000000000", "password": "wrong"},
    )
    assert response.status_code == 401


def test_refresh_flow(client):
    tokens = register_and_verify(client, "+967775555555")
    refreshed = client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": tokens["refresh_token"]},
    )
    assert refreshed.status_code == 200
    assert refreshed.json()["access_token"]
