"""إشعارات الضحية — إبلاغها تلقائياً بتطور قضيتها"""
import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.user import _now, _uuid


class VictimNotification(Base):
    __tablename__ = "victim_notifications"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    victim_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id"), index=True
    )
    report_id: Mapped[str | None] = mapped_column(String(36), nullable=True, index=True)

    # case_update | files_deleted | cloud_cleaned | general
    type: Mapped[str] = mapped_column(String(30), default="case_update")
    title: Mapped[str] = mapped_column(String(120))
    message: Mapped[str] = mapped_column(String(500))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now, index=True)
    read_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
