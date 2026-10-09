"""إحصاءات لوحة التحكم"""
from datetime import datetime, timedelta

from fastapi import APIRouter, Depends
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.core.deps import get_db, require_roles
from app.models.report import Evidence, Report
from app.models.user import User
from app.schemas.stats import OverviewOut
from app.services.pattern_analysis import analyze_patterns

router = APIRouter(prefix="/stats", tags=["stats"])

DASHBOARD_ROLES = ("admin", "supervisor", "investigator")


@router.get("/overview", response_model=OverviewOut)
def overview(
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(*DASHBOARD_ROLES)),
) -> dict:
    now = datetime.utcnow()
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)

    total_reports = db.query(func.count(Report.id)).scalar() or 0
    today_reports = (
        db.query(func.count(Report.id))
        .filter(Report.created_at >= today_start)
        .scalar()
        or 0
    )
    total_victims = (
        db.query(func.count(User.id))
        .filter(User.role == "victim", User.is_active.is_(True))
        .scalar()
        or 0
    )
    total_evidences = db.query(func.count(Evidence.id)).scalar() or 0

    def group_counts(column) -> dict[str, int]:
        rows = db.query(column, func.count(Report.id)).group_by(column).all()
        return {row[0] or "unknown": row[1] for row in rows}

    by_day_rows = (
        db.query(
            func.date(Report.created_at),
            func.count(Report.id),
        )
        .filter(Report.created_at >= today_start - timedelta(days=13))
        .group_by(func.date(Report.created_at))
        .all()
    )
    counts_by_date = {str(row[0]): row[1] for row in by_day_rows}
    by_day = []
    for offset in range(13, -1, -1):
        day = (today_start - timedelta(days=offset)).date()
        by_day.append({"date": day.isoformat(), "count": counts_by_date.get(day.isoformat(), 0)})

    patterns = analyze_patterns(db)
    professional = sum(1 for p in patterns if p["is_professional"])
    top_senders = [
        {
            "sender_display": p["sender_display"],
            "victims": p["victims"],
            "reports": p["reports"],
            "is_professional": p["is_professional"],
            "score": p["score"],
        }
        for p in patterns[:5]
    ]

    return {
        "total_reports": total_reports,
        "today_reports": today_reports,
        "total_victims": total_victims,
        "total_evidences": total_evidences,
        "professional_senders": professional,
        "by_status": group_counts(Report.status),
        "by_category": group_counts(Report.category),
        "by_source": group_counts(Report.source_app),
        "by_day": by_day,
        "top_senders": top_senders,
    }
