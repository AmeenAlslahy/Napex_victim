"""مخططات البلاغات — متوافقة مع ReportModel.toJson في تطبيق الجهاز"""
from datetime import datetime

from pydantic import BaseModel, Field


class SenderIn(BaseModel):
    raw: str = ""
    display_name: str = ""
    phone_number: str | None = None
    sender_hash: str | None = None
    is_contact: bool = False
    is_blocked: bool = False


class AnalysisIn(BaseModel):
    category: str = "extortion"
    confidence: float = 0.0
    risk_level: str = "none"
    is_extortion: bool = False
    probabilities: dict[str, float] = Field(default_factory=dict)
    keywords: list[str] = Field(default_factory=list)
    threat_phrases: list[str] = Field(default_factory=list)


class ReportIn(BaseModel):
    local_id: str
    sender: SenderIn
    content: str
    source_app: str = "sms"
    source_package: str | None = None
    analysis: AnalysisIn
    message_timestamp: datetime
    created_at: datetime


class ReportSubmitOut(BaseModel):
    """استجابة استلام البلاغ — التطبيق يقرأ report_number أو id"""

    id: str
    report_number: str
    status: str = "received"
    received_at: datetime


class StatusIn(BaseModel):
    status: str
    note: str | None = None


class EvidenceOut(BaseModel):
    id: str
    report_id: str
    file_hash: str
    file_size: int
    mime_type: str
    verified: bool
    uploaded_at: datetime


class CustodyOut(BaseModel):
    action: str
    actor: str
    notes: str | None = None
    timestamp: datetime


class ReportOut(BaseModel):
    id: str
    local_id: str
    report_number: str | None = None
    victim_id: str | None = None
    sender_raw: str
    sender_display: str
    sender_phone: str | None = None
    sender_hash: str | None = None
    content: str
    source_app: str
    source_package: str | None = None
    analysis: dict
    category: str
    risk_level: str
    confidence: float
    message_timestamp: datetime
    created_at: datetime
    status: str


class ReportDetailOut(ReportOut):
    evidences: list[EvidenceOut] = Field(default_factory=list)
    custody: list[CustodyOut] = Field(default_factory=list)


class ReportListOut(BaseModel):
    items: list[ReportOut]
    total: int
    page: int
    page_size: int


# الحالات المسموح بها للتحديث من لوحة التحكم
ALLOWED_STATUS_TRANSITIONS = {
    "received",
    "under_review",
    "investigating",
    "resolved",
    "closed",
    "rejected",
}
