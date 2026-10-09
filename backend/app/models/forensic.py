"""موديول التحقيق الجنائي الرقمي — إدارة القضايا من الضبط إلى الحذف الآمن"""
import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.user import _now, _uuid


class ForensicCase(Base):
    """قضية جنائية رقمية — كل مرحلة موثقة بسلسلة الحفظ"""

    __tablename__ = "forensic_cases"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    case_number: Mapped[str] = mapped_column(String(30), unique=True, index=True)
    report_id: Mapped[str | None] = mapped_column(
        String(36), ForeignKey("reports.id"), nullable=True, index=True
    )

    # الضبط
    device_type: Mapped[str | None] = mapped_column(String(40), nullable=True)
    device_identifier: Mapped[str | None] = mapped_column(String(120), nullable=True)
    seizure_location: Mapped[str | None] = mapped_column(String(200), nullable=True)
    seizure_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    officers: Mapped[str | None] = mapped_column(String(300), nullable=True)

    # التصوير الجنائي (Forensic Imaging)
    imaging_tool: Mapped[str | None] = mapped_column(String(60), nullable=True)
    image_hash: Mapped[str | None] = mapped_column(String(64), nullable=True)

    # الاستخراج
    extracted_files_count: Mapped[int | None] = mapped_column(Integer, nullable=True)
    extraction_notes: Mapped[str | None] = mapped_column(String(500), nullable=True)

    # الحذف الآمن
    erase_method: Mapped[str | None] = mapped_column(String(60), nullable=True)
    erase_verification_hash: Mapped[str | None] = mapped_column(String(64), nullable=True)
    erase_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    # opened -> seized -> imaged -> extracted -> erased -> closed
    status: Mapped[str] = mapped_column(String(20), default="opened", index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)

    @staticmethod
    def generate_case_number() -> str:
        return f"FC-{uuid.uuid4().hex[:8].upper()}"
