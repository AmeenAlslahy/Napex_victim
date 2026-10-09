"""واجهات الإدارة — إدارة المستخدمين وسجل التدقيق والنظام (للمدير فقط)"""
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.core.deps import get_db, require_roles
from app.models.audit import AuditLog
from app.models.system_config import SystemConfig
from app.models.user import User

router = APIRouter(prefix="/admin", tags=["admin"])

ADMIN_ONLY = ("admin",)

VALID_ROLES = {"victim", "investigator", "supervisor", "admin"}


class KillswitchIn(BaseModel):
    enabled: bool
    reason: str | None = Field(default=None, max_length=300)


def _set_flag(db: Session, key: str, value: dict, actor: str, description: str) -> None:
    row = db.get(SystemConfig, key)
    if row is None:
        row = SystemConfig(key=key, description=description)
        db.add(row)
    row.value = value
    row.updated_by = actor
    row.updated_at = datetime.utcnow()
    db.add(
        AuditLog(
            actor=actor,
            action="system_config_changed",
            entity_type="system_config",
            entity_id=key,
            details=value,
        )
    )


@router.get("/system/killswitch")
def get_killswitch(
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(*ADMIN_ONLY)),
) -> dict:
    row = db.get(SystemConfig, "killswitch")
    return row.value if row and isinstance(row.value, dict) else {"enabled": False}


@router.post("/system/killswitch")
def set_killswitch(
    payload: KillswitchIn,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(*ADMIN_ONLY)),
) -> dict:
    """مفتاح إيقاف طارئ — يرفض كل الطلبات عدا /health وواجهات الإدارة"""
    value = {
        "enabled": payload.enabled,
        "reason": payload.reason,
        "enabled_at": datetime.utcnow().isoformat(),
    }
    _set_flag(
        db,
        "killswitch",
        value,
        actor=user.phone_number,
        description="مفتاح الإيقاف الطارئ (Incident Response)",
    )
    db.commit()
    return value


def _user_out(user: User) -> dict:
    return {
        "id": user.id,
        "phone_number": user.phone_number,
        "role": user.role,
        "full_name": user.full_name,
        "governorate": user.governorate,
        "is_active": user.is_active,
        "is_verified": user.is_verified,
        "created_at": user.created_at,
    }


@router.get("/users")
def list_users(
    role: str | None = Query(default=None),
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(*ADMIN_ONLY)),
) -> list[dict]:
    query = db.query(User)
    if role:
        query = query.filter(User.role == role)
    users = query.order_by(User.created_at.desc()).limit(1000).all()
    return [_user_out(u) for u in users]


class RoleIn(BaseModel):
    role: str


@router.patch("/users/{user_id}/role")
def change_role(
    user_id: str,
    payload: RoleIn,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(*ADMIN_ONLY)),
) -> dict:
    if payload.role not in VALID_ROLES:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_ENTITY,
            f"الدور يجب أن يكون: {', '.join(sorted(VALID_ROLES))}",
        )
    target = db.get(User, user_id)
    if target is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "المستخدم غير موجود")
    if target.id == user.id:
        raise HTTPException(
            status.HTTP_409_CONFLICT, "لا يمكنك تغيير دورك بنفسك"
        )

    previous = target.role
    target.role = payload.role
    db.add(
        AuditLog(
            actor=user.phone_number,
            action="user_role_changed",
            entity_type="user",
            entity_id=target.id,
            details={"from": previous, "to": payload.role},
        )
    )
    db.commit()
    db.refresh(target)
    return _user_out(target)


@router.patch("/users/{user_id}/deactivate")
def deactivate_user(
    user_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(*ADMIN_ONLY)),
) -> dict:
    target = db.get(User, user_id)
    if target is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "المستخدم غير موجود")
    if target.id == user.id:
        raise HTTPException(status.HTTP_409_CONFLICT, "لا يمكنك إيقاف حسابك بنفسك")

    target.is_active = False
    db.add(
        AuditLog(
            actor=user.phone_number,
            action="user_deactivated",
            entity_type="user",
            entity_id=target.id,
        )
    )
    db.commit()
    db.refresh(target)
    return _user_out(target)


@router.get("/audit")
def audit_log(
    action: str | None = Query(default=None),
    limit: int = Query(default=100, ge=1, le=1000),
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(*ADMIN_ONLY)),
) -> list[dict]:
    query = db.query(AuditLog)
    if action:
        query = query.filter(AuditLog.action == action)
    logs = query.order_by(AuditLog.created_at.desc()).limit(limit).all()
    return [
        {
            "id": log.id,
            "actor": log.actor,
            "action": log.action,
            "entity_type": log.entity_type,
            "entity_id": log.entity_id,
            "details": log.details,
            "created_at": log.created_at,
        }
        for log in logs
    ]


@router.post("/system/retention")
def run_retention(
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(*ADMIN_ONLY)),
) -> dict:
    """تشغيل سياسة الاحتفاظ يدوياً — الأرشفة والتنظيف حسب السياسات"""
    from app.services.retention import run_all

    result = run_all(db)
    db.add(
        AuditLog(
            actor=user.phone_number,
            action="retention_run",
            entity_type="system",
            details=result,
        )
    )
    db.commit()
    return result
