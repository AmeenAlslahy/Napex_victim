"""مخزن الكائنات — المحلي افتراضياً، S3/MinIO عند ضبط الإعدادات

الواجهة: save(key, data) -> path_or_uri / load(key) -> bytes / delete(key)
الاستخدام: نسخ الأدلة المختومة إلى مخزن خارجي (خارج مجلد uploads المحلي).
"""
import shutil
from pathlib import Path

from app.core.config import get_settings


class LocalObjectStore:
    """مخزن محلي — مجلد uploads داخل الخادم"""

    def __init__(self, base_dir: str) -> None:
        self._base = Path(base_dir)
        self._base.mkdir(parents=True, exist_ok=True)

    def save(self, key: str, data: bytes) -> str:
        target = self._base / key
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        return str(target)

    def load(self, key: str) -> bytes | None:
        target = self._base / key
        if not target.exists():
            return None
        return target.read_bytes()

    def delete(self, key: str) -> bool:
        target = self._base / key
        if target.exists():
            target.unlink()
            return True
        return False


class S3ObjectStore:
    """S3/MinIO — boto3 يُستورد عند الاستخدام فقط (حزمة اختيارية)"""

    def __init__(self, endpoint: str, access_key: str, secret_key: str, bucket: str) -> None:
        import boto3  # pragma: no cover — اختياري

        self._bucket = bucket
        self._client = boto3.client(
            "s3",
            endpoint_url=endpoint,
            aws_access_key_id=access_key,
            aws_secret_access_key=secret_key,
        )

    def save(self, key: str, data: bytes) -> str:
        self._client.put_object(Bucket=self._bucket, Key=key, Body=data)
        return f"s3://{self._bucket}/{key}"

    def load(self, key: str) -> bytes | None:
        from botocore.exceptions import ClientError  # pragma: no cover

        try:
            response = self._client.get_object(Bucket=self._bucket, Key=key)
            return response["Body"].read()
        except ClientError:
            return None

    def delete(self, key: str) -> bool:
        self._client.delete_object(Bucket=self._bucket, Key=key)
        return True


def create_object_store():
    """مصنع المخزن — S3 عند ضبط الإعدادات كاملة، وإلا المحلي"""
    s = get_settings()
    if s.object_store_endpoint and s.object_store_access_key:
        try:
            return S3ObjectStore(
                endpoint=s.object_store_endpoint,
                access_key=s.object_store_access_key,
                secret_key=s.object_store_secret_key,
                bucket=s.object_store_bucket,
            )
        except Exception:
            pass
    return LocalObjectStore(s.upload_dir)
