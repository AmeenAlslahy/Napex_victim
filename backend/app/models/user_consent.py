"""موافقات المستخدم — إدارة موافقة الخصوصية (GDPR-style)"""
import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.user import _now, _uuid

# أنواع الموافقات المدعومة
CONSENT_TYPES = {"analytics", "ai_training", "data_sharing"}
CURRENT_POLICY_VERSION = "1.0"


class UserConsent(Base):
    __tablename__ = "user_consents"
    __table_args__ = (
        UniqueConstraint("user_id", "consent_type", name="uq_user_consent_type"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id"), index=True
    )
    consent_type: Mapped[str] = mapped_column(String(40), index=True)
    granted: Mapped[bool] = mapped_column(Boolean, default=False)
    policy_version: Mapped[str] = mapped_column(String(20), default=CURRENT_POLICY_VERSION)
    granted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
