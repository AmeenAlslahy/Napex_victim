"""واجهات الحساب الشخصي — الموافقات، تصدير البيانات

ملاحظة الخصوصية: الحظر الشخصي للضحية يُدار محلياً في التطبيق فقط
(لا يُرسل للخادم إطلاقاً) — انظر PersonalBlocklistDao في تطبيق Flutter."""
from datetime import datetime
from json import dumps

from fastapi import APIRouter, Depends, HTTPException, Response, status
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.core.deps import get_current_user, get_db
from app.models.report import Report
from app.models.user import User
from app.models.user_consent import (
    CONSENT_TYPES,
    CURRENT_POLICY_VERSION,
    UserConsent,
)

router = APIRouter(prefix="/me", tags=["me"])


class ConsentIn(BaseModel):
    consent_type: str
    granted: bool
    policy_version: str = Field(default=CURRENT_POLICY_VERSION, max_length=20)


def _consent_out(consent: UserConsent) -> dict:
    return {
        "consent_type": consent.consent_type,
        "granted": consent.granted,
        "policy_version": consent.policy_version,
        "granted_at": consent.granted_at,
        "revoked_at": consent.revoked_at,
    }


@router.get("/consents")
def list_consents(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> list[dict]:
    consents = (
        db.query(UserConsent)
        .filter(UserConsent.user_id == user.id)
        .all()
    )
    return [_consent_out(c) for c in consents]


@router.post("/consents")
def set_consent(
    payload: ConsentIn,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> dict:
    if payload.consent_type not in CONSENT_TYPES:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_ENTITY,
            f"نوع الموافقة يجب أن يكون: {', '.join(sorted(CONSENT_TYPES))}",
        )

    from datetime import datetime as dt

    consent = (
        db.query(UserConsent)
        .filter(
            UserConsent.user_id == user.id,
            UserConsent.consent_type == payload.consent_type,
        )
        .first()
    )
    if consent is None:
        consent = UserConsent(user_id=user.id, consent_type=payload.consent_type)
        db.add(consent)

    consent.granted = payload.granted
    consent.policy_version = payload.policy_version
    if payload.granted:
        consent.granted_at = dt.utcnow()
        consent.revoked_at = None
    else:
        consent.revoked_at = dt.utcnow()

    db.commit()
    db.refresh(consent)
    return _consent_out(consent)


@router.get("/export")
def export_my_data(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> Response:
    """تصدير بيانات الضحية كاملة (JSON) — حق الوصول الشخصي للبيانات"""
    reports = (
        db.query(Report)
        .filter(Report.victim_id == user.id)
        .order_by(Report.created_at.desc())
        .all()
    )

    payload = {
        "exported_at": datetime.utcnow().isoformat(),
        "account": {
            "phone_number": user.phone_number,
            "full_name": user.full_name,
            "governorate": user.governorate,
        },
        "reports": [
            {
                "report_number": r.report_number,
                "sender_display": r.sender_display,
                "sender_raw": r.sender_raw,
                "source_app": r.source_app,
                "content": r.content,
                "category": r.category,
                "risk_level": r.risk_level,
                "status": r.status,
                "message_timestamp": r.message_timestamp.isoformat(),
                "created_at": r.created_at.isoformat(),
            }
            for r in reports
        ],
    }

    return Response(
        content=dumps(payload, ensure_ascii=False, indent=2),
        media_type="application/json",
        headers={
            "Content-Disposition": 'attachment; filename="napex_my_data.json"'
        },
    )
