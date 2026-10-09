"""واجهات التحقيق الجنائي الرقمي — من الضبط إلى الحذف الآمن الموثق"""
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.core.deps import get_db, require_roles
from app.models.audit import AuditLog
from app.models.blockchain_anchor import BlockchainAnchor
from app.models.forensic import ForensicCase
from app.models.report import Report
from app.models.user import User
from app.services.custody_chain import verify_chain
from app.services.victim_notify import notify_victim

router = APIRouter(prefix="/forensic", tags=["forensic"])

DASHBOARD_ROLES = ("admin", "supervisor", "investigator")


class CreateCaseIn(BaseModel):
    report_id: str | None = None


class SeizeIn(BaseModel):
    device_type: str = Field(min_length=1, max_length=40)
    device_identifier: str = Field(min_length=1, max_length=120)
    seizure_location: str = Field(min_length=1, max_length=200)
    officers: str = Field(min_length=1, max_length=300)


class ImageIn(BaseModel):
    imaging_tool: str = Field(min_length=1, max_length=60)
    image_hash: str = Field(min_length=8, max_length=64)


class ExtractIn(BaseModel):
    extracted_files_count: int = Field(ge=0)
    notes: str | None = Field(default=None, max_length=500)


class EraseIn(BaseModel):
    erase_method: str = Field(min_length=1, max_length=60)
    verification_hash: str = Field(min_length=8, max_length=64)


def _get_case(db: Session, case_id: str) -> ForensicCase:
    case = db.get(ForensicCase, case_id)
    if case is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "القضية الجنائية غير موجودة")
    return case


def _case_out(case: ForensicCase) -> dict:
    return {
        "id": case.id,
        "case_number": case.case_number,
        "report_id": case.report_id,
        "device_type": case.device_type,
        "device_identifier": case.device_identifier,
        "seizure_location": case.seizure_location,
        "seizure_at": case.seizure_at,
        "officers": case.officers,
        "imaging_tool": case.imaging_tool,
        "image_hash": case.image_hash,
        "extracted_files_count": case.extracted_files_count,
        "extraction_notes": case.extraction_notes,
        "erase_method": case.erase_method,
        "erase_verification_hash": case.erase_verification_hash,
        "erase_at": case.erase_at,
        "status": case.status,
        "created_at": case.created_at,
    }


@router.post("/cases", status_code=status.HTTP_201_CREATED)
def create_case(
    payload: CreateCaseIn,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(*DASHBOARD_ROLES)),
) -> dict:
    if payload.report_id is not None and db.get(Report, payload.report_id) is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "البلاغ المرتبط غير موجود")

    case = ForensicCase(
        case_number=ForensicCase.generate_case_number(),
        report_id=payload.report_id,
    )
    db.add(case)
    db.add(
        AuditLog(
            actor=user.phone_number,
            action="forensic_case_opened",
            entity_type="forensic_case",
            entity_id=case.id,
        )
    )
    db.commit()
    db.refresh(case)
    return _case_out(case)


@router.get("/cases")
def list_cases(
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(*DASHBOARD_ROLES)),
) -> list[dict]:
    cases = db.query(ForensicCase).order_by(ForensicCase.created_at.desc()).all()
    return [_case_out(c) for c in cases]


@router.get("/cases/{case_id}")
def get_case(
    case_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(*DASHBOARD_ROLES)),
) -> dict:
    return _case_out(_get_case(db, case_id))


@router.post("/cases/{case_id}/seize")
def seize_device(
    case_id: str,
    payload: SeizeIn,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(*DASHBOARD_ROLES)),
) -> dict:
    case = _get_case(db, case_id)
    case.device_type = payload.device_type
    case.device_identifier = payload.device_identifier
    case.seizure_location = payload.seizure_location
    case.officers = payload.officers
    case.seizure_at = datetime.utcnow()
    case.status = "seized"

    db.add(
        AuditLog(
            actor=user.phone_number,
            action="forensic_device_seized",
            entity_type="forensic_case",
            entity_id=case.id,
            details={"device": payload.device_type, "location": payload.seizure_location},
        )
    )
    db.commit()
    db.refresh(case)
    return _case_out(case)


