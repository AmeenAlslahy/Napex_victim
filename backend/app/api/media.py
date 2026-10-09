"""واجهات حماية الوسائط — Watermark + بصمة إدراكية + السجل الوطني"""
import json
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, File, Form, HTTPException, Response, UploadFile
from sqlalchemy.orm import Session

from app.core.deps import get_db, require_roles
from app.models.perceptual_hash import PerceptualHashEntry
from app.models.user import User
from app.services.media_protection import (
    embed_watermark,
    extract_watermark,
    hamming_distance,
    perceptual_hash,
    sha256_hex,
)

router = APIRouter(prefix="/media", tags=["media"])

DASHBOARD_ROLES = ("admin", "supervisor", "investigator")

NEAR_MATCH_DISTANCE = 8


@router.post("/watermark")
async def watermark_image(
    reference: str = Form(..., description="مرجع التتبع: رقم بلاغ/قضية"),
    report_id: str | None = Form(default=None),
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(*DASHBOARD_ROLES)),
):
    """دمج بصمة خفية في الصورة + تسجيل البصمة الإدراكية في السجل الوطني"""
    data = await file.read()
    payload = {
        "reference": reference,
        "registered_by": user.phone_number,
        "original_hash": sha256_hex(data),
        "embedded_at": datetime.now(timezone.utc).isoformat(),
    }

    try:
        watermarked = embed_watermark(data, payload)
    except ValueError as exc:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, str(exc))

    phash = perceptual_hash(data)
    entry = PerceptualHashEntry(
        phash=phash,
        content_hash=payload["original_hash"],
        source="victim_media" if reference.startswith("EXT") is False else "evidence",
        report_id=report_id or None,
        watermark_payload=payload,
        registered_by=user.phone_number,
    )
    db.add(entry)
    db.commit()

    from fastapi import Response

    return Response(
        content=watermarked,
        media_type="image/png",
        headers={
            "X-Napex-Phash": phash,
            "X-Napex-Original-Hash": payload["original_hash"],
            "X-Napex-Payload": json.dumps(payload, ensure_ascii=False),
        },
    )


@router.post("/verify")
async def verify_image(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(*DASHBOARD_ROLES)),
):
    """فحص صورة: هل تحمل بصمة NAP-EX؟ وهل بصمتها الإدراكية في السجل الوطني؟"""
    data = await file.read()
    phash = perceptual_hash(data)
    watermark = extract_watermark(data)

    matches = (
        db.query(PerceptualHashEntry).filter(PerceptualHashEntry.phash == phash).all()
    )
    near_matches = [
        {
            "phash": row.phash,
            "distance": hamming_distance(phash, row.phash),
            "report_id": row.report_id,
        }
        for row in db.query(PerceptualHashEntry).all()
        if hamming_distance(phash, row.phash) <= NEAR_MATCH_DISTANCE
        and row.phash != phash
    ][:10]

    return {
        "phash": phash,
        "watermark": watermark,
        "registry_match": bool(matches),
        "registry_entries": [
            {"report_id": m.report_id, "registered_at": m.registered_at}
            for m in matches
        ],
        "near_matches": near_matches,
    }


@router.get("/phash/{phash}/lookup")
def lookup_phash(
    phash: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(*DASHBOARD_ROLES)),
):
    """البحث في السجل الوطني — تطابق تام + تطابات محتملة (هامينغ ≤ 8)"""
    exact = (
        db.query(PerceptualHashEntry)
        .filter(PerceptualHashEntry.phash == phash)
        .all()
    )
    all_entries = db.query(PerceptualHashEntry).all()
    near = [
        {
            "phash": row.phash,
            "distance": hamming_distance(phash, row.phash),
            "report_id": row.report_id,
        }
        for row in all_entries
        if row.phash != phash and hamming_distance(phash, row.phash) <= 8
    ]
    near.sort(key=lambda n: n["distance"])

    return {
        "exact": [
            {"report_id": e.report_id, "registered_at": e.registered_at}
            for e in exact
        ],
        "near": near[:10],
    }
