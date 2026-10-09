"""مخزن رموز OTP — Redis عند توفره، وإلا ذاكرة العملية (تطوير)"""
import logging
import secrets
import time

logger = logging.getLogger("napex.otp")


class MemoryOtpStore:
    """بدائل داخل الذاكرة — وضع التطوير/الاختبار"""

    def __init__(self) -> None:
        self._entries: dict[str, tuple[str, float]] = {}  # phone -> (code, expires_at)

    def set(self, phone: str, code: str, ttl_seconds: int) -> None:
        self._entries[phone] = (code, time.monotonic() + ttl_seconds)

    def verify(self, phone: str, code: str) -> bool:
        entry = self._entries.get(phone)
        if entry is None:
            return False
        stored_code, expires_at = entry
        if time.monotonic() > expires_at:
            self._entries.pop(phone, None)
            return False
        return secrets.compare_digest(stored_code, code)

    def pop(self, phone: str) -> None:
        self._entries.pop(phone, None)


class RedisOtpStore:
    """مخزن Redis — يعمل عبر تعدد workers"""

    def __init__(self, redis_client) -> None:
        self._redis = redis_client

    def set(self, phone: str, code: str, ttl_seconds: int) -> None:
        self._redis.setex(f"otp:{phone}", ttl_seconds, code)

    def verify(self, phone: str, code: str) -> bool:
        stored = self._redis.get(f"otp:{phone}")
        if stored is None:
            return False
        stored = stored.decode() if isinstance(stored, bytes) else str(stored)
        return secrets.compare_digest(stored, code)

    def pop(self, phone: str) -> None:
        self._redis.delete(f"otp:{phone}")


def create_otp_store(redis_url: str = ""):
    """مصنع المخزن — Redis عند التوفر مع سقوط آمن للذاكرة"""
    if redis_url:
        try:
            import redis as redis_lib

            client = redis_lib.Redis.from_url(
                redis_url,
                decode_responses=True,
                socket_connect_timeout=2,
            )
            client.ping()
            logger.info("OTP store: Redis")
            return RedisOtpStore(client)
        except Exception as exc:
            logger.warning("Redis unavailable (%s) — OTP falls back to memory", exc)

    logger.info("OTP store: in-memory")
    return MemoryOtpStore()


def generate_otp() -> str:
    return f"{secrets.randbelow(1_000_000):06d}"
