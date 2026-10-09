"""واجهات القضايا الموحدة — تجميع البلاغات والمتابعة"""
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field
from sqlalchemy import func
from sqlalchemy.orm import Session, joinedload

from app.core.deps import get_db, require_roles
from app.models.audit import AuditLog
from app.models.case import (
    CASE_STATUSES,
    Case,
    CaseNote,
    CaseUpdate,
    generate_case_number,
)
from app.models.report import Report
from app.models.user import User
from app.services.notify import manager
from app.services.victim_notify import notify_victim

router = APIRouter(prefix="/cases", tags=["cases"])

DASHBOARD_ROLES = ("admin", "supervisor", "investigator")


class CreateCaseIn(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    description: str | None = Field(default=None, max_length=2000)
    category: str | None = Field(default=None, max_length=50)
    priority: str = Field(default="medium")
    report_id: str | None = None


class AttachReportIn(BaseModel):
    report_id: str


class NoteIn(BaseModel):
    content: str = Field(min_length=1, max_length=2000)
    is_internal: bool = True


class UpdateIn(BaseModel):
    type: str = Field(default="case_update", max_length=30)
    title: str = Field(min_length=1, max_length=120)
    message: str = Field(min_length=1, max_length=500)
    notify_victim: bool = False


class PatchCaseIn(BaseModel):
    title: str | None = Field(default=None, max_length=200)
    description: str | None = Field(default=None, max_length=2000)
    priority: str | None = Field(default=None)
    status: str | None = Field(default=None)
    assigned_to: str | None = Field(default=None)
    resolution: str | None = Field(default=None, max_length=2000)


def _get_case(db: Session, case_id: str) -> Case:
    case = (
        db.query(Case)
        .options(joinedload(Case.reports), joinedload(Case.notes), joinedload(Case.updates))
        .filter(Case.id == case_id, Case.deleted_at.is_(None))
        .first()
    )
    if case is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "القضية غير موجودة")
    return case


def _case_out(case: Case) -> dict:
    return {
        "id": case.id,
        "case_number": case.case_number,
        "title": case.title,
        "description": case.description,
        "category": case.category,
        "priority": case.priority,
        "status": case.status,
        "primary_victim_id": case.primary_victim_id,
        "assigned_to": case.assigned_to,
        "reports_count": case.reports_count,
        "victims_count": case.victims_count,
        "created_at": case.created_at,
        "updated_at": case.updated_at,
        "closed_at": case.closed_at,
    }


@router.post("", status_code=status.HTTP_201_CREATED)
def create_case(
    payload: CreateCaseIn,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(*DASHBOARD_ROLES)),
) -> dict:
    if payload.priority not in ("low", "medium", "high", "critical"):
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "أولوية غير صالحة")

    case = Case(
        case_number=generate_case_number(),
        title=payload.title,
        description=payload.description,
        category=payload.category,
        priority=payload.priority,
        created_by=user.id,
    )
    db.add(case)
    db.flush()  # يولّد case.id قبل ربط البلاغ

    if payload.report_id:
        report = db.get(Report, payload.report_id)
        if report is None:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "البلاغ غير موجود")
        report.case_id = case.id
        case.primary_victim_id = report.victim_id
        db.flush()

    case.reports_count = (
        db.query(Report).filter(Report.case_id == case.id).count()
    )
    db.add(
        AuditLog(
            actor=user.phone_number,
            action="case_created",
            entity_type="case",
            entity_id=case.id,
            details={"case_number": case.case_number},
        )
    )
    db.commit()
    db.refresh(case)
    return _case_out(case)


@router.get("")
def list_cases(
    status_filter: str | None = Query(default=None, alias="status"),
    assigned_to_me: bool = Query(default=False),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(*DASHBOARD_ROLES)),
) -> dict:
    query = db.query(Case).filter(Case.deleted_at.is_(None))
    if status_filter:
        query = query.filter(Case.status == status_filter)
    if assigned_to_me:
        query = query.filter(Case.assigned_to == user.id)

    total = query.count()
    items = (
        query.order_by(Case.updated_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
        .all()
    )
    return {
        "items": [_case_out(c) for c in items],
        "total": total,
        "page": page,
        "page_size": page_size,
    }


@router.get("/{case_id}")
def get_case(
    case_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(*DASHBOARD_ROLES)),
) -> dict:
    case = _get_case(db, case_id)
    data = _case_out(case)
    data["reports"] = [
        {
            "id": r.id,
            "report_number": r.report_number,
            "sender_display": r.sender_display,
            "sender_hash": r.sender_hash,
            "category": r.category,
            "risk_level": r.risk_level,
            "status": r.status,
            "created_at": r.created_at,
        }
        for r in case.reports
    ]
    data["notes"] = [
        {
            "id": n.id,
            "author_name": n.author_name,
            "content": n.content,
            "is_internal": n.is_internal,
            "created_at": n.created_at,
        }
        for n in case.notes
    ]
    data["updates"] = [
        {
            "id": u.id,
            "type": u.type,
            "title": u.title,
            "message": u.message,
            "created_at": u.created_at,
        }
        for u in case.updates
    ]
    return data


