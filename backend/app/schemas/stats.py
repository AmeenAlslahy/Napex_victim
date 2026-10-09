"""مخططات الإحصاءات وتحليل الأنماط"""
from datetime import datetime

from pydantic import BaseModel


class OverviewOut(BaseModel):
    total_reports: int
    today_reports: int
    total_victims: int
    total_evidences: int
    professional_senders: int
    by_status: dict[str, int]
    by_category: dict[str, int]
    by_source: dict[str, int]
    by_day: list[dict]  # [{date: '2026-10-05', count: 3}, ...]
    top_senders: list[dict]


class PatternOut(BaseModel):
    sender_key: str
    sender_display: str
    sender_phone: str | None
    victims: int
    reports: int
    apps: list[str]
    first_seen: datetime | None
    last_seen: datetime | None
    span_days: int
    dominant_category: str
    avg_confidence: float
    is_professional: bool
    score: int
