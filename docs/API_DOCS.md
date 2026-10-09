# NAP-EX — توثيق واجهات الخادم (API v1)

> Base URL: `http://<host>:8000/api/v1` — التوثيق التفاعلي: `/docs` (Swagger)
> المصادقة: `Authorization: Bearer <access_token>` — الأدوار: V=victim, I=investigator, S=supervisor, A=admin

## 1. المصادقة `/auth`

| Endpoint | الوصول | الوصف |
|---|---|---|
| `POST /auth/register` | عام | تسجيل ضحية + توليد OTP (صالح 3 دقائق) |
| `POST /auth/verify-otp` | عام | تحقق → JWT (access + refresh) + المستخدم |
| `POST /auth/login` | عام | دخول لوحة التحكم (هاتف + كلمة مرور) |
| `POST /auth/refresh` | عام | تجديد التوكنات |
| `POST /auth/logout` | مصادق | تسجيل خروج |
| `GET /auth/me` | مصادق | بيانات المستخدم الحالي |
| `DELETE /auth/account` | مصادق | إيقاف الحساب |

**تسجيل:**
```json
POST /auth/register
{ "phone_number": "+967771234567", "full_name": "سارة", "governorate": "تعز" }
→ 200 { "user": { "id": "...", "phone_number": "...", "role": "victim", ... } }
→ 409 إذا كان مسجلاً مسبقاً
```

**التحقق (وضع التطوير: أي 6 أرقام):**
```json
POST /auth/verify-otp
{ "phone_number": "+967771234567", "otp": "123456" }
→ 200 { "access_token": "...", "refresh_token": "...", "expires_in": 1800, "user": {...} }
→ 401 رمز خاطئ / 404 حساب غير موجود
```

## 2. البلاغات `/reports`

| Endpoint | الوصول | الوصف |
|---|---|---|
| `POST /reports` | مصادق (التطبيق) | **استقبال بلاغ** → رقم رسمي EXT-YYYY-XXXXXX + سلسلة حفظ + بث WS |
| `GET /reports` | I/S/A | قائمة + فلاتر: `status, category, q, page, page_size` |
| `GET /reports/{id}` | I/S/A | التفاصيل + الأدلة + سلسلة الحفظ |
| `PATCH /reports/{id}/status` | I/S/A | تحديث الحالة (received/under_review/investigating/resolved/closed/rejected) |
| `POST /reports/{id}/feedback` | مالك البلاغ | **تغذية راجعة**: `confirmed / false_positive / uncertain` + `extortion_kind` (financial/sexual/reputation/threat/other) |
| `GET /reports/feedback/summary` | I/S/A | مؤشر جودة الكشف: `confirmed_precision` |

**إرسال بلاغ (العقد مع تطبيق الجهاز):**
```json
POST /reports
{
  "local_id": "uuid",
  "sender": { "raw": "+967...", "display_name": "...", "phone_number": "...", "sender_hash": "sha256" },
  "content": "نص الرسالة",
  "source_app": "com.whatsapp",
  "analysis": { "category": "extortion", "confidence": 0.92, "risk_level": "high",
                "is_extortion": true, "probabilities": {}, "keywords": [], "threat_phrases": [] },
  "message_timestamp": "2026-10-05T10:00:00Z",
  "created_at": "2026-10-05T10:01:00Z",
  "status": "pending"
}
→ 201 { "id": "...", "report_number": "EXT-2026-14E8F6", "status": "received", "received_at": "..." }
```

## 3. الأدلة `/evidence`

| Endpoint | الوصول | الوصف |
|---|---|---|
| `POST /evidence/upload` | مصادق | `multipart`: file + `report_id` + `file_hash` — **تحقق SHA-256** على الخادم (حد 25MB) |
| `GET /evidence/{id}` | I/S/A | تنزيل الدليل |

الاستجابة تُظهر `"verified": true/false` — الدليل غير المطابق يُحفظ مع توثيق عدم المطابقة في سلسلة الحفظ.

## 4. التحليل والأنماط `/analysis`

| Endpoint | الوصول | الوصف |
|---|---|---|
| `POST /analysis/classify` | مصادق | `{ "text": "..." }` → تصنيف محرك القواعد على الخادم |
| `GET /analysis/patterns` | I/S/A | قائمة المبتزين بدرجة الخطورة — **محترف** = ضحيتان+ أو 4 بلاغات+ |

## 5. الإحصاءات `/stats`

| Endpoint | الوصول | الوصف |
|---|---|---|
| `GET /stats/overview` | I/S/A | إجماليات + by_status/category/source + by_day (14 يوماً) + top_senders |

## 6. التحقيق الجنائي `/forensic`

