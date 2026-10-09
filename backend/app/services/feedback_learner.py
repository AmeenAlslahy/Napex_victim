"""Feedback Loop — تحويل تقييمات الضحايا إلى تحسين فعلي للكشف

الدورة الكاملة:
1. الضحية تُقيّم بلاغاً (confirmed / false_positive / uncertain)
2. compute_keyword_overrides: الكلمات المتطابقة في البلاغات المؤكدة
   يرتفع وزنها (+15% لكل تأكيد)، وفي سوء الفهم ينخفض (-20% لكل خطأ)
3. الأوزان تُحفظ في system_config وتُطبق على المصنّف مباشرة
4. dataset للتصدير: كل تقييم = عينة (نص، فئة) جاهزة لتدريب TFLite
"""
import logging
from collections import defaultdict
from datetime import datetime, timezone

from sqlalchemy.orm import Session

from app.models.report import Report
from app.models.report_feedback import ReportFeedback
from app.models.system_config import SystemConfig

logger = logging.getLogger("napex.ml")

OVERRIDES_KEY = "keyword_weight_overrides"

BOOST_PER_CONFIRM = 0.15
PENALTY_PER_FALSE_POSITIVE = 0.20
MIN_FACTOR = 0.3
MAX_FACTOR = 2.0


def compute_keyword_overrides(db: Session) -> dict[str, float]:
    """حساب معاملات تعديل الأوزان من كل التقييمات المسجلة"""
    adjustments: dict[str, list[float]] = defaultdict(list)

    feedbacks = db.query(ReportFeedback).all()
    for feedback in feedbacks:
        report = db.get(Report, feedback.report_id)
        if report is None:
            continue

        keywords = (report.analysis or {}).get("keywords") or []
        if feedback.feedback_type == "confirmed":
            for keyword in keywords:
                adjustments[keyword].append(BOOST_PER_CONFIRM)
        elif feedback.feedback_type == "false_positive":
            for keyword in keywords:
                adjustments[keyword].append(-PENALTY_PER_FALSE_POSITIVE)

    overrides = {}
    for keyword, deltas in adjustments.items():
        factor = 1.0 + sum(deltas)
        overrides[keyword] = round(max(MIN_FACTOR, min(MAX_FACTOR, factor)), 3)
    return overrides


def persist_overrides(db: Session, overrides: dict[str, float], actor: str) -> None:
    """حفظ الأوزان في system_config ليُحمَّل عند إقلاع الخادم"""
    row = db.get(SystemConfig, OVERRIDES_KEY)
    if row is None:
        row = SystemConfig(
            key=OVERRIDES_KEY,
            description="معاملات تعديل أوزان كلمات الكشف من تغذية الضحايا الراجعة",
        )
    row.value = overrides
    row.updated_by = actor
    row.updated_at = datetime.now(timezone.utc)
    db.add(row)
    db.commit()


def load_persisted_overrides(db: Session) -> dict[str, float]:
    row = db.get(SystemConfig, OVERRIDES_KEY)
    if row is None or not isinstance(row.value, dict):
        return {}
    return row.value


def build_training_dataset(db: Session) -> list[dict]:
    """بناء مجموعة بيانات (text, label) من التقييمات — جاهزة لتدريب TFLite"""
    rows: list[dict] = []
    feedbacks = db.query(ReportFeedback).all()
    for feedback in feedbacks:
        report = db.get(Report, feedback.report_id)
        if report is None:
            continue

        if feedback.feedback_type == "confirmed":
            label = feedback.extortion_kind or "extortion"
        elif feedback.feedback_type == "false_positive":
            label = "normal"
        else:
            continue  # غير المتأكد لا يُستخدم للتدريب

        rows.append(
            {
                "text": report.content,
                "label": label,
                "source": "victim_feedback",
                "report_number": report.report_number,
            }
        )
    return rows


def retrain(db: Session, actor: str) -> dict:
    """إعادة التدريب (وضع القواعد): حساب الأوزان + تطبيقها فوراً + حفظها"""
    from app.services.classifier import classifier

    overrides = compute_keyword_overrides(db)
    classifier.apply_overrides(overrides)
    persist_overrides(db, overrides, actor)
    logger.info("Feedback retrain applied: %d keyword overrides", len(overrides))
    return overrides
