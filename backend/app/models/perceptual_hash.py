"""السجل الوطني للبصمات الإدراكية — كشف النشر اللاحق للمحتوى المسرب"""
import uuid
from datetime import datetime

from sqlalchemy import JSON, DateTime, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.user import _now, _uuid


class PerceptualHashEntry(Base):
    __tablename__ = "perceptual_hashes"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    phash: Mapped[str] = mapped_column(String(16), index=True)
    content_hash: Mapped[str] = mapped_column(String(64), index=True)
    source: Mapped[str] = mapped_column(String(30), default="investigator", index=True)
    report_id: Mapped[str | None] = mapped_column(
        String(36), ForeignKey("reports.id"), nullable=True, index=True
    )
    watermark_payload: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    registered_by: Mapped[str | None] = mapped_column(String(120), nullable=True)
    registered_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)
