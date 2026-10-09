"""اعتماديات FastAPI — قاعدة البيانات والمصادقة والأدوار"""
from typing import Callable

from fastapi import Depends, Header, HTTPException, status
from sqlalchemy.orm import Session

from app.core.security import decode_token
from app.db.base import Base, SessionLocal, get_db as _get_db  # noqa: F401 (re-export)
from app.models.user import User

# ============ قاعدة البيانات ============
get_db: Callable[[], Session] = _get_db


# ============ المصادقة ============

def get_current_user(
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
) -> User:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="مصادقة مطلوبة",
        )

    token = authorization.removeprefix("Bearer ").strip()
    try:
        payload = decode_token(token)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="رمز غير صالح أو منتهي",
        )

    if payload.get("type") != "access":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="نوع الرمز غير صحيح",
        )

    user = db.get(User, payload.get("sub"))
    if user is None or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="الحساب غير موجود أو موقوف",
        )
    return user


def require_roles(*roles: str):
    """حراسة الأدوار (RBAC) — مثال: Depends(require_roles('admin', 'investigator'))"""

    def dependency(user: User = Depends(get_current_user)) -> User:
        if user.role not in roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="لا تملك صلاحية لهذا الإجراء",
            )
        return user

    return dependency
