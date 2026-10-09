"""واجهات الضحية — إشعاراتها وقراءتها"""
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.core.deps import get_current_user, get_db, require_roles
from app.models.user import User
from app.models.victim import VictimNotification
from app.services.victim_notify import notify_victim

router = APIRouter(prefix="/victim", tags=["victim"])

DASHBOARD_ROLES = ("admin", "supervisor", "investigator")


class NotifyIn(BaseModel):
    victim_id: str | None = None
    report_id: str | None = None
    type: str = Field(default="case_update", max_length=30)
    title: str = Field(min_length=1, max_length=120)
    message: str = Field(min_length=1, max_length=500)


def _notification_out(n: VictimNotification) -> dict:
    return {
        "id": n.id,
        "victim_id": n.victim_id,
        "report_id": n.report_id,
        "type": n.type,
        "title": n.title,
        "message": n.message,
        "created_at": n.created_at,
        "read_at": n.read_at,
    }


@router.post("/notify", status_code=status.HTTP_201_CREATED)
def send_notification(
    payload: NotifyIn,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(*DASHBOARD_ROLES)),
) -> dict:
    if payload.victim_id is None and payload.report_id is None:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_ENTITY,
            "حدد الضحية أو البلاغ",
        )

    # إن أُرسل report_id بدون victim_id — استنتج الضحية من البلاغ
    victim_id = payload.victim_id
    if victim_id is None and payload.report_id:
        from app.models.report import Report

        report = db.get(Report, payload.report_id)
        if report is None:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "البلاغ غير موجود")
        victim_id = report.victim_id

    notification = notify_victim(
        db,
        victim_id=victim_id,
        notification_type=payload.type,
        title=payload.title,
        message=payload.message,
        report_id=payload.report_id,
    )
    db.commit()
    db.refresh(notification)
    return _notification_out(notification)


@router.get("/notifications")
def my_notifications(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> list[dict]:
    notifications = (
        db.query(VictimNotification)
        .filter(VictimNotification.victim_id == user.id)
        .order_by(VictimNotification.created_at.desc())
        .limit(100)
        .all()
    )
    return [_notification_out(n) for n in notifications]


@router.get("/notifications/all")
def all_notifications(
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(*DASHBOARD_ROLES)),
) -> list[dict]:
    notifications = (
        db.query(VictimNotification)
        .order_by(VictimNotification.created_at.desc())
        .limit(200)
        .all()
    )
    return [_notification_out(n) for n in notifications]


@router.patch("/notifications/{notification_id}/read")
def mark_read(
    notification_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> dict:
    notification = db.get(VictimNotification, notification_id)
    if notification is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "الإشعار غير موجود")

    is_owner = notification.victim_id == user.id
    is_staff = user.role in DASHBOARD_ROLES
    if not (is_owner or is_staff):
        raise HTTPException(status.HTTP_403_FORBIDDEN, "غير مصرح")

    if notification.read_at is None:
        notification.read_at = datetime.utcnow()
        db.commit()
    return _notification_out(notification)
