"""واجهات التحليل — تصنيف نصوص وتحليل أنماط المبتزين"""
from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.core.deps import get_current_user, get_db, require_roles
from app.models.user import User
from app.schemas.stats import PatternOut
from app.services.classifier import classifier
from app.services.pattern_analysis import analyze_patterns

router = APIRouter(prefix="/analysis", tags=["analysis"])

DASHBOARD_ROLES = ("admin", "supervisor", "investigator")


class ClassifyIn(BaseModel):
    text: str = Field(min_length=1, max_length=5000)


@router.post("/classify")
def classify_text(
    payload: ClassifyIn,
    user: User = Depends(get_current_user),
) -> dict:
    """تصنيف نص على الخادم — يُستخدم للاختبار ولمعالجة الرسائل المُعادة"""
    return classifier.classify(payload.text)


@router.get("/patterns", response_model=list[PatternOut])
def get_patterns(
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(*DASHBOARD_ROLES)),
) -> list[dict]:
    """قائمة المبتزين مرتبة بدرجة الخطورة — يبرز المحترفين أولاً"""
    return analyze_patterns(db)
