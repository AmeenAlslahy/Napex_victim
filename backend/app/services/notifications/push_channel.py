"""قناة Push — Firebase Cloud Messaging (legacy HTTP API بأولوية للبساطة)"""
import httpx

from app.core.config import get_settings
from app.services.notifications.base import DispatchResult

_FCM_ENDPOINT = "https://fcm.googleapis.com/fcm/send"


class PushChannel:
    def __init__(self) -> None:
        self._settings = get_settings()

    @property
    def configured(self) -> bool:
        return bool(self._settings.fcm_server_key)

    def send(self, device_token: str, title: str, body: str, data: dict | None = None) -> DispatchResult:
        if not device_token:
            return DispatchResult.failed("push", "", "لا يوجد رمز جهاز")
        if not self.configured:
            return DispatchResult.not_configured("push", device_token[:16])

        try:
            s = self._settings
            response = httpx.post(
                _FCM_ENDPOINT,
                json={
                    "to": device_token,
                    "notification": {"title": title, "body": body},
                    "data": data or {},
                    "priority": "high",
                },
                headers={"Authorization": f"key={s.fcm_server_key}"},
                timeout=15,
            )
            sent = response.status_code < 400
            return DispatchResult(
                "push", device_token[:16], sent, f"HTTP {response.status_code}"
            )
        except Exception as exc:
            return DispatchResult.failed("push", device_token[:16], str(exc))
