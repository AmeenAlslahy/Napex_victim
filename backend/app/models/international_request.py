"""طلبات التعاون الدولي — Interpol / MLAT / ISP مع الوثيقة الرسمية"""
import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.user import _now, _uuid

REQUEST_TYPES = {"interpol", "mlat", "isp"}
REQUEST_STATUSES = {"draft", "submitted", "acknowledged", "responded", "closed"}


class InternationalRequest(Base):
    __tablename__ = "international_requests"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    reference_number: Mapped[str] = mapped_column(String(30), unique=True, index=True)
    request_type: Mapped[str] = mapped_column(String(20), index=True)
    target_country: Mapped[str | None] = mapped_column(String(60), nullable=True)
    report_id: Mapped[str | None] = mapped_column(
        String(36), ForeignKey("reports.id"), nullable=True, index=True
    )
    case_id: Mapped[str | None] = mapped_column(String(36), nullable=True)

    status: Mapped[str] = mapped_column(String(20), default="draft", index=True)
    document_content: Mapped[str] = mapped_column(Text, default="")
    notes: Mapped[str | None] = mapped_column(String(500), nullable=True)
    created_by: Mapped[str | None] = mapped_column(String(36), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)
