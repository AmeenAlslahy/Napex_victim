"""طلبات التعاون الدولي — Interpol / MLAT / ISP: بناء + تتبع"""
import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.core.deps import get_db, require_roles
from app.models.audit import AuditLog
from app.models.cloud import CloudOrder
from app.models.international_request import (
    InternationalRequest,
    REQUEST_STATUSES,
    REQUEST_TYPES,
)
from app.models.report import Report
from app.models.user import User

router = APIRouter(prefix="/international", tags=["international"])

DASHBOARD_ROLES = ("admin", "supervisor", "investigator")

_REF_PREFIX = {"interpol": "INT", "mlat": "MLAT", "isp": "ISP"}


class CreateRequestIn(BaseModel):
    request_type: str
    report_id: str
    target_country: str | None = Field(default=None, max_length=60)
    court_number: str | None = Field(default=None, max_length=60)
    crime_articles: list[str] = Field(default_factory=list)


class StatusIn(BaseModel):
    status: str
    notes: str | None = Field(default=None, max_length=500)


def _request_out(req: InternationalRequest) -> dict:
    return {
        "id": req.id,
        "reference_number": req.reference_number,
        "request_type": req.request_type,
        "target_country": req.target_country,
        "report_id": req.report_id,
        "status": req.status,
        "notes": req.notes,
        "created_at": req.created_at,
        "updated_at": req.updated_at,
    }


def _get_request(db: Session, request_id: str) -> InternationalRequest:
    req = db.get(InternationalRequest, request_id)
    if req is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "الطلب غير موجود")
    return req


@router.get("/takedown-document/{cloud_order_id}")
def takedown_document(
    cloud_order_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(*DASHBOARD_ROLES)),
) -> dict:
    """توليد وثيقة طلب الإزالة الرسمية لطلب سحابي — جاهزة للتقديم عبر بوابة المزود"""
    from app.integrations.takedown import TakedownRequestBuilder

    order = db.get(CloudOrder, cloud_order_id)
    if order is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "الطلب غير موجود")
    report = db.get(Report, order.report_id) if order.report_id else None
    if report is None:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_ENTITY,
            "الطلب غير مرتبط ببلاغ",
        )

    document = TakedownRequestBuilder().build(order.provider, report, order)
    return {
        "cloud_order_id": order.id,
        "provider": order.provider,
        "document": document,
    }


@router.post("/requests", status_code=status.HTTP_201_CREATED)
def create_request(
    payload: CreateRequestIn,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(*DASHBOARD_ROLES)),
) -> dict:
    if payload.request_type not in REQUEST_TYPES:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_ENTITY,
            f"النوع يجب أن يكون: {', '.join(sorted(REQUEST_TYPES))}",
        )

    report = db.get(Report, payload.report_id)
    if report is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "البلاغ غير موجود")

    reference = (
        f"{_REF_PREFIX[payload.request_type]}-"
        f"{datetime.utcnow().year}-{uuid.uuid4().hex[:6].upper()}"
    )

    # بناء وثيقة الطلب حسب النوع
    if payload.request_type == "interpol":
        from app.integrations.cross_border import InterpolNoticeBuilder

        document = InterpolNoticeBuilder().build(
            report,
            requesting_country="Yemen",
            target_country=payload.target_country or "—",
        )
    elif payload.request_type == "mlat":
        from app.integrations.cross_border import MlatRequestBuilder

        document = MlatRequestBuilder().build(
            report,
            target_country=payload.target_country or "—",
            crime_articles=payload.crime_articles,
        )
    else:  # isp
        from app.integrations.takedown import IspRequestBuilder

        document = IspRequestBuilder().build(
            report,
            court_number=payload.court_number or "النيابة العامة",
        )

    request = InternationalRequest(
        reference_number=reference,
        request_type=payload.request_type,
        target_country=payload.target_country,
        report_id=report.id,
        status="draft",
        document_content=document,
        created_by=user.id,
    )
    db.add(request)
    db.add(
        AuditLog(
            actor=user.phone_number,
            action="international_request_created",
            entity_type="international_request",
            entity_id=request.id,
            details={"type": payload.request_type, "reference": reference},
        )
    )
    db.commit()
    db.refresh(request)
    return _request_out(request)


@router.get("/requests")
def list_requests(
    request_type: str | None = Query(default=None),
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(*DASHBOARD_ROLES)),
) -> list[dict]:
    query = db.query(InternationalRequest)
    if request_type:
        query = query.filter(InternationalRequest.request_type == request_type)
    return [_request_out(r) for r in query.order_by(
        InternationalRequest.created_at.desc()
    ).limit(200).all()]


@router.get("/requests/{request_id}")
def get_request(
    request_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(*DASHBOARD_ROLES)),
) -> dict:
    req = _get_request(db, request_id)
    data = _request_out(req)
    data["document"] = req.document_content
    return data


@router.patch("/requests/{request_id}/status")
def update_status(
    request_id: str,
    payload: StatusIn,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(*DASHBOARD_ROLES)),
) -> dict:
    if payload.status not in REQUEST_STATUSES:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_ENTITY,
            f"الحالة يجب أن تكون: {', '.join(sorted(REQUEST_STATUSES))}",
        )
    req = _get_request(db, request_id)
    req.status = payload.status
    if payload.notes:
        req.notes = payload.notes
    db.add(
        AuditLog(
            actor=user.phone_number,
            action="international_request_status",
            entity_type="international_request",
            entity_id=req.id,
            details={"status": payload.status},
        )
    )
    db.commit()
    db.refresh(req)
    return _request_out(req)
