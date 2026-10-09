"""سياسة الاحتفاظ والتنظيف — تعمل يدوياً من الإدارة أو مجدولة لاحقاً

- البلاغات المغلقة أقدم من N سنوات → soft delete (archived)
- audit_logs أقدم من 7 سنوات → حذف
- إشعارات الضحية المقروءة أقدم من سنة → حذف
"""
from datetime import datetime, timedelta

from sqlalchemy.orm import Session

from app.models.audit import AuditLog
from app.models.report import Report
from app.models.victim import VictimNotification


def archive_closed_reports(db: Session, years: int = 5) -> int:
    """Soft-delete للبلاغات المغلقة القديمة (أرشفة منطقية)"""
    cutoff = datetime.utcnow() - timedelta(days=365 * years)
    count = (
        db.query(Report)
        .filter(
            Report.status == "closed",
            Report.deleted_at.is_(None),
            Report.updated_at < cutoff,
        )
        .update({Report.deleted_at: datetime.utcnow()}, synchronize_session=False)
    )
    db.commit()
    return count


def cleanup_audit_logs(db: Session, years: int = 7) -> int:
    cutoff = datetime.utcnow() - timedelta(days=365 * years)
    count = (
        db.query(AuditLog)
        .filter(AuditLog.created_at < cutoff)
        .delete(synchronize_session=False)
    )
    db.commit()
    return count


def cleanup_old_notifications(db: Session, days: int = 365) -> int:
    cutoff = datetime.utcnow() - timedelta(days=days)
    count = (
        db.query(VictimNotification)
        .filter(
            VictimNotification.read_at.isnot(None),
            VictimNotification.created_at < cutoff,
        )
        .delete(synchronize_session=False)
    )
    db.commit()
    return count


def run_all(db: Session) -> dict:
    return {
        "archived_reports": archive_closed_reports(db),
        "purged_audit_logs": cleanup_audit_logs(db),
        "purged_notifications": cleanup_old_notifications(db),
        "ran_at": datetime.utcnow().isoformat(),
    }