@router.post("/cases/{case_id}/image")
def image_device(
    case_id: str,
    payload: ImageIn,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(*DASHBOARD_ROLES)),
) -> dict:
    case = _get_case(db, case_id)
    if case.status not in ("seized", "imaged"):
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_ENTITY,
            "يجب توثيق ضبط الجهاز قبل التصوير الجنائي",
        )
    case.imaging_tool = payload.imaging_tool
    case.image_hash = payload.image_hash
    case.status = "imaged"

    db.add(
        AuditLog(
            actor=user.phone_number,
            action="forensic_imaging_done",
            entity_type="forensic_case",
            entity_id=case.id,
            details={"tool": payload.imaging_tool, "hash": payload.image_hash[:16]},
        )
    )
    db.commit()
    db.refresh(case)
    return _case_out(case)


@router.post("/cases/{case_id}/extract")
def extract_files(
    case_id: str,
    payload: ExtractIn,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(*DASHBOARD_ROLES)),
) -> dict:
    case = _get_case(db, case_id)
    case.extracted_files_count = payload.extracted_files_count
    case.extraction_notes = payload.notes
    case.status = "extracted"
    db.commit()
    db.refresh(case)
    return _case_out(case)


@router.post("/cases/{case_id}/erase")
def secure_erase(
    case_id: str,
    payload: EraseIn,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(*DASHBOARD_ROLES)),
) -> dict:
    """توثيق الحذف الآمن للمحتوى المسترد — عبر إجراء رسمي على الجهاز المضبوط"""
    case = _get_case(db, case_id)
    case.erase_method = payload.erase_method
    case.erase_verification_hash = payload.verification_hash
    case.erase_at = datetime.utcnow()
    case.status = "erased"

    db.add(
        AuditLog(
            actor=user.phone_number,
            action="forensic_secure_erase",
            entity_type="forensic_case",
            entity_id=case.id,
            details={"method": payload.erase_method},
        )
    )

    # إبلاغ الضحية تلقائياً
    report = db.get(Report, case.report_id) if case.report_id else None
    notify_victim(
        db,
        victim_id=report.victim_id if report else None,
        notification_type="files_deleted",
        title="تم تنفيذ الحذف الآمن",
        message=(
            f"اكتمل الإجراء القانوني على جهاز المبتز في قضيتك "
            f"({case.case_number}) — طريقة الحذف: {payload.erase_method}"
        ),
        report_id=case.report_id,
    )
    db.commit()
    db.refresh(case)
    return _case_out(case)


@router.get("/cases/{case_id}/report")
def forensic_report(
    case_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(*DASHBOARD_ROLES)),
) -> dict:
    """التقرير الجنائي الرقمي الكامل للقضية"""
    case = _get_case(db, case_id)
    return {
        "case": _case_out(case),
        "workflow": {
            "seized": case.seizure_at is not None,
            "imaged": case.image_hash is not None,
            "extracted": case.extracted_files_count is not None,
            "erased": case.erase_at is not None,
        },
        "generated_at": datetime.utcnow().isoformat(),
        "generated_by": user.phone_number,
    }


# ============ Blockchain Anchoring (Phase 3ب) ============


class AnchorIn(BaseModel):
    report_id: str


