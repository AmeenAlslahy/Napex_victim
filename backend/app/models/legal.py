"""موديول السير العمل القانوني — أوامر التفتيش والحذف الموثقة"""
import uuid
from datetime import datetime

from sqlalchemy import DateTime, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.user import _now, _uuid


class LegalOrder(Base):
    """أمر قانوني (مذكرة تفتيش / أمر حذف / أمر ضبط) — يولّد مستنداً رسمياً"""

    __tablename__ = "legal_orders"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    order_number: Mapped[str] = mapped_column(String(30), unique=True, index=True)

    # warrant | takedown | seizure
    order_type: Mapped[str] = mapped_column(String(20), index=True)
    court_number: Mapped[str] = mapped_column(String(60))
    judge_name: Mapped[str] = mapped_column(String(120))

    # device | cloud | isp
    target_type: Mapped[str] = mapped_column(String(20), default="device")
    target_ref: Mapped[str | None] = mapped_column(String(36), nullable=True, index=True)

    related_report_id: Mapped[str | None] = mapped_column(String(36), nullable=True)
    related_case_id: Mapped[str | None] = mapped_column(String(36), nullable=True)

    # draft -> issued -> executed -> returned
    status: Mapped[str] = mapped_column(String(20), default="issued", index=True)
    issued_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)
    served_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    executed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    returned_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    valid_until: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    execution_notes: Mapped[str | None] = mapped_column(String(500), nullable=True)

    # Audit & Documents
    issued_by: Mapped[str | None] = mapped_column(String(36), nullable=True)
    document_hash: Mapped[str | None] = mapped_column(String(64), nullable=True)

    @staticmethod
    def generate_order_number() -> str:
        return f"LO-{uuid.uuid4().hex[:8].upper()}"
