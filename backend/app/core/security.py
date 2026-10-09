"""الأمان — تجزئة كلمات المرور (PBKDF2) وإصدار/فك رموز JWT"""
import hashlib
import hmac
import secrets
from datetime import datetime, timedelta, timezone
from typing import Literal

import jwt

from app.core.config import get_settings

_PBKDF2_ITERATIONS = 120_000
TokenType = Literal["access", "refresh"]


# ============ كلمات المرور ============

def hash_password(password: str) -> str:
    salt = secrets.token_hex(16)
    digest = hashlib.pbkdf2_hmac(
        "sha256", password.encode(), salt.encode(), _PBKDF2_ITERATIONS
    )
    return f"pbkdf2_sha256${_PBKDF2_ITERATIONS}${salt}${digest.hex()}"


def verify_password(password: str, stored: str) -> bool:
    try:
        _, iterations, salt, expected = stored.split("$")
        digest = hashlib.pbkdf2_hmac(
            "sha256", password.encode(), salt.encode(), int(iterations)
        )
        return hmac.compare_digest(digest.hex(), expected)
    except (ValueError, AttributeError):
        return False


# ============ JWT ============

def create_token(
    user_id: str, role: str, token_type: TokenType
) -> tuple[str, datetime]:
    settings = get_settings()
    now = datetime.now(timezone.utc)

    if token_type == "access":
        expires_at = now + timedelta(
            minutes=settings.access_token_expire_minutes
        )
    else:
        expires_at = now + timedelta(days=settings.refresh_token_expire_days)

    payload = {
        "sub": user_id,
        "role": role,
        "type": token_type,
        "iat": now,
        "exp": expires_at,
    }
    token = jwt.encode(payload, settings.secret_key, algorithm=settings.algorithm)
    return token, expires_at


def decode_token(token: str) -> dict:
    settings = get_settings()
    return jwt.decode(token, settings.secret_key, algorithms=[settings.algorithm])


def issue_tokens(user_id: str, role: str) -> dict:
    access, access_exp = create_token(user_id, role, "access")
    refresh, _ = create_token(user_id, role, "refresh")
    settings = get_settings()
    return {
        "access_token": access,
        "refresh_token": refresh,
        "token_type": "Bearer",
        "expires_in": settings.access_token_expire_minutes * 60,
        "expires_at": access_exp.isoformat(),
    }


# ============ أدوات ============

def generate_report_number(year: int | None = None) -> str:
    year = year or datetime.now(timezone.utc).year
    return f"EXT-{year}-{secrets.token_hex(3).upper()}"


def sha256_hex(data: bytes | str) -> str:
    if isinstance(data, str):
        data = data.encode()
    return hashlib.sha256(data).hexdigest()
