"""واجهات المصادقة — متوافقة مع AuthApi في تطبيق الجهاز"""
import logging
import secrets
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, Request, Response, status
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.deps import get_current_user, get_db
from app.core.limits import limiter
from app.core.security import (
    decode_token,
    hash_password,
    issue_tokens,
    verify_password,
)
from app.models.audit import AuditLog
from app.models.user import User
from app.models.user_consent import UserConsent
from app.services.otp_store import create_otp_store, generate_otp
from app.schemas.auth import (
    LoginIn,
    RefreshIn,
    RegisterIn,
    TokenOut,
    UserOut,
    VerifyOtpIn,
)

router = APIRouter(prefix="/auth", tags=["auth"])
logger = logging.getLogger("napex.otp")

# مخزن OTP — Redis عند توفره، وإلا الذاكرة — في الإنتاج يُستبدل بمزود SMS فعلي
_otp_store = create_otp_store(get_settings().redis_url)
_OTP_TTL_SECONDS = 180


def _user_out(user: User) -> dict:
    return UserOut(
        id=user.id,
        phone_number=user.phone_number,
        role=user.role,
        full_name=user.full_name,
        email=user.email,
        governorate=user.governorate,
        is_active=user.is_active,
        is_verified=user.is_verified,
        created_at=user.created_at,
    ).model_dump()


@router.post("/register")
@limiter.limit(get_settings().rate_limit_auth)
def register(request: Request, payload: RegisterIn, db: Session = Depends(get_db)) -> dict:
    existing = (
        db.query(User).filter(User.phone_number == payload.phone_number).first()
    )
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="رقم الهاتف مسجل مسبقاً",
        )

    user = User(
        phone_number=payload.phone_number,
        full_name=payload.full_name,
        email=payload.email,
        governorate=payload.governorate,
        role="victim",
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    # توليد OTP وتخزينه
    code = generate_otp()
    _otp_store.set(payload.phone_number, code, _OTP_TTL_SECONDS)
    logger.info("OTP for %s: %s (valid 3 minutes)", payload.phone_number, code)

    return {"user": _user_out(user)}


@router.post("/verify-otp", response_model=TokenOut)
@limiter.limit(get_settings().rate_limit_auth)
def verify_otp(request: Request, payload: VerifyOtpIn, db: Session = Depends(get_db)) -> dict:
    user = (
        db.query(User).filter(User.phone_number == payload.phone_number).first()
    )
    if user is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "الحساب غير موجود")

    settings = get_settings()
    accepted = False

    if settings.dev_accept_any_otp and payload.otp.isdigit() and len(payload.otp) == 6:
        # وضع التطوير فقط — يُعطَّل في الإنتاج
        accepted = True
    else:
        accepted = bool(_otp_store.verify(payload.phone_number, payload.otp))

    if not accepted:
        raise HTTPException(
            status.HTTP_401_UNAUTHORIZED, "رمز التحقق غير صحيح أو منتهي"
        )

    user.is_verified = True
    db.commit()
    _otp_store.pop(payload.phone_number)

    tokens = issue_tokens(user.id, user.role)
    tokens["user"] = _user_out(user)
    return tokens


@router.post("/login", response_model=TokenOut)
@limiter.limit(get_settings().rate_limit_auth)
def login(request: Request, payload: LoginIn, db: Session = Depends(get_db)) -> dict:
    user = (
        db.query(User).filter(User.phone_number == payload.phone_number).first()
    )
    if (
        user is None
        or not user.hashed_password
        or not verify_password(payload.password, user.hashed_password)
    ):
        raise HTTPException(
            status.HTTP_401_UNAUTHORIZED, "بيانات الدخول غير صحيحة"
        )
    if not user.is_active:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "الحساب موقوف")

    tokens = issue_tokens(user.id, user.role)
    tokens["user"] = _user_out(user)
    return tokens


@router.post("/refresh", response_model=TokenOut)
def refresh(payload: RefreshIn, db: Session = Depends(get_db)) -> dict:
    try:
        decoded = decode_token(payload.refresh_token)
    except Exception:
        raise HTTPException(
            status.HTTP_401_UNAUTHORIZED, "رمز التحديث غير صالح أو منتهي"
        )

    if decoded.get("type") != "refresh":
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "نوع الرمز غير صحيح")

    user = db.get(User, decoded.get("sub"))
    if user is None or not user.is_active:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "الحساب غير متاح")

    tokens = issue_tokens(user.id, user.role)
    tokens["user"] = _user_out(user)
    return tokens


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
def logout(user: User = Depends(get_current_user)) -> Response:
    # الرموز تُبطل جهة العميل — السجل يُوثَّق هنا
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/me", response_model=UserOut)
def me(user: User = Depends(get_current_user)) -> dict:
    return _user_out(user)


@router.delete("/account", status_code=status.HTTP_204_NO_CONTENT)
def delete_account(
    user: User = Depends(get_current_user), db: Session = Depends(get_db)
) -> Response:
    """الحق في المحو (Right to Erasure):

    - تُمحى بيانات الهوية نهائياً (الاسم/البريد/المحافظة/كلمة المرور)
    - يُجهل رقم الهاتف ويُفصل عن الحساب
    - تُفصل البلاغات عن الهوية (تبقى كأدلة قانونية مجهولة المصدر)
    - تُحذف الموافقات وتُوقف الحساب
    """
    from sqlalchemy import update as sa_update

    from app.models.report import Report

    db.query(UserConsent).filter(UserConsent.user_id == user.id).delete()

    # فصل البلاغات عن الهوية (تبقى كأدلة — قانون الاحتفاظ)
    db.execute(
        sa_update(Report).where(Report.victim_id == user.id).values(victim_id=None)
    )

    user.phone_number = f"erased-{user.id[:12]}"
    user.full_name = None
    user.email = None
    user.governorate = None
    user.hashed_password = None
    user.is_active = False
    user.is_verified = False

    db.add(
        AuditLog(
            actor="erased-user",
            action="account_erased",
            entity_type="user",
            entity_id=user.id,
            details={"gdpr": True},
        )
    )
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)

