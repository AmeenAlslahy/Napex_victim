"""إنشاء إشعارات الضحية — تُستدعى تلقائياً من مراحل الحذف السحابي والجنائي"""
from sqlalchemy.orm import Session

from app.models.victim import VictimNotification


def notify_victim(
    db: Session,
    victim_id: str | None,
    notification_type: str,
    title: str,
    message: str,
    report_id: str | None = None,
) -> VictimNotification | None:
    if not victim_id:
        return None
    notification = VictimNotification(
        victim_id=victim_id,
        report_id=report_id,
        type=notification_type,
        title=title,
        message=message,
    )
    db.add(notification)
    return notification
