"""واجهات السير العمل القانوني — أوامر موثقة مع توليد المستند الرسمي"""
from datetime import datetime
from html import escape

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import HTMLResponse
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.core.deps import get_db, require_roles
from app.models.audit import AuditLog
from app.models.legal import LegalOrder
from app.models.report import Report
from app.models.user import User
from app.services.notify import manager

router = APIRouter(prefix="/legal", tags=["legal"])

DASHBOARD_ROLES = ("admin", "supervisor", "investigator")

ORDER_TYPES = {"warrant", "takedown", "seizure"}
TARGET_TYPES = {"device", "cloud", "isp"}


class CreateOrderIn(BaseModel):
    order_type: str
    court_number: str = Field(min_length=1, max_length=60)
    judge_name: str = Field(min_length=1, max_length=120)
    target_type: str = "device"
    target_ref: str | None = None
    related_report_id: str | None = None
    related_case_id: str | None = None


class ExecuteIn(BaseModel):
    notes: str | None = Field(default=None, max_length=500)
    # عند تنفيذ أمر سحابي يُنشأ طلب إزالة تلقائياً لهذا المزود
    cloud_provider: str = Field(default="google", max_length=30)


def _order_out(order: LegalOrder) -> dict:
    return {
        "id": order.id,
        "order_number": order.order_number,
        "order_type": order.order_type,
        "court_number": order.court_number,
        "judge_name": order.judge_name,
        "target_type": order.target_type,
        "target_ref": order.target_ref,
        "related_report_id": order.related_report_id,
        "related_case_id": order.related_case_id,
        "status": order.status,
        "issued_at": order.issued_at,
        "executed_at": order.executed_at,
        "execution_notes": order.execution_notes,
    }


@router.post("/orders", status_code=status.HTTP_201_CREATED)
def create_order(
    payload: CreateOrderIn,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(*DASHBOARD_ROLES)),
) -> dict:
    if payload.order_type not in ORDER_TYPES:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_ENTITY,
            f"نوع الأمر يجب أن يكون: {', '.join(sorted(ORDER_TYPES))}",
        )
    if payload.target_type not in TARGET_TYPES:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_ENTITY,
            f"الهدف يجب أن يكون: {', '.join(sorted(TARGET_TYPES))}",
        )

    order = LegalOrder(
        order_number=LegalOrder.generate_order_number(),
        order_type=payload.order_type,
        court_number=payload.court_number,
        judge_name=payload.judge_name,
        target_type=payload.target_type,
        target_ref=payload.target_ref,
        related_report_id=payload.related_report_id,
        related_case_id=payload.related_case_id,
        issued_by=user.id,
    )
    db.add(order)
    db.add(
        AuditLog(
            actor=user.phone_number,
            action="legal_order_issued",
            entity_type="legal_order",
            entity_id=order.id,
            details={"type": payload.order_type, "court": payload.court_number},
        )
    )
    db.commit()
    db.refresh(order)
    return _order_out(order)


@router.get("/orders")
def list_orders(
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(*DASHBOARD_ROLES)),
) -> list[dict]:
    orders = db.query(LegalOrder).order_by(LegalOrder.issued_at.desc()).all()
    return [_order_out(o) for o in orders]


@router.get("/orders/{order_id}")
def get_order(
    order_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(*DASHBOARD_ROLES)),
) -> dict:
    order = db.get(LegalOrder, order_id)
    if order is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "الأمر القانوني غير موجود")
    return _order_out(order)


@router.post("/orders/{order_id}/execute")
async def execute_order(
    order_id: str,
    payload: ExecuteIn,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(*DASHBOARD_ROLES)),
) -> dict:
    order = db.get(LegalOrder, order_id)
    if order is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "الأمر القانوني غير موجود")
    if order.status == "executed":
        raise HTTPException(status.HTTP_409_CONFLICT, "الأمر منفذ مسبقاً")

    order.status = "executed"
    order.executed_at = datetime.utcnow()
    order.execution_notes = payload.notes

    # التكامل: أمر سحابي منفَّذ يولّد طلب إزالة تلقائياً للمزود
    cloud_order_number = None
    if order.target_type == "cloud":
        from app.models.cloud import CloudOrder

        cloud = CloudOrder(
            order_number=CloudOrder.generate_order_number(),
            legal_order_id=order.id,
            report_id=order.related_report_id,
            provider=payload.cloud_provider,
            status="submitted",
        )
        db.add(cloud)
        db.flush()
        cloud_order_number = cloud.order_number

    db.add(
        AuditLog(
            actor=user.phone_number,
            action="legal_order_executed",
            entity_type="legal_order",
            entity_id=order.id,
            details={"cloud_order": cloud_order_number},
        )
    )
    db.commit()
    db.refresh(order)

    await manager.broadcast(
        {
            "type": "legal_order_executed",
            "order_number": order.order_number,
            "cloud_order": cloud_order_number,
        }
    )
    result = _order_out(order)
    result["cloud_order_number"] = cloud_order_number
    return result


