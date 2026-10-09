"""نماذج البلاغات والأدلة وسلسلة الحفظ"""
import uuid
from datetime import datetime, timezone

from sqlalchemy import (
    JSON,
    Boolean,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.encrypted_field import EncryptedString
from app.db.base import Base
from app.models.user import _now, _uuid


class Report(Base):
    __tablename__ = "reports"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    local_id: Mapped[str] = mapped_column(String(36), unique=True, index=True)
    report_number: Mapped[str | None] = mapped_column(
        String(30), unique=True, index=True, nullable=True
    )

    # القضية الموحدة — تُربط تلقائياً بنفس sender_hash أو يدوياً من اللوحة
    case_id: Mapped[str | None] = mapped_column(
        String(36), ForeignKey("cases.id"), nullable=True, index=True
    )

    # الضحية (المستخدم المرسل للبلاغ) — قد يكون مجهولاً
    victim_id: Mapped[str | None] = mapped_column(
        String(36), ForeignKey("users.id"), nullable=True, index=True
    )

    # المبتز المشتبه به
    sender_raw: Mapped[str] = mapped_column(String(160))
    sender_display: Mapped[str] = mapped_column(String(160), default="")
    sender_phone: Mapped[str | None] = mapped_column(
        EncryptedString(120), nullable=True
    )
    sender_phone_hash: Mapped[str | None] = mapped_column(
        String(64), nullable=True, index=True
    )
    sender_hash: Mapped[str | None] = mapped_column(String(64), nullable=True, index=True)

    content: Mapped[str] = mapped_column(Text)
    content_hash: Mapped[str | None] = mapped_column(String(64), nullable=True)
    source_app: Mapped[str] = mapped_column(String(60), default="sms", index=True)
    source_package: Mapped[str | None] = mapped_column(String(60), nullable=True)

    # نتيجة تحليل الجهاز: {category, confidence, risk_level, is_extortion, keywords...}
    analysis: Mapped[dict] = mapped_column(JSON, default=dict)
    category: Mapped[str] = mapped_column(String(20), default="extortion", index=True)
    risk_level: Mapped[str] = mapped_column(String(20), default="high", index=True)
    confidence: Mapped[float] = mapped_column(Float, default=0.0)

    priority: Mapped[int] = mapped_column(Integer, default=5, index=True)
    reviewed_by: Mapped[str | None] = mapped_column(String(36), nullable=True)
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    message_timestamp: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_now, index=True
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_now
    )
    deleted_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    status: Mapped[str] = mapped_column(String(20), default="received", index=True)

    case = relationship("Case", back_populates="reports")
    evidences: Mapped[list["Evidence"]] = relationship(back_populates="report")
    custody: Mapped[list["CustodyEntry"]] = relationship(
        back_populates="report", order_by="CustodyEntry.timestamp"
    )


class Evidence(Base):
    __tablename__ = "evidences"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    report_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("reports.id"), index=True
    )
    file_path: Mapped[str] = mapped_column(String(400))
    file_hash: Mapped[str] = mapped_column(String(64), index=True)
    file_size: Mapped[int] = mapped_column(Integer, default=0)
    mime_type: Mapped[str] = mapped_column(String(100), default="application/octet-stream")
    encrypted_on_device: Mapped[bool] = mapped_column(default=True)
    verified: Mapped[bool] = mapped_column(Boolean, default=False)
    uploaded_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)

    report: Mapped[Report] = relationship(back_populates="evidences")


class CustodyEntry(Base):
    """سلسلة الحفظ — كل إجراء على البلاغ موثق بسلسلة هاش غير قابلة للكسر"""

    __tablename__ = "custody_entries"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    report_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("reports.id"), index=True
    )
    action: Mapped[str] = mapped_column(String(60))
    actor: Mapped[str] = mapped_column(String(120), default="system")
    notes: Mapped[str | None] = mapped_column(String(400), nullable=True)
    timestamp: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)

    # السلسلة المشفرة — أي تعديل تاريخي يكسر التحقق
    previous_hash: Mapped[str | None] = mapped_column(String(64), nullable=True)
    current_hash: Mapped[str | None] = mapped_column(String(64), nullable=True, index=True)

    report: Mapped[Report] = relationship(back_populates="custody")
