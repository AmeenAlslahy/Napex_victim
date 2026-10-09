"""جدول القضايا الموحدة — تجميع عدة بلاغات لنفس المبتز في قضية واحدة"""
import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.models.user import _now, _uuid

CASE_STATUSES = {"open", "investigating", "resolved", "closed"}


def generate_case_number() -> str:
    return f"CASE-{uuid.uuid4().hex[:8].upper()}"


class Case(Base):
    __tablename__ = "cases"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    case_number: Mapped[str] = mapped_column(String(30), unique=True, index=True)
    title: Mapped[str] = mapped_column(String(200))
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    category: Mapped[str | None] = mapped_column(String(50), nullable=True)
    priority: Mapped[str] = mapped_column(String(20), default="medium", index=True)

    primary_victim_id: Mapped[str | None] = mapped_column(
        String(36), ForeignKey("users.id"), nullable=True
    )
    assigned_to: Mapped[str | None] = mapped_column(
        String(36), ForeignKey("users.id"), nullable=True, index=True
    )
    created_by: Mapped[str | None] = mapped_column(String(36), nullable=True)

    status: Mapped[str] = mapped_column(String(30), default="open", index=True)
    resolution: Mapped[str | None] = mapped_column(Text, nullable=True)

    reports_count: Mapped[int] = mapped_column(Integer, default=0)
    victims_count: Mapped[int] = mapped_column(Integer, default=0)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now, index=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)
    closed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    reports = relationship("Report", back_populates="case")
    notes = relationship(
        "CaseNote", back_populates="case", order_by="CaseNote.created_at"
    )
    updates = relationship(
        "CaseUpdate", back_populates="case", order_by="CaseUpdate.created_at"
    )


class CaseNote(Base):
    """ملاحظة محقق على القضية"""

    __tablename__ = "case_notes"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    case_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("cases.id"), index=True
    )
    author_id: Mapped[str | None] = mapped_column(String(36), nullable=True)
    author_name: Mapped[str] = mapped_column(String(160), default="")
    content: Mapped[str] = mapped_column(Text)
    is_internal: Mapped[bool] = mapped_column(default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)

    case: Mapped[Case] = relationship(back_populates="notes")


class CaseUpdate(Base):
    """تحديث على القضية — يظهر للضحية عند الربط"""

    __tablename__ = "case_updates"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    case_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("cases.id"), index=True
    )
    type: Mapped[str] = mapped_column(String(30), default="case_update")
    title: Mapped[str] = mapped_column(String(120))
    message: Mapped[str] = mapped_column(String(500))
    is_read: Mapped[bool] = mapped_column(default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now, index=True)

    case: Mapped[Case] = relationship(back_populates="updates")
