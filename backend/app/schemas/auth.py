"""مخططات المصادقة — متوافقة مع واجهة تطبيق الجهاز"""
from datetime import datetime

from pydantic import BaseModel, Field


class RegisterIn(BaseModel):
    phone_number: str = Field(min_length=7, max_length=20)
    full_name: str | None = None
    email: str | None = None
    governorate: str | None = None


class UserOut(BaseModel):
    id: str
    phone_number: str
    role: str
    full_name: str | None = None
    email: str | None = None
    governorate: str | None = None
    is_active: bool = True
    is_verified: bool = False
    created_at: datetime | None = None


class VerifyOtpIn(BaseModel):
    phone_number: str
    otp: str = Field(min_length=6, max_length=6)


class LoginIn(BaseModel):
    phone_number: str
    password: str


class RefreshIn(BaseModel):
    refresh_token: str


class TokenOut(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "Bearer"
    expires_in: int
    user: UserOut | None = None
