"""مولدات طلبات التكامل الخارجي — كلها وثائق رسمية جاهزة للتقديم

الفلسفة (موثقة في LEGAL_FRAMEWORK.md): النظام يُعد الطلب ويوثقه —
والإرسال يتم عبر القنوات الرسمية للجهة. الوضع الآلي (APIs) يُضاف لاحقاً
بموافقة كل مزود دون تغيير هذا التصميم.
"""
from app.models.cloud import CloudOrder
from app.models.report import Report


class TakedownRequestBuilder:
    """طلب إزالة محتوى موجه لمزود — نص رسمي جاهز للتقديم عبر بوابة المزود"""

    PORTALS = {
        "google": "https://support.google.com/legal/troubleshooter/1114905",
        "apple": "https://www.apple.com/legal/privacy/",
        "meta": "https://www.facebook.com/help/contact/144055245408684",
        "telegram": "mailto:abuse@telegram.org",
        "tiktok": "https://www.tiktok.com/legal/report/privacy",
        "snapchat": "https://help.snapchat.com/hc/requests/new",
        "other": "",
    }

    def build(self, provider: str, report: Report, cloud_order) -> str:
        portal = self.PORTALS.get(provider, "")
        portal_line = f"بوابة التقديم: {portal}" if portal else "التقديم: عبر القناة الرسمية للمزود"
        return "\n".join(
            [
                "طلب إزالة محتوى (Non-Consensual Intimate Imagery / Extortion)",
                "=" * 60,
                f"المزود: {provider}",
                f"رقم طلبنا الداخلي: {cloud_order.order_number}",
                f"بلاغ رسمي: {report.report_number} (موثق بسلسلة حفظ رقمية)",
                f"طابع الرسالة الأصلية: {report.message_timestamp.isoformat()}",
                "",
                "المطلوب:",
                "- إزالة المحتوى المخالف المرتبط بالبلاغ أعلاه",
                "- الاحتفاظ بالبيانات الوصفية للتحقيق وفق سياسة المزود",
                "",
                "السند القانوني: أمر قضائي/نيابة عامة مرفق",
                "جهة التواصل: وحدة مكافحة جرائم المعلوماتية — NAP-EX",
                "",
                "ملاحظة: الأدلة مشفرة ومحفوظة مع بصمة SHA-256 تثبت سلامتها.",
            ]
        )


class IspRequestBuilder:
    """طلب تعاون مع مزود خدمة الإنترنت — بأمر قضائي"""

    def build(self, report: Report, court_number: str) -> str:
        return "\n".join(
            [
                "طلب تعاون من مزود خدمة الإنترنت",
                "=" * 60,
                f"البلاغ: {report.report_number}",
                f"المحكمة/النيابة: {court_number}",
                f"الهاش الوطني للمبتز: {report.sender_hash}",
                f"الرقم/الحساب: {report.sender_raw}",
                "",
                "المطلوب وفق الإجراءات النافذة:",
                "- بيانات المشترك وقت الأحداث المشار إليها",
                "- سجل استخدام الرقم/الحساب في الفترة ذاتها",
                "",
                "مرفق: أمر قضائي ساري المفعول",
            ]
        )