| Endpoint | الوصول | الوصف |
|---|---|---|
| `POST /forensic/cases` | I/S/A | فتح قضية (ربط اختياري ببلاغ) → `FC-XXXXXXXX` |
| `GET /forensic/cases` · `GET /cases/{id}` | I/S/A | قائمة/تفاصيل |
| `POST /cases/{id}/seize` | I/S/A | ضبط: نوع الجهاز + المعرف + المكان + الضباط |
| `POST /cases/{id}/image` | I/S/A | تصوير جنائي: الأداة + SHA-256 للنسخة (يشترط الضبط أولاً → 422) |
| `POST /cases/{id}/extract` | I/S/A | توثيق عدد الملفات المستردة |
| `POST /cases/{id}/erase` | I/S/A | **حذف آمن**: الطريقة (DOD 5220.22-M / NIST 800-88) + هاش تحقق → **إشعار الضحية تلقائياً** |
| `GET /cases/{id}/report` | I/S/A | التقرير الجنائي الكامل + حالة كل مرحلة |

سير العمل: `opened → seized → imaged → extracted → erased`

## 7. السير القانوني `/legal`

| Endpoint | الوصول | الوصف |
|---|---|---|
| `POST /legal/orders` | I/S/A | إصدار أمر: `warrant/takedown/seizure` + المحكمة + القاضي + الهدف (`device/cloud/isp`) → `LO-XXXXXXXX` |
| `GET /legal/orders` · `/{id}` | I/S/A | قائمة/تفاصيل |
| `POST /orders/{id}/execute` | I/S/A | تنفيذ — **الهدف السحابي يولّد CloudOrder تلقائياً** + بث WS |
| `GET /orders/{id}/document` | I/S/A | **المستند الرسمي** (HTML عربي RTL قابل للطباعة PDF) |

## 8. الحذف السحابي `/cloud`

| Endpoint | الوصول | الوصف |
|---|---|---|
| `POST /cloud/orders` | I/S/A | طلب يدوي: `provider` (google/apple/meta/telegram/tiktok/snapchat/other) |
| `GET /cloud/orders` | I/S/A | القائمة |
| `PATCH /orders/{id}/status` | I/S/A | `submitted → acknowledged → actioned/rejected` — **actioned يُبلغ الضحية تلقائياً** |
| `POST /orders/{id}/retry` | I/S/A | إعادة إرسال (attempts + 1) |

## 9. الضحية والإشعارات `/victim`

| Endpoint | الوصول | الوصف |
|---|---|---|
| `POST /victim/notify` | I/S/A | إشعار يدوي (يُستنتج الضحية من البلاغ إن لم يُحدد) |
| `GET /victim/notifications` | مصادق | إشعاراتي |
| `GET /victim/notifications/all` | I/S/A | كل الإشعارات (لوحة) |
| `PATCH /notifications/{id}/read` | المالك/I/S/A | تعليم كمقروء |

أنواع الإشعارات: `case_update` · `files_deleted` · `cloud_cleaned` · `general`

## 10. قائمة الحظر `/blocklist` + الشخصية `/me/blocklist`

| Endpoint | الوصول | الوصف |
|---|---|---|
| `GET /blocklist?since=` | مصادق (مزامنة الأجهزة) | الإدخالات النشطة |
| `POST /blocklist` | I/S/A | إضافة (من report_id يستنتج المرسل) — منع تكرار 409 |
| `DELETE /blocklist/{id}` | I/S/A | إيقاف إدخال |
| `GET/POST/DELETE /me/blocklist` | مصادق | **قائمة الحظر الشخصية** لكل حساب |
| `GET /me/export` | مصادق | **تصدير كل بيانات المستخدم JSON** |

## 11. الإدارة `/admin`

| Endpoint | الوصول | الوصف |
|---|---|---|
| `GET /admin/users?role=` | A | قائمة المستخدمين |
| `PATCH /admin/users/{id}/role` | A | تغيير الدور (لا يمكن تغيير دورك بنفسك → 409) |
| `PATCH /admin/users/{id}/deactivate` | A | إيقاف حساب |
| `GET /admin/audit?action=&limit=` | A | سجل التدقيق الكامل |

## 12. WebSocket `/ws?token=<access>`

الرسائل الواردة للوحة:
```json
{ "type": "new_report", "report": {...} }
{ "type": "status_change", "report_number": "EXT-...", "status": "under_review", "by": "..." }
{ "type": "legal_order_executed", "order_number": "LO-...", "cloud_order": "CO-..." }
```
العميل يرسل `ping` كل 25 ثانية ← `{"type": "pong"}`. رمز غير صالح → إغلاق 4401.

## 13. الصحة

`GET /health` و`GET /api/v1/health` → `{"status": "ok", "service": "napex-backend", "version": "1.0.0"}`

## أكواد الأخطاء الموحدة

| الكود | المعنى |
|---|---|
| 401 | رمز مفقود/منتهي — التطبيق يجدد تلقائياً |
| 403 | دور غير مخوّل (RBAC) |
| 404 | غير موجود |
| 409 | تعارض (مكرر / منفذ مسبقاً / إجراء على الذات) |
| 422 | بيانات غير صالحة — `detail` يشرح القيم المسموحة |
