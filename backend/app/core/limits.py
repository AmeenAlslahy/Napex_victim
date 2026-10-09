"""حدود المعدل (Rate Limiting) — تُسجَّل في main وتُستهلك في الـ endpoints"""
from slowapi import Limiter
from slowapi.util import get_remote_address

from app.core.config import get_settings

limiter = Limiter(
    key_func=get_remote_address,
    default_limits=[],
    storage_uri=get_settings().rate_limit_storage,
)