@router.patch("/{case_id}")
def patch_case(
    case_id: str,
    payload: PatchCaseIn,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(*DASHBOARD_ROLES)),
) -> dict:
    case = _get_case(db, case_id)

    if payload.status is not None:
        if payload.status not in CASE_STATUSES:
            raise HTTPException(
                status.HTTP_422_UNPROCESSABLE_ENTITY,
                f"الحالة يجب أن تكون: {', '.join(sorted(CASE_STATUSES))}",
            )
        case.status = payload.status
        if payload.status == "closed":
            case.closed_at = datetime.utcnow()

    changes = {}
    for field in ("title", "description", "priority", "assigned_to", "resolution"):
        value = getattr(payload, field)
        if value is not None:
            changes[field] = value
            setattr(case, field, value)

    case.updated_at = datetime.utcnow()
    db.add(
        AuditLog(
            actor=user.phone_number,
            action="case_updated",
            entity_type="case",
            entity_id=case.id,
            old_values={"status": None},
            new_values=changes | {"status": case.status},
        )
    )
    db.commit()
    db.refresh(case)
    return _case_out(case)


@router.post("/{case_id}/reports", status_code=status.HTTP_200_OK)
def attach_report(
    case_id: str,
    payload: AttachReportIn,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(*DASHBOARD_ROLES)),
) -> dict:
    case = _get_case(db, case_id)
    report = db.get(Report, payload.report_id)
    if report is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "البلاغ غير موجود")

    report.case_id = case.id
    db.flush()
    case.reports_count = (
        db.query(Report).filter(Report.case_id == case.id).count()
    )
    case.victims_count = (
        db.query(func.count(func.distinct(Report.victim_id)))
        .filter(Report.case_id == case.id, Report.victim_id.isnot(None))
        .scalar()
        or 0
    )
    case.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(case)
    return _case_out(case)


@router.post("/{case_id}/notes", status_code=status.HTTP_201_CREATED)
def add_note(
    case_id: str,
    payload: NoteIn,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(*DASHBOARD_ROLES)),
) -> dict:
    case = _get_case(db, case_id)
    note = CaseNote(
        case_id=case.id,
        author_id=user.id,
        author_name=user.full_name or user.phone_number,
        content=payload.content,
        is_internal=payload.is_internal,
    )
    db.add(note)
    case.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(note)
    return {
        "id": note.id,
        "author_name": note.author_name,
        "content": note.content,
        "is_internal": note.is_internal,
        "created_at": note.created_at,
    }


@router.post("/{case_id}/updates", status_code=status.HTTP_201_CREATED)
async def add_update(
    case_id: str,
    payload: UpdateIn,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(*DASHBOARD_ROLES)),
) -> dict:
    """تحديث قضية — مع إشعار اختياري يصل لتطبيق الضحية"""
    case = _get_case(db, case_id)

    update = CaseUpdate(
        case_id=case.id,
        type=payload.type,
        title=payload.title,
        message=payload.message,
    )
    db.add(update)

    if payload.notify_victim and case.primary_victim_id:
        notify_victim(
            db,
            victim_id=case.primary_victim_id,
            notification_type="case_update",
            title=payload.title,
            message=payload.message,
        )

    case.updated_at = datetime.utcnow()
    db.add(
        AuditLog(
            actor=user.phone_number,
            action="case_update_added",
            entity_type="case",
            entity_id=case.id,
            details={"notified_victim": payload.notify_victim},
        )
    )
    db.commit()
    db.refresh(update)

    await manager.broadcast(
        {"type": "case_update", "case_number": case.case_number, "title": payload.title}
    )
    return {
        "id": update.id,
        "type": update.type,
        "title": update.title,
        "message": update.message,
        "created_at": update.created_at,
    }


@router.delete("/{case_id}")
def soft_delete_case(
    case_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles("admin", "supervisor")),
) -> dict:
    case = _get_case(db, case_id)
    case.deleted_at = datetime.utcnow()
    db.add(
        AuditLog(
            actor=user.phone_number,
            action="case_deleted",
            entity_type="case",
            entity_id=case.id,
        )
    )
    db.commit()
    return {"id": case.id, "deleted": True}
