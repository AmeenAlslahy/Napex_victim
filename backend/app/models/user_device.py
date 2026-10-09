"""أجهزة المستخدمين — تسجيل أجهزة الضحايا (للإشعارات مستقبلاً)"""
import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.user import _now, _uuid


class UserDevice(Base):
    __tablename__ = "user_devices"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id"), index=True
    )
    device_id: Mapped[str] = mapped_column(String(100), index=True)
    device_model: Mapped[str | None] = mapped_column(String(120), nullable=True)
    os_version: Mapped[str | None] = mapped_column(String(60), nullable=True)
    fcm_token: Mapped[str | None] = mapped_column(String(255), nullable=True)
    last_seen_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)

    __table_args__ = (
        UniqueConstraint("user_id", "device_id", name="uq_user_device"),
    )
