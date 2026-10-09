"""سلسلة الحفظ المشفرة (Custody Hash Chain)

كل إدخال يحمل:
    previous_hash = hash الإدخال السابق في نفس البلاغ
    current_hash  = SHA-256(previous_hash + report_id + action + actor + notes + timestamp)

أي تعديل تاريخي (حتى حرف واحد) يكسر كل السلسلة اللاحقة — ويكشفه verify_chain.

ملاحظة تقنية: SQLite يفقد timezone عند الـ roundtrip (aware → naive)،
لذا _normalize_ts توحّد الطابع الزمني إلى UTC-naive قبل الهاش —
ضمان أن hash الإنشاء = hash التحقق عبر أي قاعدة بيانات.
"""
import hashlib
from datetime import datetime, timezone

from sqlalchemy.orm import Session

from app.models.report import CustodyEntry, Report


def _normalize_ts(ts: datetime) -> str:
    """UTC-naive isoformat موحّد — مستقر عبر roundtrip قاعدة البيانات"""
    if ts.tzinfo is not None:
        ts = ts.astimezone(timezone.utc).replace(tzinfo=None)
    return ts.isoformat()


def _entry_hash(
    report_id: str,
    action: str,
    actor: str,
    notes: str | None,
    timestamp_iso: str,
    previous_hash: str,
) -> str:
    payload = "|".join(
        [
            previous_hash or "",
            report_id,
            action,
            actor,
            notes or "",
            timestamp_iso,
        ]
    )
    return hashlib.sha256(payload.encode()).hexdigest()


def append_custody_entry(
    db: Session,
    report_id: str,
    action: str,
    actor: str,
    notes: str | None = None,
) -> CustodyEntry:
    """الطريقة الوحيدة لإنشاء إدخال حفظ — تضمن تماسك السلسلة"""
    last = (
        db.query(CustodyEntry)
        .filter(CustodyEntry.report_id == report_id)
        .order_by(CustodyEntry.timestamp.desc(), CustodyEntry.id.desc())
        .first()
    )
    previous_hash = last.current_hash if last else None

    entry = CustodyEntry(
        report_id=report_id,
        action=action,
        actor=actor,
        notes=notes,
    )
    db.add(entry)
    db.flush()  # يولّد id + created_at
    entry.previous_hash = previous_hash
    entry.current_hash = _entry_hash(
        report_id=report_id,
        action=entry.action,
        actor=entry.actor,
        notes=entry.notes,
        timestamp_iso=_normalize_ts(entry.timestamp),
        previous_hash=previous_hash,
    )
    db.flush()
    return entry


def verify_chain(db: Session, report_id: str) -> tuple[bool, list[dict]]:
    """المشي على السلسلة وإعادة حساب كل هاش — يُعيد (سليمة؟، تفاصيل الإدخالات)"""
    entries = (
        db.query(CustodyEntry)
        .filter(CustodyEntry.report_id == report_id)
        .order_by(CustodyEntry.timestamp.asc(), CustodyEntry.id.asc())
        .all()
    )

    previous: str | None = None
    all_valid = True
    details: list[dict] = []

    for entry in entries:
        expected_hash = _entry_hash(
            report_id=entry.report_id,
            action=entry.action,
            actor=entry.actor,
            notes=entry.notes,
            timestamp_iso=_normalize_ts(entry.timestamp),
            previous_hash=previous,
        )
        entry_valid = (
            entry.previous_hash == previous
            and entry.current_hash == expected_hash
        )
        if not entry_valid:
            all_valid = False

        details.append(
            {
                "action": entry.action,
                "actor": entry.actor,
                "timestamp": entry.timestamp.isoformat(),
                "previous_hash": entry.previous_hash,
                "current_hash": entry.current_hash,
                "valid": entry_valid,
            }
        )
        previous = entry.current_hash

    return all_valid, details
