"""اختبارات الامتثال والمنصة: التغذية الراجعة، الموافقات، Killswitch، المحو"""
import itertools

from app.services.classifier import classifier
from app.tests.conftest import dashboard_token, make_report, register_and_verify

_counter = itertools.count(1)


def _victim(client, phone: str):
    tokens = register_and_verify(client, phone)
    headers = {"Authorization": f"Bearer {tokens['access_token']}"}
    n = next(_counter)
    report = client.post(
        "/api/v1/reports",
        json=make_report(f"local-comp-{n}", sender_hash=f"hash-comp-{n}"),
        headers=headers,
    ).json()
    return headers, report


def _admin(client):
    token = dashboard_token(client, "+967000000000", "Admin@123")
    return {"Authorization": f"Bearer {token}"}


# ============ Feedback Loop ============

def test_feedback_retrain_adjusts_classifier_weights(client):
    headers, report = _victim(client, "+967779300001")

    # بلاغ مؤكد يحتوي كلمات → الكلمة تُقوّى
    client.post(
        f"/api/v1/reports/{report['id']}/feedback",
        json={"feedback_type": "confirmed", "extortion_kind": "financial"},
        headers=headers,
    )

    # بلاغ سوء فهم على نفس النص → الكلمة تُخفَّض أكثر من القوة
    client.post(
        f"/api/v1/reports/{report['id']}/feedback",
        json={"feedback_type": "false_positive", "reason": "عادي"},
        headers=headers,
    )

    retrained = client.post(
        "/api/v1/reports/feedback/retrain",
        json={"apply": True},
        headers=_admin(client),
    )
    assert retrained.status_code == 200, retrained.text
    body = retrained.json()
    assert body["overrides_count"] >= 1
    # -0.20 +0.15 = عامل 0.95 (أقل من 1)
    assert any(factor < 1.0 for factor in body["overrides"].values())

    # الأوزان محفوظة وقابلة للقراءة
    overrides = client.get(
        "/api/v1/reports/feedback/overrides", headers=_admin(client)
    ).json()["overrides"]
    assert overrides == body["overrides"]

    # dataset جاهز للتدريب
    dataset = client.get(
        "/api/v1/reports/feedback/dataset", headers=_admin(client)
    )
    assert dataset.status_code == 200
    rows = dataset.json()
    labels = {row["label"] for row in rows}
    assert "normal" in labels  # سوء الفهم
    # الضحية لا ترى أدوات التدريب
    assert (
        client.get(
            "/api/v1/reports/feedback/dataset",
            headers=headers,
        ).status_code
        == 403
    )


def test_classifier_override_penalizes_keyword(client):
    """التحسين يعمل فعلياً: كلمة عقوبتها 0.3 لا ترفع درجة الابتزاز لوحدها"""
    classifier.apply_overrides({"عندي صورك": 0.3})
    result = classifier.classify("عندي صورك")
    classifier.apply_overrides({})  # تنظيف

    assert result["category"] == "extortion"  # التصنيف نفسه
    # تحت عتبة البلاغ التلقائي (0.85) — معايرة k=2.6: العقوبة تُنزلها من 0.93 إلى ~0.55
    assert result["confidence"] < 0.85


# ============ الموافقات (GDPR) ============

def test_consent_management(client):
    headers, _ = _victim(client, "+967779400001")

    invalid = client.post(
        "/api/v1/me/consents",
        json={"consent_type": "marketing", "granted": True},
        headers=headers,
    )
    assert invalid.status_code == 422

    granted = client.post(
        "/api/v1/me/consents",
        json={"consent_type": "ai_training", "granted": True},
        headers=headers,
    )
    assert granted.status_code == 200
    assert granted.json()["granted"] is True
    assert granted.json()["granted_at"] is not None

    revoked = client.post(
        "/api/v1/me/consents",
        json={"consent_type": "ai_training", "granted": False},
        headers=headers,
    )
    assert revoked.status_code == 200
    assert revoked.json()["granted"] is False
    assert revoked.json()["revoked_at"] is not None

    listed = client.get("/api/v1/me/consents", headers=headers).json()
    assert any(c["consent_type"] == "ai_training" for c in listed)


# ============ Killswitch (Incident Response) ============

def test_killswitch_blocks_traffic_but_not_admin(client):
    headers, _ = _victim(client, "+967779500001")
    admin = _admin(client)

    # تفعيل
    enabled = client.post(
        "/api/v1/admin/system/killswitch",
        json={"enabled": True, "reason": "P1 — اختراق محتمل"},
        headers=admin,
    )
    assert enabled.status_code == 200

    # الصحة تعمل
    assert client.get("/health").status_code == 200

    # إدارة تعمل
    assert client.get("/api/v1/admin/audit", headers=admin).status_code == 200

    # الضحية محجوبة 503
    blocked = client.get("/api/v1/victim/notifications", headers=headers)
    assert blocked.status_code == 503
    assert blocked.json()["code"] == "KILLSWITCH_ACTIVE"

    # إلغاء التفعيل
    disabled = client.post(
        "/api/v1/admin/system/killswitch",
        json={"enabled": False},
        headers=admin,
    )
    assert disabled.status_code == 200

    # عادت الخدمة
    assert (
        client.get(
            "/api/v1/victim/notifications", headers=headers
        ).status_code
        == 200
    )


def test_killswitch_admin_only(client):
    headers, _ = _victim(client, "+967779500002")
    response = client.post(
        "/api/v1/admin/system/killswitch",
        json={"enabled": True},
        headers=headers,
    )
    assert response.status_code == 403


# ============ الحق في المحو (GDPR) ============

def test_account_erasure_anonymizes_user(client):
    phone = "+967779600001"
    tokens = register_and_verify(client, phone)
    headers = {"Authorization": f"Bearer {tokens['access_token']}"}
    report = client.post(
        "/api/v1/reports",
        json=make_report("local-erasure", sender_hash="hash-erasure"),
        headers=headers,
    ).json()

    erase = client.delete("/api/v1/auth/account", headers=headers)
    assert erase.status_code == 204

    # الحساب محايد: لا مصادقة بعد الآن
    assert (
        client.get("/api/v1/auth/me", headers=headers).status_code == 401
    )

    # البلاغ بقي (دليل قانوني) لكن مفصولاً عن الهوية
    admin = _admin(client)
    detail = client.get(f"/api/v1/reports/{report['id']}", headers=admin)
    assert detail.status_code == 200
    assert detail.json()["victim_id"] is None


def test_real_world_extortion_samples(client):
    """عينات ابتزاز دارجة واقعية — كلها يجب أن تُكشف مؤكدة (حماية من التراجع)"""
    from app.services.classifier import KeywordClassifier, _KEYWORDS_PATH

    c = KeywordClassifier()
    c.load(_KEYWORDS_PATH)

    samples = [
        "اذا ما ترسل لي 500 الف بنشر صورك واسمع بك",
        "اذا ما تنفذ اللي طلبته منه اعرف ان فضيحتك بتكون بين كل الناس",
        "معك مهله يومين والا ما تلوم الا نفسك",
        "اسمعي يابنت اذا ما ترسلي صورك وانت عارية كل شي بيوصل لعند اهلك ولعند الناس",
    ]
    for text in samples:
        result = c.classify(text)
        assert result["is_extortion"], f'لم تُكشف: {text} → {result["category"]}'
        assert result["confidence"] >= 0.85, f'ثقة منخفضة: {text}'
