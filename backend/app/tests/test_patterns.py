"""اختبارات تحليل الأنماط والمصنّف"""
from app.tests.conftest import dashboard_token, make_report, register_and_verify


def _auth_headers(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def test_pattern_flags_professional_sender(client):
    # ضحية أولى: 3 بلاغات من نفس المبتز
    victim_a = register_and_verify(client, "+967777000001")
    for i in range(3):
        client.post(
            "/api/v1/reports",
            json=make_report(f"local-p1-{i}", sender_hash="hash-pro"),
            headers=_auth_headers(victim_a["access_token"]),
        )

    # ضحية ثانية: بلاغ من نفس المبتز → ضحيتان = محترف
    victim_b = register_and_verify(client, "+967777000002")
    client.post(
        "/api/v1/reports",
        json=make_report("local-p1-b", sender_hash="hash-pro"),
        headers=_auth_headers(victim_b["access_token"]),
    )

    investigator = _auth_headers(
        dashboard_token(client, "+967000000001", "Inv@123")
    )
    patterns = client.get("/api/v1/analysis/patterns", headers=investigator)
    assert patterns.status_code == 200

    profiles = patterns.json()
    pro = next(p for p in profiles if p["sender_key"] == "hash-pro")
    assert pro["victims"] == 2
    assert pro["reports"] == 4
    assert pro["is_professional"] is True
    assert pro["score"] >= profiles[0]["score"]  # مرتبة تنازلياً


def test_single_victim_low_count_not_professional(client):
    victim = register_and_verify(client, "+967777000003")
    client.post(
        "/api/v1/reports",
        json=make_report("local-single", sender_hash="hash-single"),
        headers=_auth_headers(victim["access_token"]),
    )

    investigator = _auth_headers(
        dashboard_token(client, "+967000000001", "Inv@123")
    )
    patterns = client.get("/api/v1/analysis/patterns", headers=investigator).json()
    single = next(p for p in patterns if p["sender_key"] == "hash-single")
    assert single["is_professional"] is False


def test_classify_extortion_text(client):
    victim = register_and_verify(client, "+967777000004")
    result = client.post(
        "/api/v1/analysis/classify",
        json={"text": "عندي صورك سأنشرها إذا ما ادفعت"},
        headers=_auth_headers(victim["access_token"]),
    ).json()
    assert result["category"] == "extortion"
    assert result["confidence"] > 0.8
    assert result["is_extortion"] is True


def test_classify_normal_text(client):
    victim = register_and_verify(client, "+967777000005")
    result = client.post(
        "/api/v1/analysis/classify",
        json={"text": "صباح الخير كيف حالك اليوم"},
        headers=_auth_headers(victim["access_token"]),
    ).json()
    assert result["category"] == "normal"
    assert result["is_extortion"] is False


def test_stats_overview(client):
    victim = register_and_verify(client, "+967777000006")
    client.post(
        "/api/v1/reports",
        json=make_report("local-stats", sender_hash="hash-stats"),
        headers=_auth_headers(victim["access_token"]),
    )

    admin = _auth_headers(dashboard_token(client, "+967000000000", "Admin@123"))
    overview = client.get("/api/v1/stats/overview", headers=admin)
    assert overview.status_code == 200
    body = overview.json()
    assert body["total_reports"] >= 1
    assert len(body["by_day"]) == 14
    assert body["total_evidences"] >= 0
    assert isinstance(body["by_status"], dict)
