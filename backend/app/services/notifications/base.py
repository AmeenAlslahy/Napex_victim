"""نتائج الإرسال الموحدة — كل قناة تُعيد هذا ولا ترفع استثناءات أبداً"""
from dataclasses import dataclass, field


@dataclass
class DispatchResult:
    channel: str          # email | sms | push
    recipient: str
    sent: bool
    detail: str = ""

    @staticmethod
    def not_configured(channel: str, recipient: str = "") -> "DispatchResult":
        return DispatchResult(
            channel=channel,
            recipient=recipient,
            sent=False,
            detail="القناة غير مهيأة",
        )

    @staticmethod
    def failed(channel: str, recipient: str, detail: str) -> "DispatchResult":
        return DispatchResult(channel=channel, recipient=recipient, sent=False, detail=detail)
