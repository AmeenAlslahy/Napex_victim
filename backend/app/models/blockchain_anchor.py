"""سجلات الختم على البلوكشين — جذر Merkle لسلسلة حفظ كل بلاغ"""
import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.user import _now, _uuid


class BlockchainAnchor(Base):
    __tablename__ = "blockchain_anchors"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    report_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("reports.id"), index=True
    )
    batch_id: Mapped[str] = mapped_column(String(40), unique=True, index=True)
    merkle_root: Mapped[str] = mapped_column(String(64))
    entries_count: Mapped[int] = mapped_column(Integer, default=0)

    # sepolia | offline-merkle
    chain: Mapped[str] = mapped_column(String(20), default="offline-merkle")
    tx_hash: Mapped[str | None] = mapped_column(String(80), nullable=True)
    block_number: Mapped[int | None] = mapped_column(Integer, nullable=True)

    anchored_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)
    anchored_by: Mapped[str | None] = mapped_column(String(120), nullable=True)