@router.get("/orders/{order_id}/document", response_class=HTMLResponse)
def order_document(
    order_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(*DASHBOARD_ROLES)),
) -> HTMLResponse:
    """المستند الرسمي للأمر — قابل للطباعة PDF من المتصفح (RTL)"""
    order = db.get(LegalOrder, order_id)
    if order is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "الأمر القانوني غير موجود")

    type_labels = {
        "warrant": "مذكرة تفتيش",
        "takedown": "أمر إزالة محتوى",
        "seizure": "أمر ضبط",
    }
    target_labels = {"device": "جهاز إلكتروني", "cloud": "محتوى سحابي", "isp": "مزود خدمة"}

    html = f"""<!doctype html>
<html lang="ar" dir="rtl"><head><meta charset="utf-8">
<title>{escape(order.order_number)}</title>
<style>
  body {{ font-family: 'Segoe UI', Tahoma, sans-serif; margin: 40px; color: #14213d; }}
  .header {{ text-align: center; border-bottom: 3px solid #0d3b66; padding-bottom: 16px; }}
  .header h1 {{ color: #0d3b66; letter-spacing: 3px; }}
  table {{ width: 100%; border-collapse: collapse; margin-top: 24px; }}
  td, th {{ border: 1px solid #cbd5e1; padding: 10px 14px; text-align: right; }}
  th {{ background: #f0f4f9; width: 30%; }}
  .footer {{ margin-top: 40px; display: flex; justify-content: space-between; }}
  .stamp {{ border: 2px solid #0d3b66; padding: 10px 26px; border-radius: 8px; font-weight: bold; }}
  @media print {{ .noprint {{ display: none; }} }}
</style></head><body>
<div class="header">
  <h1>NAP-EX</h1>
  <p>المنصة الوطنية لمكافحة الابتزاز الإلكتروني</p>
  <h2>{escape(type_labels.get(order.order_type, order.order_type))}</h2>
</div>
<table>
  <tr><th>رقم الأمر</th><td dir="ltr">{escape(order.order_number)}</td></tr>
  <tr><th>المحكمة / الدائرة</th><td>{escape(order.court_number)}</td></tr>
  <tr><th>القاضي</th><td>{escape(order.judge_name)}</td></tr>
  <tr><th>الهدف</th><td>{escape(target_labels.get(order.target_type, order.target_type))}</td></tr>
  <tr><th>مرجع الهدف</th><td dir="ltr">{escape(order.target_ref or '—')}</td></tr>
  <tr><th>تاريخ الإصدار</th><td>{order.issued_at.strftime('%Y-%m-%d %H:%M')}</td></tr>
  <tr><th>الحالة</th><td>{'منفَّذ' if order.status == 'executed' else 'صادر'}</td></tr>
  {f'<tr><th>تاريخ التنفيذ</th><td>{order.executed_at.strftime("%Y-%m-%d %H:%M")}</td></tr>' if order.executed_at else ''}
</table>
<p style="margin-top:24px; line-height:2">
بناءً على البلاغ الموثق في المنصة والمستندات المرفقة بسلسلة الحفظ الرقمية،
صدر هذا الأمر لاتخاذ الإجراءات القانونية اللازمة وفق الأنظمة المعمول بها.
</p>
<div class="footer">
  <div class="stamp">خاتم الجهة المختصة</div>
  <div>توقيع القاضي: {escape(order.judge_name)}</div>
</div>
<p class="noprint" style="margin-top:30px; color:#5a6a85; font-size:12px">
للطباعة/الحفظ PDF: اضغط Ctrl+P من المتصفح.
</p>
</body></html>"""
    return HTMLResponse(html)
