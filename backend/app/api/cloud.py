"""واجهات الحذف السحابي — تتبع طلبات الإزالة لدى مزودي المنصات"""
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.core.deps import get_db, require_roles
from app.models.audit import AuditLog
from app.models.cloud import CloudOrder
from app.models.report import Report
from app.models.user import User
from app.services.victim_notify import notify_victim

router = APIRouter(prefix="/cloud", tags=["cloud"])

DASHBOARD_ROLES = ("admin", "supervisor", "investigator")

CLOUD_STATUSES = {"submitted", "acknowledged", "actioned", "rejected"}
PROVIDERS = {"google", "apple", "meta", "telegram", "tiktok", "snapchat", "other"}


class CreateOrderIn(BaseModel):
    provider: str
    report_id: str | None = None
    files_count: int = Field(default=0, ge=0)
    notes: str | None = Field(default=None, max_length=500)


class StatusIn(BaseModel):
    status: str
    notes: str | None = Field(default=None, max_length=500)


def _order_out(order: CloudOrder) -> dict:
    return {
        "id": order.id,
        "order_number": order.order_number,
        "legal_order_id": order.legal_order_id,
        "report_id": order.report_id,
        "provider": order.provider,
        "provider_ref": order.provider_ref,
        "files_count": order.files_count,
        "status": order.status,
        "attempts": order.attempts,
        "submitted_at": order.submitted_at,
        "actioned_at": order.actioned_at,
        "notes": order.notes,
    }


@router.post("/orders", status_code=status.HTTP_201_CREATED)
def create_order(
    payload: CreateOrderIn,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(*DASHBOARD_ROLES)),
) -> dict:
    if payload.provider not in PROVIDERS:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_ENTITY,
            f"المزود يجب أن يكون: {', '.join(sorted(PROVIDERS))}",
        )
    order = CloudOrder(
        order_number=CloudOrder.generate_order_number(),
        report_id=payload.report_id,
        provider=payload.provider,
        files_count=payload.files_count,
        notes=payload.notes,
    )
    db.add(order)
    db.commit()
    db.refresh(order)
    return _order_out(order)


@router.get("/orders")
def list_orders(
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(*DASHBOARD_ROLES)),
) -> list[dict]:
    orders = db.query(CloudOrder).order_by(CloudOrder.submitted_at.desc()).all()
    return [_order_out(o) for o in orders]


@router.patch("/orders/{order_id}/status")
def update_status(
    order_id: str,
    payload: StatusIn,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(*DASHBOARD_ROLES)),
) -> dict:
    if payload.status not in CLOUD_STATUSES:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_ENTITY,
            f"الحالة يجب أن تكون: {', '.join(sorted(CLOUD_STATUSES))}",
        )
    order = db.get(CloudOrder, order_id)
    if order is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "الطلب غير موجود")

    order.status = payload.status
    if payload.status == "actioned":
        order.actioned_at = datetime.utcnow()

    # عند إتمام الإزالة: إبلاغ الضحية تلقائياً
    if payload.status == "actioned":
        report = db.get(Report, order.report_id) if order.report_id else None
        notify_victim(
            db,
            victim_id=report.victim_id if report else None,
            notification_type="cloud_cleaned",
            title="تمت إزالة المحتوى من المنصة",
            message=(
                f"أكمل مزود الخدمة ({order.provider}) إزالة المحتوى المرتبط "
                f"بقضيتك — الطلب {order.order_number}"
            ),
            report_id=order.report_id,
        )

    db.add(
        AuditLog(
            actor=user.phone_number,
            action="cloud_order_status",
            entity_type="cloud_order",
            entity_id=order.id,
            details={"status": payload.status, "provider": order.provider},
        )
    )
    db.commit()
    db.refresh(order)
    return _order_out(order)


@router.post("/orders/{order_id}/retry")
def retry_order(
    order_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(*DASHBOARD_ROLES)),
) -> dict:
    order = db.get(CloudOrder, order_id)
    if order is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "الطلب غير موجود")
    if order.status == "actioned":
        raise HTTPException(status.HTTP_409_CONFLICT, "الطلب منفذ بالفعل")

    order.attempts += 1
    order.status = "submitted"
    db.commit()
    db.refresh(order)
    return _order_out(order)
