"""واجهات الأدلة الرقمية — رفع وتنزيل مع التحقق من التجزئة"""
import secrets
from datetime import datetime, timezone
from pathlib import Path
from uuid import uuid4

from fastapi import (
    APIRouter,
    Depends,
    File,
    Form,
    HTTPException,
    UploadFile,
    status,
)
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.deps import get_current_user, get_db, require_roles
from app.core.security import sha256_hex
from app.models.audit import AuditLog
from app.models.report import Evidence, Report
from app.models.user import User
from app.services.custody_chain import append_custody_entry

router = APIRouter(prefix="/evidence", tags=["evidence"])

DASHBOARD_ROLES = ("admin", "supervisor", "investigator")


@router.post("/upload", status_code=status.HTTP_201_CREATED)
async def upload_evidence(
    report_id: str = Form(...),
    file_hash: str = Form(...),
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> dict:
    """رفع دليل مشفر من الجهاز مع التحقق من مطابقة الهاش"""
    report = db.get(Report, report_id)
    if report is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "البلاغ غير موجود")

    data = await file.read()
    if len(data) == 0:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "ملف فارغ")
    if len(data) > 25 * 1024 * 1024:
        raise HTTPException(status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, "الملف أكبر من 25MB")

    actual_hash = sha256_hex(data)
    verified = secrets.compare_digest(actual_hash, file_hash.lower().strip())

    settings = get_settings()
    evidence_id = uuid4().hex
    destination = Path(settings.upload_dir) / report.id
    destination.mkdir(parents=True, exist_ok=True)
    target = destination / f"{evidence_id}.bin"
    target.write_bytes(data)

    evidence = Evidence(
        id=evidence_id,
        report_id=report.id,
        file_path=str(target),
        file_hash=actual_hash,
        file_size=len(data),
        mime_type=file.content_type or "application/octet-stream",
        encrypted_on_device=True,
        verified=verified,
    )
    db.add(evidence)
    append_custody_entry(
        db,
        report_id=report.id,
        action="evidence_received",
        actor=f"device:{user.phone_number}",
        notes=f"hash_verified={verified} sha256={actual_hash[:16]}…",
    )
    db.add(
        AuditLog(
            actor=user.phone_number,
            action="evidence_uploaded",
            entity_type="evidence",
            entity_id=evidence_id,
            details={"report_id": report.id, "verified": verified},
        )
    )
    db.commit()

    return {
        "id": evidence_id,
        "url": f"/api/v1/evidence/{evidence_id}",
        "verified": verified,
        "file_hash": actual_hash,
        "file_size": len(data),
        "uploaded_at": datetime.now(timezone.utc).isoformat(),
    }


@router.get("/{evidence_id}")
def download_evidence(
    evidence_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(*DASHBOARD_ROLES)),
) -> FileResponse:
    evidence = db.get(Evidence, evidence_id)
    if evidence is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "الدليل غير موجود")

    path = Path(evidence.file_path)
    if not path.exists():
        raise HTTPException(status.HTTP_404_NOT_FOUND, "الملف غير موجود على الخادم")

    return FileResponse(
        path,
        media_type=evidence.mime_type,
        filename=f"evidence_{evidence.id[:12]}.bin",
    )
