"""اختبارات البلاغات والأدلة"""
import hashlib

from app.tests.conftest import dashboard_token, make_report, register_and_verify


def _victim_headers(client, phone: str) -> dict:
    tokens = register_and_verify(client, phone)
    return {"Authorization": f"Bearer {tokens['access_token']}"}


def test_submit_report_returns_official_number(client):
    headers = _victim_headers(client, "+967776000001")
    response = client.post(
        "/api/v1/reports",
        json=make_report("local-1"),
        headers=headers,
    )
    assert response.status_code == 201, response.text
    data = response.json()
    assert data["report_number"].startswith("EXT-")
    assert data["status"] == "received"


def test_victim_cannot_list_reports(client):
    headers = _victim_headers(client, "+967776000002")
    response = client.get("/api/v1/reports", headers=headers)
    assert response.status_code == 403


def test_investigator_can_list_and_filter(client):
    headers = _victim_headers(client, "+967776000003")
    client.post("/api/v1/reports", json=make_report("local-3"), headers=headers)

    investigator = {
        "Authorization": dashboard_token_header(
            client, "+967000000001", "Inv@123"
        )
    }
    listed = client.get("/api/v1/reports", headers=investigator)
    assert listed.status_code == 200
    body = listed.json()
    assert body["total"] >= 1
    assert any(item["local_id"] == "local-3" for item in body["items"])

    filtered = client.get(
        "/api/v1/reports",
        params={"status": "received", "q": "ادفعت"},
        headers=investigator,
    )
    assert filtered.status_code == 200
    assert filtered.json()["total"] >= 1


def dashboard_token_header(client, phone: str, password: str) -> str:
    from app.tests.conftest import dashboard_token

    return f"Bearer {dashboard_token(client, phone, password)}"


def test_report_detail_includes_custody(client):
    headers = _victim_headers(client, "+967776000004")
    submitted = client.post(
        "/api/v1/reports", json=make_report("local-4"), headers=headers
    ).json()

    investigator = {
        "Authorization": dashboard_token_header(
            client, "+967000000001", "Inv@123"
        )
    }
    detail = client.get(
        f"/api/v1/reports/{submitted['id']}", headers=investigator
    )
    assert detail.status_code == 200
    body = detail.json()
    actions = [entry["action"] for entry in body["custody"]]
    assert "received_from_device" in actions


def test_status_update_by_supervisor(client):
    headers = _victim_headers(client, "+967776000005")
    submitted = client.post(
        "/api/v1/reports", json=make_report("local-5"), headers=headers
    ).json()

    supervisor = {
        "Authorization": dashboard_token_header(
            client, "+967000000002", "Sup@123"
        )
    }
    updated = client.patch(
        f"/api/v1/reports/{submitted['id']}/status",
        json={"status": "under_review", "note": "بدأ الفحص"},
        headers=supervisor,
    )
    assert updated.status_code == 200
    assert updated.json()["status"] == "under_review"

    invalid = client.patch(
        f"/api/v1/reports/{submitted['id']}/status",
        json={"status": "not-a-status"},
        headers=supervisor,
    )
    assert invalid.status_code == 422


def test_evidence_upload_with_hash_verification(client):
    headers = _victim_headers(client, "+967776000006")
    submitted = client.post(
        "/api/v1/reports", json=make_report("local-6"), headers=headers
    ).json()

    evidence_bytes = b"NAP-EX encrypted evidence payload"
    file_hash = hashlib.sha256(evidence_bytes).hexdigest()

    upload = client.post(
        "/api/v1/evidence/upload",
        data={"report_id": submitted["id"], "file_hash": file_hash},
        files={"file": ("evidence.bin", evidence_bytes, "application/octet-stream")},
        headers=headers,
    )
    assert upload.status_code == 201, upload.text
    assert upload.json()["verified"] is True

    # هاش خاطئ → يُخزن الدليل لكن بلا علامة التحقق
    tampered = client.post(
        "/api/v1/evidence/upload",
        data={"report_id": submitted["id"], "file_hash": "0" * 64},
        files={"file": ("bad.bin", evidence_bytes, "application/octet-stream")},
        headers=headers,
    )
    assert tampered.status_code == 201
    assert tampered.json()["verified"] is False

    # المحقق يستطيع التنزيل
    investigator = {
        "Authorization": dashboard_token_header(
            client, "+967000000001", "Inv@123"
        )
    }
    download = client.get(
        f"/api/v1/evidence/{upload.json()['id']}", headers=investigator
    )
    assert download.status_code == 200
    assert download.content == evidence_bytes
