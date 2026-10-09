"""قناة البريد الإلكتروني — SMTP (لا تُرسل شيئاً حتى تُضبط SMTP_HOST)"""
import smtplib
from email.mime.text import MIMEText
from email.utils import formataddr

from app.core.config import get_settings
from app.services.notifications.base import DispatchResult


class EmailChannel:
    def __init__(self) -> None:
        self._settings = get_settings()

    @property
    def configured(self) -> bool:
        s = self._settings
        return bool(s.smtp_host)

    def send(self, to: str, subject: str, body: str) -> DispatchResult:
        if not to:
            return DispatchResult.failed("email", "", "لا يوجد بريد للمستلم")
        if not self.configured:
            return DispatchResult.not_configured("email", to)

        try:
            s = self._settings
            message = MIMEText(body, "plain", "utf-8")
            message["Subject"] = f"[NAP-EX] {subject}"
            message["From"] = formataddr(("NAP-EX", s.email_from))
            message["To"] = to

            with smtplib.SMTP(s.smtp_host, s.smtp_port, timeout=15) as server:
                if s.smtp_port == 587:
                    server.starttls()
                if s.smtp_user and s.smtp_password:
                    server.login(s.smtp_user, s.smtp_password)
                server.send_message(message)

            return DispatchResult("email", to, True)
        except Exception as exc:
            return DispatchResult.failed("email", to, str(exc))
