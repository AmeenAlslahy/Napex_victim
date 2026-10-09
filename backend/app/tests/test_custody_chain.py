"""اختبارات سلسلة الحفظ المشفرة وختم البلوكشين"""
import itertools

from app.services.custody_chain import verify_chain
from app.tests.conftest import (
    dashboard_token,
    make_report,
    register_and_verify,
)

_counter = itertools.count(1)


def _victim(client, phone: str):
    tokens = register_and_verify(client, phone)
    headers = {"Authorization": f"Bearer {tokens['access_token']}"}
    n = next(_counter)
    report = client.post(
        "/api/v1/reports",
        json=make_report(f"local-chain-{n}", sender_hash=f"hash-chain-{n}"),
        headers=headers,
    ).json()
    return headers, report


def _investigator(client) -> dict:
    token = dashboard_token(client, "+967000000001", "Inv@123")
    return {"Authorization": f"Bearer {token}"}


def test_custody_chain_valid_after_status_change(client):
    headers, report = _victim(client, "+967779800001")

    # تغيير حالة يضيف إدخالاً ثانياً في السلسلة
    client.patch(
        f"/api/v1/reports/{report['id']}/status",
        json={"status": "under_review"},
        headers=_investigator(client),
    )

    verified = client.get(
        f"/api/v1/reports/{report['id']}/custody-verify",
        headers=_investigator(client),
    )
    assert verified.status_code == 200
    body = verified.json()
    assert body["valid"] is True
    assert body["entries_count"] == 2

    # السلسلة متسلسلة: previous_hash لكل إدخال = current_hash السابق
    entries = body["entries"]
    assert entries[1]["previous_hash"] == entries[0]["current_hash"]


def test_tampering_breaks_chain(client):
    headers, report = _victim(client, "+967779800002")

    from app.db.base import SessionLocal

    # تلاعب مباشر في قاعدة البيانات: تعديل ملاحظة إدخال موثق **لهذا البلاغ**
    db = SessionLocal()
    try:
        from app.models.report import CustodyEntry

        entry = (
            db.query(CustodyEntry)
            .filter(CustodyEntry.report_id == report["id"])
            .first()
        )
        entry.notes = "ملاحظة معدّلة بعد الحقيقة"
        db.commit()
    finally:
        db.close()

    verified = client.get(
        f"/api/v1/reports/{report['id']}/custody-verify",
        headers=_investigator(client),
    ).json()
    assert verified["valid"] is False


def test_anchor_offline_merkle_then_status(client):
    headers, report = _victim(client, "+967779800003")

    anchored = client.post(
        "/api/v1/forensic/anchor",
        json={"report_id": report["id"]},
        headers=_investigator(client),
    )
    assert anchored.status_code == 201, anchored.text
    body = anchored.json()
    assert body["chain"] == "offline-merkle"  # بلا RPC — وضع Merkle المحلي
    assert len(body["merkle_root"]) == 64
    assert body["entries_count"] >= 1

    # ختم مكرر مرفوض
    duplicate = client.post(
        "/api/v1/forensic/anchor",
        json={"report_id": report["id"]},
        headers=_investigator(client),
    )
    assert duplicate.status_code == 409

    # سجل الختم موجود
    status = client.get(
        f"/api/v1/forensic/anchor/{report['id']}",
        headers=_investigator(client),
    )
    assert status.status_code == 200
    assert status.json()["merkle_root"] == body["merkle_root"]


def test_anchor_requires_valid_chain(client):
    headers, report = _victim(client, "+967779800004")

    from app.db.base import SessionLocal

    # تلاعب قبل الختم → الختم مرفوض
    db = SessionLocal()
    try:
        from app.models.report import CustodyEntry

        entry = (
            db.query(CustodyEntry)
            .filter(CustodyEntry.report_id == report["id"])
            .first()
        )
        entry.actor = "ممثل منتحل"
        db.commit()
    finally:
        db.close()

    rejected = client.post(
        "/api/v1/forensic/anchor",
        json={"report_id": report["id"]},
        headers=_investigator(client),
    )
    assert rejected.status_code == 422