@router.post("/anchor", status_code=status.HTTP_201_CREATED)
def anchor_custody_chain(
    payload: AnchorIn,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(*DASHBOARD_ROLES)),
) -> dict:
    """ختم سلسلة حفظ البلاغ: جذر Merkle يُحسب محلياً ويُرسل للشبكة إن كانت مهيأة"""
    from app.infrastructure.blockchain.web3_client import safe_anchor_on_chain
    from app.services.custody_chain import verify_chain

    report = db.get(Report, payload.report_id)
    if report is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "البلاغ غير موجود")

    existing = (
        db.query(BlockchainAnchor)
        .filter(BlockchainAnchor.report_id == report.id)
        .first()
    )
    if existing is not None:
        raise HTTPException(status.HTTP_409_CONFLICT, "البلاغ مختوم مسبقاً")

    valid, entries = verify_chain(db, report.id)
    if not valid or not entries:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_ENTITY,
            "سلسلة الحفظ غير سالمة — لا يمكن الختم قبل التحقق",
        )

    from app.infrastructure.blockchain.web3_client import build_merkle_root

    merkle_root = build_merkle_root([e["current_hash"] for e in entries])
    batch_id = f"BAT-{report.report_number or report.id[:12]}"

    on_chain = safe_anchor_on_chain(batch_id, merkle_root)

    anchor = BlockchainAnchor(
        report_id=report.id,
        batch_id=batch_id,
        merkle_root=merkle_root,
        entries_count=len(entries),
        chain="sepolia" if on_chain else "offline-merkle",
        tx_hash=on_chain["tx_hash"] if on_chain else None,
        block_number=on_chain["block_number"] if on_chain else None,
        anchored_by=user.phone_number,
    )
    db.add(anchor)
    db.add(
        AuditLog(
            actor=user.phone_number,
            action="custody_chain_anchored",
            entity_type="report",
            entity_id=report.id,
            severity="success",
            details={
                "batch_id": batch_id,
                "merkle_root": merkle_root[:16],
                "on_chain": on_chain is not None,
            },
        )
    )
    db.commit()
    db.refresh(anchor)

    return {
        "id": anchor.id,
        "batch_id": batch_id,
        "merkle_root": merkle_root,
        "entries_count": len(entries),
        "chain": anchor.chain,
        "tx_hash": anchor.tx_hash,
        "block_number": anchor.block_number,
        "anchored_at": anchor.anchored_at,
    }


@router.get("/anchor/{report_id}")
def get_anchor(
    report_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(*DASHBOARD_ROLES)),
) -> dict:
    anchor = (
        db.query(BlockchainAnchor)
        .filter(BlockchainAnchor.report_id == report_id)
        .first()
    )
    if anchor is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "لا يوجد ختم لهذا البلاغ")

    result = {
        "batch_id": anchor.batch_id,
        "merkle_root": anchor.merkle_root,
        "entries_count": anchor.entries_count,
        "chain": anchor.chain,
        "tx_hash": anchor.tx_hash,
        "block_number": anchor.block_number,
        "anchored_at": anchor.anchored_at,
    }

    # التحقق العام من الشبكة إن كانت مهيأة
    try:
        from app.infrastructure.blockchain.web3_client import verify_on_chain

        chain_check = verify_on_chain(anchor.batch_id, anchor.merkle_root)
        if chain_check.get("on_chain"):
            result["on_chain_verification"] = chain_check
    except Exception:
        pass
    return result


@router.get("/verify/{content_hash}")
def verify_hash_public(
    content_hash: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(*DASHBOARD_ROLES)),
) -> dict:
    """تحقق عام: هل هذا الهاش ضمن سلسلة حفظ مختومة؟"""
    from app.models.blockchain_anchor import BlockchainAnchor as BCA
    from app.services.custody_chain import verify_chain as verify

    anchors = db.query(BCA).all()
    for anchor in anchors:
        report = db.get(Report, anchor.report_id)
        if report is None:
            continue
        valid, entries = verify(db, report.id)
        matched = [e for e in entries if e["current_hash"] == content_hash]
        if matched:
            return {
                "found": True,
                "valid": valid,
                "batch_id": anchor.batch_id,
                "chain": anchor.chain,
                "tx_hash": anchor.tx_hash,
                "entry": matched[0],
            }
    return {"found": False}
