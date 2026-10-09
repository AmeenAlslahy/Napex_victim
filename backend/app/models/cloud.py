"""موديول الحذف السحابي (Cloud Takedown) — تتبع الطلبات لمزودي المنصات"""
import uuid
from datetime import datetime

from sqlalchemy import JSON, DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.user import _now, _uuid


class CloudOrder(Base):
    """طلب إزالة محتوى من مزود سحابي — التكامل الفعلي مع APIs المزودين يُضاف لاحقاً"""

    __tablename__ = "cloud_orders"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    order_number: Mapped[str] = mapped_column(String(30), unique=True, index=True)
    legal_order_id: Mapped[str | None] = mapped_column(
        String(36), ForeignKey("legal_orders.id"), nullable=True, index=True
    )
    report_id: Mapped[str | None] = mapped_column(
        String(36), ForeignKey("reports.id"), nullable=True, index=True
    )

    # google | apple | meta | telegram | tiktok | ...
    provider: Mapped[str] = mapped_column(String(30), index=True)
    provider_ref: Mapped[str | None] = mapped_column(String(120), nullable=True)
    files_count: Mapped[int] = mapped_column(Integer, default=0)
    files_list: Mapped[dict | None] = mapped_column(JSON, nullable=True)

    # Submission
    submission_proof_path: Mapped[str | None] = mapped_column(String(400), nullable=True)

    # draft -> submitted -> acknowledged -> actioned | rejected
    status: Mapped[str] = mapped_column(String(20), default="submitted", index=True)
    attempts: Mapped[int] = mapped_column(Integer, default=1)
    submitted_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)
    actioned_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    notes: Mapped[str | None] = mapped_column(String(500), nullable=True)

    @staticmethod
    def generate_order_number() -> str:
        return f"CO-{uuid.uuid4().hex[:8].upper()}"
