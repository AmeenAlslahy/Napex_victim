"""واجهات البلاغات — استقبال من التطبيق + إدارة من لوحة التحكم"""
from datetime import datetime, timezone

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field
from sqlalchemy import or_
from sqlalchemy.orm import Session, joinedload

from app.core.deps import get_current_user, get_db, require_roles
from app.core.encrypted_field import blind_hash
from app.core.security import generate_report_number, sha256_hex
from app.models.audit import AuditLog
from app.models.report import CustodyEntry, Report
from app.models.report_feedback import ReportFeedback
from app.models.user import User
from app.schemas.report import (
    ALLOWED_STATUS_TRANSITIONS,
    ReportDetailOut,
    ReportIn,
    ReportListOut,
    ReportSubmitOut,
    StatusIn,
)
from app.services.case_manager import broadcast_pattern_alert_payload, on_report_received
from app.services.custody_chain import append_custody_entry, verify_chain
from app.services.notify import manager



router = APIRouter(prefix="/reports", tags=["reports"])

DASHBOARD_ROLES = ("admin", "supervisor", "investigator")

# ============ مقاييس الرصد (Prometheus) ============
try:
    from prometheus_client import Counter

    REPORTS_CREATED = Counter(
        "napex_reports_created_total",
        "عدد البلاغات المستلمة من الأجهزة",
    )
    FEEDBACK_SUBMITTED = Counter(
        "napex_feedback_submitted_total",
        "عدد التقييمات الواردة من الضحايا",
        ["feedback_type"],
    )
except Exception:  # pragma: no cover — احتياط إن غاب عميل prometheus
    from prometheus_client import GC_COLLECTOR  # noqa: F401

    class _Noop:
        def labels(self, *a, **k):
            return self

        def inc(self, *a, **k):
            return None

    REPORTS_CREATED = _Noop()
    FEEDBACK_SUBMITTED = _Noop()


def _naive_utc(value: datetime) -> datetime:
    """توحيد التواريخ كـ UTC-naive لتوافق SQLite"""
    if value.tzinfo is not None:
        return value.astimezone(timezone.utc).replace(tzinfo=None)
    return value


def _report_out(report: Report) -> dict:
    return {
        "id": report.id,
        "local_id": report.local_id,
        "report_number": report.report_number,
        "case_id": report.case_id,
        "victim_id": report.victim_id,
        "sender_raw": report.sender_raw,
        "sender_display": report.sender_display,
        "sender_phone": report.sender_phone,
        "sender_hash": report.sender_hash,
        "content": report.content,
        "source_app": report.source_app,
        "source_package": report.source_package,
        "analysis": report.analysis or {},
        "category": report.category,
        "risk_level": report.risk_level,
        "confidence": report.confidence,
        "priority": report.priority,
        "message_timestamp": report.message_timestamp,
        "created_at": report.created_at,
        "updated_at": report.updated_at,
        "status": report.status,
    }


@router.post("", response_model=ReportSubmitOut, status_code=status.HTTP_201_CREATED)
async def submit_report(
    payload: ReportIn,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> dict:
    """استقبال بلاغ من تطبيق الضحية (استدعاء تلقائي عند كشف ابتزاز)"""
    phone = payload.sender.phone_number
    content_hash = sha256_hex(payload.content)
    report = Report(
        local_id=payload.local_id,
        victim_id=user.id,
        sender_raw=payload.sender.raw or payload.sender.display_name or "غير معروف",
        sender_display=payload.sender.display_name or payload.sender.raw or "غير معروف",
        sender_phone=phone,
        sender_phone_hash=blind_hash(phone) if phone else None,
        sender_hash=payload.sender.sender_hash
        or (sha256_hex(phone.encode()) if phone else None),
        content=payload.content,
        content_hash=content_hash,
        source_app=payload.source_app,
        source_package=payload.source_package,
        analysis=payload.analysis.model_dump(),
        category=payload.analysis.category,
        risk_level=payload.analysis.risk_level,
        confidence=payload.analysis.confidence,
        message_timestamp=_naive_utc(payload.message_timestamp),
        created_at=_naive_utc(payload.created_at),
        status="received",
    )
    report.report_number = generate_report_number()

    db.add(report)
    db.flush()  # يولّد report.id قبل بناء إدخال السلسلة

    append_custody_entry(
        db,
        report_id=report.id,
        action="received_from_device",
        actor=f"device:{user.phone_number}",
        notes=f"confidence={report.confidence:.2f}, risk={report.risk_level}",
    )
    db.commit()
    db.refresh(report)

    db.add(
        AuditLog(
            actor=user.phone_number,
            action="report_received",
            entity_type="report",
            entity_id=report.id,
            details={"report_number": report.report_number},
        )
    )
    db.commit()

    # مقياس الرصد: بلاغات مستلمة
    REPORTS_CREATED.inc()

    # ربط القضايا + التنبيه الاستباقي للمبتز المحترف
    pattern_alert = on_report_received(db, report)
    db.commit()  # توثيق الربط والتنبيه (التعديلات أعلاه بعد آخر commit)
    if pattern_alert:
        await manager.broadcast(
            broadcast_pattern_alert_payload(pattern_alert, report)
        )

    # إشعار المحققين والمشرفين عبر القنوات المهيأة (خلفية — لا يؤخر الاستجابة)
    if report.risk_level in ("high", "critical") or pattern_alert:
        from app.services.notifications.dispatcher import notify_staff_of_new_report

        background_tasks.add_task(notify_staff_of_new_report, report.id)

    # بث فوري للوحة التحكم
    await manager.broadcast(
        {"type": "new_report", "report": _report_out(report)}
    )

    return {
        "id": report.id,
        "report_number": report.report_number,
        "status": report.status,
        "received_at": report.created_at,
    }


@router.get("/{report_id}/custody-verify")
def custody_verify(
    report_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(*DASHBOARD_ROLES)),
) -> dict:
    """التحقق من سلامة سلسلة الحفظ — إعادة حساب كل الهاشات ومطابقتها"""
    valid, entries = verify_chain(db, report_id)
    return {
        "report_id": report_id,
        "valid": valid,
        "entries_count": len(entries),
        "entries": entries,
    }


