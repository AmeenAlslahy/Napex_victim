"""موزّع الإشعارات — يوجه عبر القنوات المهيأة لكل مستخدم/محقق

قاعدة صارمة: لا قناة ترفع استثناءً — الفشل يُسجل ويُتجاوز (البلاغ لا يعتمد على الإشعار).
"""
import logging
from dataclasses import asdict

from sqlalchemy.orm import Session

from app.models.report import Report
from app.models.user import User
from app.models.user_device import UserDevice
from app.services.notifications.base import DispatchResult
from app.services.notifications.email_channel import EmailChannel
from app.services.notifications.push_channel import PushChannel
from app.services.notifications.sms_channel import SmsChannel

logger = logging.getLogger("napex.notify")

STAFF_ROLES = ("admin", "supervisor", "investigator")


class NotificationDispatcher:
    def __init__(self) -> None:
        self._email = EmailChannel()
        self._sms = SmsChannel()
        self._push = PushChannel()

    # ============ لمستخدم واحد ============

    def notify_user(self, db: Session, user: User, title: str, body: str) -> list[dict]:
        results: list[dict] = []

        if user.email:
            results.append(asdict(self._email.send(user.email, title, body)))

        if user.phone:
            results.append(asdict(self._sms.send(user.phone, f"{title}\n{body}")))

        tokens = [
            row[0]
            for row in db.query(UserDevice.fcm_token)
            .filter(
                UserDevice.user_id == user.id,
                UserDevice.is_active.is_(True),
                UserDevice.fcm_token.isnot(None),
            )
            .all()
        ]
        for token in tokens:
            results.append(asdict(self._push.send(token, title, body)))

        if not results:
            results.append(
                asdict(DispatchResult.not_configured("any", user.phone_number))
            )
        return results

    # ============ للمحققين والمشرفين (الجهة) ============

    def notify_staff(self, db: Session, title: str, body: str) -> list[dict]:
        results: list[dict] = []
        staff = (
            db.query(User)
            .filter(
                User.role.in_(STAFF_ROLES),
                User.is_active.is_(True),
            )
            .all()
        )
        for user in staff:
            results.extend(self.notify_user(db, user, title, body))
        return results


def notify_staff_of_new_report(report_id: str) -> None:
    """تُستدعى كـ Background Task — تفتح جلستها الخاصة (الطلب قد يكون أُغلق)"""
    from app.db.base import SessionLocal
    from app.core.config import get_settings

    settings = get_settings()
    if not (settings.smtp_host or settings.sms_gateway_url or settings.fcm_server_key):
        return  # لا قنوات مهيأة — صمت

    db = SessionLocal()
    try:
        report = db.get(Report, report_id)
        if report is None:
            return
        dispatcher = NotificationDispatcher()
        severity_note = (
            "🚨 بلاغ حرج" if report.risk_level == "critical" else "بلاغ جديد"
        )
        dispatcher.notify_staff(
            db,
            title=f"{severity_note}: {report.report_number}",
            body=(
                f"من {report.sender_display} عبر {report.source_app} — "
                f"الخطورة {report.risk_level} (الثقة {report.confidence:.0%})"
            ),
        )
    finally:
        db.close()
