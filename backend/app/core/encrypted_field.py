"""حقول مشفرة على مستوى قاعدة البيانات + فهرس أعمى للبحث

EncryptedString: تشفير شفاف (Fernet — AES128-CBC + HMAC) بحقل نصي.
ملاحظة: Fernet غير حتمي (IV عشوائي) — لذا البحث بالتطابق يحتاج
Blind Index: هاش HMAC-SHA256 حتمي يُخزن في عمود منفصل (مثل *_hash).
"""
import base64
import hashlib
import hmac

from cryptography.fernet import Fernet
from sqlalchemy import String, TypeDecorator

from app.core.config import get_settings


def _fernet() -> Fernet:
    """مفتاح التشفير مشتق من SECRET_KEY (يُدار عبر env في الإنتاج)"""
    key = hashlib.sha256(get_settings().secret_key.encode()).digest()
    return Fernet(base64.urlsafe_b64encode(key))


class EncryptedString(TypeDecorator):
    """نص مشفر شفافياً في قاعدة البيانات"""

    impl = String
    cache_ok = True

    def process_bind_param(self, value, dialect):
        if value is None:
            return None
        return _fernet().encrypt(str(value).encode()).decode()

    def process_result_value(self, value, dialect):
        if value is None:
            return None
        try:
            return _fernet().decrypt(value.encode()).decode()
        except Exception:
            # بيانات قديمة كُتبت قبل تفعيل التشفير — تُعاد كما هي
            return value


def blind_hash(value: str) -> str:
    """هاش حتمي للبحث بالتطابق على الحقول المشفرة (HMAC بمفتاح الخادم)"""
    if not value:
        return ""
    return hmac.new(
        get_settings().secret_key.encode(),
        value.strip().encode(),
        hashlib.sha256,
    ).hexdigest()