@router.get("", response_model=ReportListOut)
def list_reports(
    status_filter: str | None = Query(default=None, alias="status"),
    category: str | None = Query(default=None),
    q: str | None = Query(default=None, description="بحث في المحتوى/المرسل"),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(*DASHBOARD_ROLES)),
) -> dict:
    query = db.query(Report)

    if status_filter:
        query = query.filter(Report.status == status_filter)
    if category:
        query = query.filter(Report.category == category)
    if q:
        like = f"%{q}%"
        query = query.filter(
            or_(
                Report.content.ilike(like),
                Report.sender_display.ilike(like),
                Report.sender_raw.ilike(like),
                Report.report_number.ilike(like),
            )
        )

    total = query.count()
    items = (
        query.order_by(Report.created_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
        .all()
    )

    return {
        "items": [_report_out(r) for r in items],
        "total": total,
        "page": page,
        "page_size": page_size,
    }


class FeedbackIn(BaseModel):
    feedback_type: str
    reason: str | None = Field(default=None, max_length=300)
    extortion_kind: str | None = Field(default=None, max_length=30)


FEEDBACK_TYPES = {"confirmed", "false_positive", "uncertain"}


EXTORTION_KINDS = {"financial", "sexual", "reputation", "threat", "other"}


@router.get("/{report_id}/legal-notices/{kind}")
def legal_notice(
    report_id: str,
    kind: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(*DASHBOARD_ROLES)),
) -> dict:
    """الإنذارات القانونية الجاهزة للمشاركة — بقرار الضحية أو النيابة"""
    from app.integrations.legal_notices import cease_and_desist, preemptive_notice

    report = db.get(Report, report_id)
    if report is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "البلاغ غير موجود")

    builders = {
        "cease_desist": cease_and_desist,
        "preemptive_notice": preemptive_notice,
    }
    builder = builders.get(kind)
    if builder is None:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_ENTITY,
            "النوع يجب أن يكون: cease_desist أو preemptive_notice",
        )
    return {"report_id": report.id, "kind": kind, "document": builder(report)}
@router.post("/{report_id}/feedback", status_code=status.HTTP_201_CREATED)
def submit_feedback(
    report_id: str,
    payload: FeedbackIn,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> dict:
    """تغذية راجعة من الضحية: تأكيد الابتزاز / سوء فهم / غير متأكد — تحسّن دقة النظام"""
    if payload.feedback_type not in FEEDBACK_TYPES:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_ENTITY,
            f"النوع يجب أن يكون: {', '.join(sorted(FEEDBACK_TYPES))}",
        )
    if payload.extortion_kind is not None and payload.extortion_kind not in EXTORTION_KINDS:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_ENTITY,
            f"نوع الابتزاز يجب أن يكون: {', '.join(sorted(EXTORTION_KINDS))}",
        )

    report = db.query(Report).filter(Report.id == report_id).first()
    if report is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "البلاغ غير موجود")
    if report.victim_id != user.id and user.role not in DASHBOARD_ROLES:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "هذا البلاغ ليس لك")

    feedback = ReportFeedback(
        report_id=report.id,
        victim_id=user.id,
        feedback_type=payload.feedback_type,
        extortion_kind=payload.extortion_kind,
        reason=payload.reason,
    )
    db.add(feedback)
    db.add(
        AuditLog(
            actor=user.phone_number,
            action="report_feedback",
            entity_type="report",
            entity_id=report.id,
            details={"type": payload.feedback_type},
        )
    )
    db.commit()
    db.refresh(feedback)

    FEEDBACK_SUBMITTED.labels(feedback_type=feedback.feedback_type).inc()

    return {
        "id": feedback.id,
        "report_id": report.id,
        "feedback_type": feedback.feedback_type,
        "created_at": feedback.created_at,
    }


