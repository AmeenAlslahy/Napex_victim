"""تغذية راجعة من الضحية على دقة الكشف — تحسين النظام وتوثيق الحالات"""
import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.user import _now, _uuid


class ReportFeedback(Base):
    """حكم الضحية على البلاغ: مؤكد / سوء فهم / غير متأكد"""

    __tablename__ = "report_feedbacks"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    report_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("reports.id"), index=True
    )
    victim_id: Mapped[str | None] = mapped_column(String(36), nullable=True, index=True)

    # confirmed | false_positive | uncertain
    feedback_type: Mapped[str] = mapped_column(String(20), index=True)
    extortion_kind: Mapped[str | None] = mapped_column(String(30), nullable=True)
    reason: Mapped[str | None] = mapped_column(String(300), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)
