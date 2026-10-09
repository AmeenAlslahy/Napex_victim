"""إدارة القضايا — الربط التلقائي للبلاغات + التنبيه الاستباقي"""
from datetime import datetime

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models.case import Case, CaseNote, CaseUpdate, generate_case_number
from app.models.report import Report
from app.services.notify import manager

# عتبات التنبيه الاستباقي (تطابق تحليل الأنماط)
PROFESSIONAL_MIN_VICTIMS = 2
PROFESSIONAL_MIN_REPORTS = 4


def count_victims(db: Session, sender_hash: str) -> int:
    return (
        db.query(func.count(func.distinct(Report.victim_id)))
        .filter(Report.sender_hash == sender_hash, Report.victim_id.isnot(None))
        .scalar()
        or 0
    )


def is_professional(db: Session, sender_hash: str) -> tuple[int, int]:
    """يُعيد (عدد الضحايا، عدد البلاغات) للمرسل"""
    reports_count = (
        db.query(func.count(Report.id))
        .filter(Report.sender_hash == sender_hash)
        .scalar()
        or 0
    )
    victims_count = count_victims(db, sender_hash)
    return victims_count, reports_count


def auto_link_report(db: Session, report: Report) -> Case | None:
    """ربط البلاغ تلقائياً بقضية نشطة بنفس sender_hash — يُحدّث العدّادات"""
    if not report.sender_hash or report.case_id:
        return None

    case = (
        db.query(Case)
        .join(Report, Report.case_id == Case.id)
        .filter(
            Report.sender_hash == report.sender_hash,
            Case.status.in_(("open", "investigating")),
            Case.deleted_at.is_(None),
        )
        .first()
    )
    if case is None:
        return None

    report.case_id = case.id
    db.flush()  # تأكيد الربط قبل احتساب العدّادات (الجلسة بلا autoflush)
    case.reports_count = (
        db.query(func.count(Report.id)).filter(Report.case_id == case.id).scalar()
        or 0
    )
    case.victims_count = count_victims(db, report.sender_hash)
    case.updated_at = datetime.utcnow()
    return case


def maybe_create_case_for_professional(db: Session, report: Report) -> Case | None:
    """إن كان المرسل «محترفاً» وبلا قضية نشطة — أنشئ قضية تلقائياً
    واربط **كل** بلاغاته السابقة غير المرتبطة بها (تجميع الحملة بأثر رجعي)"""
    victims, reports_n = is_professional(db, report.sender_hash or "")
    if not (victims >= PROFESSIONAL_MIN_VICTIMS or reports_n >= PROFESSIONAL_MIN_REPORTS):
        return None

    case = Case(
        case_number=generate_case_number(),
        title=f"قضية ابتزاز جماعي — {report.sender_display or report.sender_raw}",
        description=f"أُنشئت تلقائياً: {victims} ضحية، {reports_n} بلاغ",
        category=report.category,
        priority="critical" if victims >= 3 else "high",
        primary_victim_id=report.victim_id,
        created_by=None,
    )
    db.add(case)
    db.flush()

    # ربط بأثر رجعي: كل بلاغات المرسل السابقة غير المرتبطة
    db.query(Report).filter(
        Report.sender_hash == report.sender_hash,
        Report.case_id.is_(None),
    ).update({Report.case_id: case.id}, synchronize_session=False)
    report.case_id = case.id
    db.flush()

    case.reports_count = (
        db.query(func.count(Report.id)).filter(Report.case_id == case.id).scalar()
        or 0
    )
    case.victims_count = count_victims(db, report.sender_hash)
    return case


def on_report_received(db: Session, report: Report) -> dict | None:
    """تُستدعى بعد حفظ البلاغ: ربط تلقائي + إنشاء قضية للمحترفين

    يُعيد معلومات التنبيه **مرة واحدة فقط** عند لحظة اكتشاف المحترف
    (إنشاء القضية التلقائي) — البلاغات اللاحقة على نفس القضية لا تُنبه مجدداً.
    """
    from app.models.audit import AuditLog

    case = auto_link_report(db, report)
    newly_created_case: Case | None = None
    if case is None:
        newly_created_case = maybe_create_case_for_professional(db, report)
        case = newly_created_case

    if case is not None:
        db.add(
            AuditLog(
                actor="system",
                action="report_case_linked",
                entity_type="report",
                entity_id=report.id,
                details={"case_number": case.case_number},
            )
        )

    # التنبيه الاستباقي — مرة واحدة عند لحظة اكتشاف المحترف
    if newly_created_case is None:
        return None

    victims, reports_n = is_professional(db, report.sender_hash or "")
    db.add(
        AuditLog(
            actor="system",
            action="pattern_alert_raised",
            entity_type="report",
            entity_id=report.id,
            severity="warning",
            details={
                "sender_hash": report.sender_hash,
                "victims": victims,
                "reports": reports_n,
            },
        )
    )
    return {
        "sender_hash": report.sender_hash,
        "victims": victims,
        "reports": reports_n,
        "case_number": case.case_number,
    }


def broadcast_pattern_alert_payload(alert: dict, report: Report) -> dict:
    return {
        "type": "pattern_alert",
        "sender_hash": alert.get("sender_hash"),
        "victims": alert.get("victims"),
        "reports": alert.get("reports"),
        "case_number": alert.get("case_number"),
        "report_number": report.report_number,
    }
