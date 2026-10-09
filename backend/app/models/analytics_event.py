"""أحداث التحليلات — تُجمَّع من النظام (مجهولة الهوية)"""
from datetime import datetime

from sqlalchemy import JSON, DateTime, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.user import _now, _uuid


class AnalyticsEvent(Base):
    __tablename__ = "analytics_events"

    id: Mapped[int] = mapped_column(
        Integer, primary_key=True, autoincrement=True
    )
    event_type: Mapped[str] = mapped_column(String(40), index=True)
    user_id: Mapped[str | None] = mapped_column(String(36), nullable=True, index=True)
    session_id: Mapped[str | None] = mapped_column(String(36), nullable=True)
    properties: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=_now, index=True
    )
