"""قناة SMS — بوابة عامة قابلة للاستبدال (POST JSON: to/text + Bearer key)"""
import httpx

from app.core.config import get_settings
from app.services.notifications.base import DispatchResult


class SmsChannel:
    """مزود SMS محدد يُضبط عبر SMS_GATEWAY_URL — التكامل الفعلي حسب المزود الوطني"""

    def __init__(self) -> None:
        self._settings = get_settings()

    @property
    def configured(self) -> bool:
        s = self._settings
        return bool(s.sms_gateway_url and s.sms_api_key)

    def send(self, to: str, body: str) -> DispatchResult:
        if not to:
            return DispatchResult.failed("sms", "", "لا يوجد رقم للمستلم")
        if not self.configured:
            return DispatchResult.not_configured("sms", to)

        try:
            s = self._settings
            response = httpx.post(
                s.sms_gateway_url,
                json={"to": to, "text": body},
                headers={"Authorization": f"Bearer {s.sms_api_key}"},
                timeout=15,
            )
            sent = response.status_code < 400
            return DispatchResult(
                "sms", to, sent,
                f"HTTP {response.status_code}",
            )
        except Exception as exc:
            return DispatchResult.failed("sms", to, str(exc))
