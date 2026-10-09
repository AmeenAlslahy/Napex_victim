"""إعدادات الخادم — تُقرأ من متغيرات البيئة أو .env"""
from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_name: str = "NAP-EX Backend"
    secret_key: str = "dev-secret-change-me-in-production"
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 30
    refresh_token_expire_days: int = 7

    database_url: str = "sqlite:///./napex.db"
    upload_dir: str = "uploads"

    # وضع التطوير: قبول أي رمز OTP من 6 أرقام لتسهيل التجربة
    # ⚠️ يجب تعطيله (false) في الإنتاج حتماً
    dev_accept_any_otp: bool = True

    cors_origins: str = "http://localhost:5173,http://localhost:4173"

    # ============ Observability ============
    metrics_enabled: bool = True
    sentry_dsn: str = ""

    # ============ Rate Limiting ============
    rate_limit_auth: str = "300/minute"
    rate_limit_reports: str = "300/minute"
    rate_limit_storage: str = "memory://"

    # ============ Blockchain Anchoring ============
    # فارغ = وضع Merkle المحلي (بلا إرسال) — يُملأ بشبكة اختبار في الإنتاج
    blockchain_rpc_url: str = ""
    blockchain_private_key: str = ""
    blockchain_contract_address: str = ""
    blockchain_chain_id: int = 11155111  # Sepolia

    # ============ البنية التحتية ============
    # فارغ = بدائل داخل الذاكرة (OTP/WS/كاش) — يُضبط في docker-compose للإنتاج
    redis_url: str = ""
    # جدولة الاحتفاظ التلقائية (يومياً 02:00) — تُفعّل في النشر
    scheduler_enabled: bool = False

    # ============ قائمة الحظر ============
    blocklist_cache_seconds: int = 30

    # ============ الإشعارات (كلها no-op حتى تُضبط) ============
    smtp_host: str = ""
    smtp_port: int = 587
    smtp_user: str = ""
    smtp_password: str = ""
    email_from: str = "napex@noreply.gov"
    sms_gateway_url: str = ""
    sms_api_key: str = ""
    fcm_server_key: str = ""

    # ============ مخزن الكائنات (S3/MinIO — اختياري) ============
    object_store_endpoint: str = ""
    object_store_access_key: str = ""
    object_store_secret_key: str = ""
    object_store_bucket: str = "napex-evidence"

    # ============ كاش قائمة الحظر ============
    blocklist_cache_seconds: int = 30


@lru_cache
def get_settings() -> Settings:
    return Settings()
