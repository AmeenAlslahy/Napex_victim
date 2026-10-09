"""واجهات قائمة الحظر الوطنية — مزامنة للأجهزة وفحص تلقائي للمرسلين"""
import json
from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.deps import get_current_user, get_db, require_roles
from app.models.blocklist import BlocklistEntry
from app.models.report import Report
from app.models.user import User

router = APIRouter(prefix="/blocklist", tags=["blocklist"])

DASHBOARD_ROLES = ("admin", "supervisor", "investigator")


class AddIn(BaseModel):
    sender_hash: str | None = Field(default=None, max_length=64)
    phone_number: str | None = Field(default=None, max_length=20)
    display_name: str = Field(default="", max_length=160)
    reason: str = Field(default="convicted_extortion", max_length=300)
    related_report_id: str | None = None


def _entry_out(entry: BlocklistEntry) -> dict:
    return {
        "id": entry.id,
        "sender_hash": entry.sender_hash,
        "phone_number": entry.phone_number,
        "display_name": entry.display_name,
        "reason": entry.reason,
        "related_report_id": entry.related_report_id,
        "active": entry.active,
        "added_at": entry.added_at,
    }


@router.get("")
def list_entries(
    since: str | None = Query(default=None, description="ISO date — المزامنة التزايدية"),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> list[dict]:
    settings = get_settings()

    # كاش Redis للقائمة الوطنية — الأجهزة تزامنها كثيفاً
    if settings.redis_url:
        try:
            import redis as redis_lib

            cache_key = f"blocklist_cache:{since or 'all'}"
            client = redis_lib.Redis.from_url(
                settings.redis_url, decode_responses=True, socket_connect_timeout=1
            )
            cached = client.get(cache_key)
            if cached:
                return json.loads(cached)
        except Exception:
            client = None
    else:
        client = None

    query = db.query(BlocklistEntry).filter(BlocklistEntry.active.is_(True))
    if since:
        try:
            since_dt = datetime.fromisoformat(since)
            query = query.filter(BlocklistEntry.added_at > since_dt)
        except ValueError:
            pass
    entries = query.order_by(BlocklistEntry.added_at.desc()).limit(5000).all()
    result = [_entry_out(e) for e in entries]

    if client is not None:
        try:
            client.setex(
                cache_key,
                settings.blocklist_cache_seconds,
                json.dumps(result, default=str),
            )
        except Exception:
            pass
    return result


@router.post("", status_code=status.HTTP_201_CREATED)
def add_entry(
    payload: AddIn,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(*DASHBOARD_ROLES)),
) -> dict:
    # إن أُرسل report_id فقط — استخرج بيانات المرسل من البلاغ
    if payload.related_report_id and not payload.sender_hash and not payload.phone_number:
        report = db.get(Report, payload.related_report_id)
        if report is None:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "البلاغ غير موجود")
        payload.sender_hash = report.sender_hash
        payload.phone_number = report.sender_phone
        payload.display_name = payload.display_name or report.sender_display

    if not payload.sender_hash and not payload.phone_number:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_ENTITY,
            "مطلوب sender_hash أو phone_number أو report_id",
        )

    duplicate = None
    if payload.sender_hash:
        duplicate = (
            db.query(BlocklistEntry)
            .filter(
                BlocklistEntry.sender_hash == payload.sender_hash,
                BlocklistEntry.active.is_(True),
            )
            .first()
        )
    if duplicate is None and payload.phone_number:
        duplicate = (
            db.query(BlocklistEntry)
            .filter(
                BlocklistEntry.phone_number == payload.phone_number,
                BlocklistEntry.active.is_(True),
            )
            .first()
        )
    if duplicate is not None:
        raise HTTPException(status.HTTP_409_CONFLICT, "المرسل مدرج بالفعل في القائمة")

    entry = BlocklistEntry(
        sender_hash=payload.sender_hash or "",
        phone_number=payload.phone_number,
        display_name=payload.display_name,
        reason=payload.reason,
        related_report_id=payload.related_report_id,
    )
    db.add(entry)
    db.commit()
    db.refresh(entry)
    return _entry_out(entry)


@router.delete("/{entry_id}")
def deactivate_entry(
    entry_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(*DASHBOARD_ROLES)),
) -> dict:
    entry = db.get(BlocklistEntry, entry_id)
    if entry is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "السجل غير موجود")
    entry.active = False
    db.commit()
    return {"id": entry.id, "active": False}
