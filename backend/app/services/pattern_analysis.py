"""تحليل الأنماط — كشف المبتزين المحترفين عبر تجميع البلاغات حسب المُرسل"""
from collections import Counter, defaultdict
from datetime import datetime

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.report import Report

# عتبات تصنيف المبتز "المحترف"
PROFESSIONAL_MIN_VICTIMS = 2
PROFESSIONAL_MIN_REPORTS = 4
LONG_CAMPAIGN_DAYS = 30


def analyze_patterns(db: Session) -> list[dict]:
    reports = db.scalars(select(Report)).all()

    groups: dict[str, list[Report]] = defaultdict(list)
    for report in reports:
        key = report.sender_hash or report.sender_raw or "unknown"
        groups[key].append(report)

    profiles: list[dict] = []
    for key, items in groups.items():
        victims = len({r.victim_id for r in items if r.victim_id})
        apps = sorted({r.source_app for r in items})
        first_seen = min(r.message_timestamp for r in items)
        last_seen = max(r.message_timestamp for r in items)
        span_days = max((last_seen - first_seen).days, 0)
        categories = Counter(r.category for r in items)
        dominant_category = categories.most_common(1)[0][0]
        avg_confidence = sum(r.confidence for r in items) / len(items)

        is_professional = (
            victims >= PROFESSIONAL_MIN_VICTIMS
            or len(items) >= PROFESSIONAL_MIN_REPORTS
        )
        score = victims * 3 + len(items) + len(apps)
        if span_days >= LONG_CAMPAIGN_DAYS:
            score += 5

        sample = items[0]
        profiles.append(
            {
                "sender_key": key,
                "sender_display": sample.sender_display or sample.sender_raw or key,
                "sender_phone": sample.sender_phone,
                "victims": victims,
                "reports": len(items),
                "apps": apps,
                "first_seen": first_seen,
                "last_seen": last_seen,
                "span_days": span_days,
                "dominant_category": dominant_category,
                "avg_confidence": round(avg_confidence, 3),
                "is_professional": is_professional,
                "score": score,
            }
        )

    profiles.sort(key=lambda p: p["score"], reverse=True)
    return profiles
