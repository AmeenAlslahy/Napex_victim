"""قائمة الحظر الوطنية — مرسلون أدينوا سابقاً بانتزاز"""
import uuid
from datetime import date, datetime

from sqlalchemy import Boolean, Date, DateTime, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.user import _now, _uuid


class BlocklistEntry(Base):
    __tablename__ = "blocklist_entries"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    sender_hash: Mapped[str] = mapped_column(String(64), index=True)
    phone_number: Mapped[str | None] = mapped_column(String(20), nullable=True, index=True)
    display_name: Mapped[str] = mapped_column(String(160), default="")
    reason: Mapped[str] = mapped_column(String(300), default="convicted_extortion")

    # المصدر: manual | court_order | pattern_alert
    source: Mapped[str] = mapped_column(String(30), default="manual", index=True)
    court_name: Mapped[str | None] = mapped_column(String(200), nullable=True)
    conviction_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    related_report_id: Mapped[str | None] = mapped_column(String(36), nullable=True)
    active: Mapped[bool] = mapped_column(Boolean, default=True)
    added_by: Mapped[str | None] = mapped_column(String(36), nullable=True)
    added_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)
    removed_by: Mapped[str | None] = mapped_column(String(36), nullable=True)
    removed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
