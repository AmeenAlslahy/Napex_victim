"""مولدات التعاون الدولي — Interpol Notices وطلبات MLAT

كل المخرجات وثائق نصية رسمية جاهزة للمراجعة القانونية والتقديم عبر
القنوات الرسمية (I-24/7، القنوات الدبلوماسية) — النظام يُعد ولا يُرسل بنفسه.
"""
from app.models.report import Report


class InterpolNoticeBuilder:
    """إشعار Interpol (نمط بنفسجي — Modus Operandi) لمبتز عبر الحدود"""

    def build(self, report: Report, requesting_country: str, target_country: str) -> str:
        import json

        notice = {
            "notice_type": "purple",
            "subject": "Electronic extortion campaign — cross border",
            "requested_action": "locate / identify / cooperate with national investigation",
            "crimes": [
                "extortion",
                "cyberstalking",
                "non-consensual intimate imagery distribution",
            ],
            "sender_fingerprint": {
                "national_hash": report.sender_hash,
                "identifier": report.sender_raw,
                "display": report.sender_display,
                "platforms_used": [report.source_app],
            },
            "official_report": report.report_number,
            "requesting_country": requesting_country,
            "target_country": target_country,
        }
        return "INTERPOL PURPLE NOTICE (DRAFT)\n" + "=" * 40 + "\n" + json.dumps(
            notice, ensure_ascii=False, indent=2
        )


class MlatRequestBuilder:
    """طلب المساعدة القضائية المتبادلة (MLAT) — قالب عام يُكيَّف قانونياً"""

    def build(self, report: Report, target_country: str, crime_articles: list[str]) -> str:
        articles = "\n".join(f"  - {a}" for a in crime_articles) or "  - (حسب التشريع النافذ)"
        return "\n".join(
            [
                "MLAT — طلب مساعدة قضائية متبادلة (Mutual Legal Assistance Request)",
                "=" * 60,
                f"الدولة الطالبة: الجمهورية اليمنية — NAP-EX",
                f"الدولة المطلوبة: {target_country}",
                f"البلاغ الرسمي: {report.report_number}",
                "",
                "وقائع مختصرة:",
                f"  مبتز يستهدف مواطنين عبر منصات ({report.source_app})،",
                "  موثق بسلسلة حفظ رقمية وبأدلة مشفرة محفوظة.",
                "",
                "المطلوب من الدولة المطلوبة:",
                "  - تحديد المشترك/الحساب لدى مزودي الخدمة المحليين",
                "  - الحفظ المؤقت للبيانات الرقمية",
                "  - إشعارنا بالإجراءات المتخذة",
                "",
                "السند القانوني:",
                articles,
            ]
        )