class RetrainIn(BaseModel):
    apply: bool = True


@router.post("/feedback/retrain")
def retrain_detector(
    payload: RetrainIn | None = None,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(*DASHBOARD_ROLES)),
) -> dict:
    """حلقة التحسين: تحويل التقييمات إلى تعديل أوزان الكلمات وتطبيقها فوراً"""
    from app.services.feedback_learner import retrain

    overrides = retrain(db, actor=user.phone_number)
    return {
        "applied": bool(payload.apply) if payload else True,
        "overrides_count": len(overrides),
        "overrides": overrides,
    }


@router.get("/feedback/dataset")
def export_training_dataset(
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(*DASHBOARD_ROLES)),
) -> list[dict]:
    """تصدير مجموعة التدريب (نص، فئة) — مُغذّى مباشر لنموذج TFLite"""
    from app.services.feedback_learner import build_training_dataset

    return build_training_dataset(db)


@router.get("/feedback/overrides")
def current_overrides(
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(*DASHBOARD_ROLES)),
) -> dict:
    from app.services.feedback_learner import load_persisted_overrides

    return {"overrides": load_persisted_overrides(db)}


@router.get("/feedback/summary")
def feedback_summary(
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(*DASHBOARD_ROLES)),
) -> dict:
    """ملخص التغذية الراجعة — مؤشر جودة الكشف للوحة التحكم"""
    from sqlalchemy import func

    from app.models.report_feedback import ReportFeedback

    rows = (
        db.query(ReportFeedback.feedback_type, func.count(ReportFeedback.id))
        .group_by(ReportFeedback.feedback_type)
        .all()
    )
    counts = {row[0]: row[1] for row in rows}
    total = sum(counts.values())
    confirmed = counts.get("confirmed", 0)
    false_positive = counts.get("false_positive", 0)

    precision = confirmed / (confirmed + false_positive) if (confirmed + false_positive) else None
    return {
        "total": total,
        "by_type": counts,
        "confirmed_precision": round(precision, 3) if precision is not None else None,
    }


@router.get("/{report_id}", response_model=ReportDetailOut)
def get_report(
    report_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(*DASHBOARD_ROLES)),
) -> dict:
    report = (
        db.query(Report)
        .options(joinedload(Report.evidences), joinedload(Report.custody))
        .filter(
            or_(Report.id == report_id, Report.report_number == report_id)
        )
        .first()
    )
    if report is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "البلاغ غير موجود")

    data = _report_out(report)
    data["evidences"] = [
        {
            "id": e.id,
            "report_id": e.report_id,
            "file_hash": e.file_hash,
            "file_size": e.file_size,
            "mime_type": e.mime_type,
            "verified": e.verified,
            "uploaded_at": e.uploaded_at,
        }
        for e in report.evidences
    ]
    data["custody"] = [
        {
            "action": c.action,
            "actor": c.actor,
            "notes": c.notes,
            "timestamp": c.timestamp,
        }
        for c in report.custody
    ]
    return data


@router.patch("/{report_id}/status")
async def update_status(
    report_id: str,
    payload: StatusIn,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(*DASHBOARD_ROLES)),
) -> dict:
    if payload.status not in ALLOWED_STATUS_TRANSITIONS:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_ENTITY,
            f"حالة غير مسموحة — المسموح: {', '.join(sorted(ALLOWED_STATUS_TRANSITIONS))}",
        )

    report = (
        db.query(Report)
        .filter(or_(Report.id == report_id, Report.report_number == report_id))
        .first()
    )
    if report is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "البلاغ غير موجود")

    previous = report.status
    report.status = payload.status
    report.reviewed_by = user.id
    report.updated_at = datetime.utcnow()
    append_custody_entry(
        db,
        report_id=report.id,
        action=f"status_{payload.status}",
        actor=user.full_name or user.phone_number,
        notes=payload.note or f"من {previous} إلى {payload.status}",
    )
    db.add(
        AuditLog(
            actor=user.phone_number,
            action="report_status_changed",
            entity_type="report",
            entity_id=report.id,
            old_values={"status": previous},
            new_values={"status": payload.status, "note": payload.note},
        )
    )
    db.commit()
    db.refresh(report)

    await manager.broadcast(
        {
            "type": "status_change",
            "report_id": report.id,
            "report_number": report.report_number,
            "status": report.status,
            "by": user.full_name or user.phone_number,
        }
    )

    return {"id": report.id, "status": report.status}
