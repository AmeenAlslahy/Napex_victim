# NAP-EX — خطة التنفيذ الكاملة (12 مرحلة)

> خطة إكمال كل الفجوات المحددة في التدقيق المعماري — شاملة طبقات الملاحقة والاحتواء والبنية التحتية.
> الإجمالي التقريبي: **44 يوم عمل** — الترتيب يحترم الاعتماديات.

## ✅ المرحلة 0 — الامتثال والجاهزية (مكتملة)

| البند | الحالة |
|---|---|
| Feedback Loop فعلي (تقييمات → أوزان المصنّف → retrain + dataset) | ✅ + 3 اختبارات |
| GDPR: UserConsent + /me/consents + PRIVACY_POLICY.md v1.0 | ✅ |
| الحق في المحو: /auth/account يمحو الهوية ويفصل البلاغات | ✅ + اختبار |
| Incident Response: INCIDENT_RESPONSE.md + Killswitch (503 فوري) | ✅ + اختباران |
| Observability: Prometheus /metrics + عدادات مخصصة + Sentry اختياري | ✅ |
| تشفير حقول الخادم: EncryptedString + Blind Index (HMAC) للهواتف | ✅ |
| Alembic (env + ini) + scripts/migrate_sqlite_to_pg.py | ✅ |
| Load Testing: tests/load/locustfile.py | ✅ جاهز للتشغيل |

## ✅ المرحلتان 1 و2 — مكتملتان (قاعدة البيانات + القضايا)

| البند | الحالة |
|---|---|
| جداول جديدة: `cases` + `case_notes` + `case_updates` + `user_devices` + `analytics_events` | ✅ |
| أعمدة ناقصة: reports (case_id/content_hash/priority/reviewed_by/updated_at/deleted_at) · legal (served_at/document_hash/issued_by/valid_until) · cloud (files_list/submission_proof) · blocklist (source/إدانة/expires/removed_by) · audit (actor_id/old/new/request_id/severity) | ✅ |
| Alembic initial migration مولّد ومُتحقق (upgrade→downgrade→upgrade) | ✅ |
| Retention service + `POST /admin/system/retention` | ✅ |
| API `/cases` (إنشاء/ربط/ملاحظات/تحديثات/إسناد/حالة/حذف ناعم) | ✅ + 6 اختبارات |
| **Auto-link** بلاغات نفس sender_hash لقضية نشطة + عدّادات | ✅ |
| **قضية تلقائية للمبتز المحترف** مع ربط **أثر رجعي** لكل بلاغاته | ✅ |
| **تنبيه استباقي** `pattern_alert` عبر WS مرة واحدة عند لحظة الاكتشاف + audit | ✅ |
| لوحة التحكم: صفحة **القضايا** (سير الحالة/الأولوية/ملاحظات/تحديثات+إشعار الضحية) | ✅ |

**درس تقني موثق:** الجلسة `autoflush=False` → أي عدّاد بعد تعديل علاقة يتطلب `db.flush()` صريحاً؛
والتعديلات بعد آخر commit تحتاج commit إضافياً وإلا تُرجع للخلف عند إغلاق الجلسة.

## ✅ المرحلتان 3 و3ب — مكتملتان (سلسلة الحفظ المشفرة + البلوكشين)

| البند | الحالة |
|---|---|
| Custody Hash Chain: `previous_hash/current_hash` SHA-256 على كل إدخال حفظ | ✅ |
| توحيد كل نقاط الإنشاء عبر `append_custody_entry` (reports/evidence) | ✅ |
| `GET /reports/{id}/custody-verify` — إعادة حساب السلسلة + كشف التلاعب | ✅ + اختباران (سلامة + تلاعب يكسرها) |
| تطبيع timestamp (aware→UTC-naive) — درس SQLite roundtrip موثق | ✅ |
| عقد `EvidenceRegistry.sol` + ABI جاهز للنشر على Sepolia | ✅ |
| `web3_client`: ختم on-chain + **وضع offline-merkle** افتراضي (يعمل بلا شبكة) | ✅ |
| جدول `blockchain_anchors` + `POST /forensic/anchor` + `GET /forensic/anchor/{id}` + `GET /forensic/verify/{hash}` | ✅ + اختباران |
| Rate limiting (slowapi على auth) + Request-ID/Timing middleware | ✅ |

## ✅ المرحلة 4 — مكتملة (البنية التحتية)

| البند | الحالة |
|---|---|
| docker-compose كامل: **Postgres + Redis + backend + dashboard + Nginx gateway** (healthchecks + depends_on) | ✅ |
| `docker/nginx.conf`: SSL-ready + rate limit zone (20r/s) + WS upgrade + 25MB uploads | ✅ |
| **Redis**: مخزن OTP (RedisOtpStore/MemoryOtpStore مع سقوط آمن) + كاش قائمة الحظر (30 ثانية) | ✅ |
| **WS Pub/Sub عبر Redis** — يدعم تعدد workers/نسخ (fallback محلي تلقائي) | ✅ |
| **APScheduler** للاحتفاظ اليومي 02:00 (بوابة SCHEDULER_ENABLED) | ✅ |
| Makefile (16 أمراً) + pyproject.toml + requirements-dev.txt | ✅ |
| **CI مقسوم إلى 3 workflows**: mobile-ci / backend-ci / dashboard-ci | ✅ |

## ✅ المرحلة 5 — مكتملة (الإشعارات والتكاملات الخارجية)

| البند | الحالة |
|---|---|
| طبقة `notifications/`: Email (SMTP) + SMS (بوابة عامة) + Push (FCM) — كل قناة **no-op آمن حتى تُضبط** ولا ترفع استثناءات | ✅ |
| `NotificationDispatcher`: إشعار المحققين والمشرفين تلقائياً عند البلاغات الحرجة (BackgroundTask بجلسة مستقلة) | ✅ |
| Push مربوط بجدول `user_devices.fcm_token` | ✅ |
| `integrations/takedown.py`: مولد وثيقة طلب الإزالة الرسمي لكل مزود + `GET /international/takedown-document/{order}` | ✅ |
| `integrations/cross_border.py`: **Interpol Purple Notice builder + MLAT builder** | ✅ |
| جدول `international_requests` + API `/international` (بناء/قائمة/حالة/وثيقة) — تتبع كامل | ✅ |
| لوحة التحكم: صفحة **التعاون الدولي** (إصدار/وثيقة/حالات) | ✅ |
| `infrastructure/storage/`: LocalObjectStore + S3/MinIO adapter (boto3 اختياري) | ✅ |
| 7 اختبارات جديدة للمرحلة | ✅ |

## ✅ المرحلة 6 — مكتملة (حماية الوسائط)

| البند | الحالة |
|---|---|
| `media_protection.py`: **LSB Watermarking** (دمج/استخراج حمولة JSON في PNG) | ✅ + 3 اختبارات |
| **aHash** بصمة إدراكية مقاومة للقياس/السطوع + `hamming_distance` | ✅ |
| جدول `perceptual_hashes` (السجل الوطني) + `POST /media/watermark` + `POST /media/verify` + `GET /media/phash/{phash}/lookup` | ✅ + 4 اختبارات |
| `integrations/legal_notices.py`: **Cease & Desist** + **إشعار مسبق** | ✅ + endpoint |
| التطبيق: موارد StopNCII/INHOPE في شاشة الدعم | ✅ |
| Alembic regen (perceptual_hashes) | ✅ |

**ملاحظة فيزيائية صادقة:** LSB يبقى في PNG lossless — تعديل السطوع يشوهه (فيزياء البتات)،
لكن **aHash يلتقط النسخة المعدلة** — الطبقتان معاً تغطيان النشر المباشر والمعدل.

---

## 📋 المراحل المتبقية

| # | المرحلة | المدة | يعتمد على | المخرج |
|---|---|---|---|---|
| 7 | Content Safety (VPN + NSFW + Overlay) | 5 أيام | — (موبايل) | 5 طبقات حماية محتوى |
| 8 | Metadata Intelligence + الجودة | 3 أيام | 2 | بصمة سلوكية + ربط الأرقام الجديدة |
| 9 | Honeypot Management | 4 أيام | 1، 2 | وحدة عمليات الحسابات الفخة للجهة |
| 10 | Dark-web Monitoring | 5 أيام | 4، 5، 6 | رصد النشر + تنبيه الضحية + ربط Takedown |
| 11 | Terraform + Kubernetes + Monitoring | 5 أيام | 4 | IaC + نشر K8s + Prometheus/Grafana/Loki |
| 12 | الوثائق والتغطية النهائية | 2 يوم | الكل | DATABASE/SECURITY/DEPLOYMENT.md + اختبارات |

### تفاصيل مختصرة

- **7**: NSFW Detector (NudeNet→TFLite، فحص عند الفتح) + ContentFilterVpnService (StevenBlack/OISD) + VideoAnalyzer بعينة متدرجة + NSFWOverlay + Parental PIN.
- **8**: حقول metadata + بصمة سلوكية (كلمات/توقيت) لربط الأرقام الجديدة + رفع تغطية الاختبارات.
- **9**: honeypot_accounts/interactions/messages (مشفرة) + escalate→قضية + intelligence — إدارة الجهة حصراً.
- **10**: monitoring_targets/hits (بالبصمات فقط) + Worker مجدول (مصادر مفهرسة قانونياً) + ربط Takedown + إشعار الضحية.
- **11**: Terraform (VPS/firewall/DNS) + K8s Kustomize (backend/dashboard/Postgres/Redis + probes/HPA) + Prometheus/Grafana/Loki + GHCR deploy.
- **12**: DATABASE.md + SECURITY.md + DEPLOYMENT.md + README نهائي.

## 🚫 Backlog — بنود مرفوضة/مؤجلة بقرار موثق

| البند | القرار |
|---|---|
| Blockchain custody لكل إدخال (بدل جذر Merkle الدفعي) | مرفوض: تكلفة gas بلا قيمة |
| Honeypot تفاعلي آلي مع المبتز | مرفوض: إدارة الجهة حصراً |
| Dark-web زحف مباشر لأسواق غير قانونية | مرفوض: اختصاص الجهات الأمنية |
| Performance Benchmarks موثقة | مؤجل: مع المرحلة 8 |
| API Versioning (Sunset headers) | مؤجل: قبل أول مستخدم خارجي |
| i18n (EN/FR) + Accessibility (a11y) | مؤجل: بعد الاستقرار |
| Content Encryption الكامل (بحث token-based) | مؤجل: مع Postgres |

## 🎯 ترتيب التنفيذ الموصى به

```
0 ─ 1 ─ 2 ─ 3 ─ 3ب ─ 4 ─ 5 ─ 6 ──► 7 ─ 8 ─ 9 ─ 10 ─ 11 ─ 12
✅  ✅  ✅  ✅   ✅  ✅  ✅  ✅     ⏳ المتبقي (7-12)
```

> **تحديث 2026-10-07 — المرحلة 7 أصبحت فعّالة بالكامل (ولست بنيوياً فقط):**
> - نموذج NSFW حقيقي (`open_nsfw` TFLite، 5.7MB) مضمّن وغير مضغوط في APK، يعمل داخل Kotlin
>   عبر `org.tensorflow:tensorflow-lite:2.12.0` (AAR مباشر — تجاوز تعارض tflite_flutter مع
>   Kotlin المدمج؛ تطلب `android.uniquePackageNames=false` لتجاوز فحص تفرّد النطاقات في AGP 9).
> - قائمة الحظر الحقيقية: StevenBlack porn-only (76,793 نطاقاً) — كانت العينة الوهمية + خطأ
>   مسار الملف (.json مقابل .txt) يفشلان التحميل بصمت.
> - إصلاحات الربط: حوار موافقة VPN لم يكن يفتح (كان يُمرَّر applicationContext بدل Activity)،
>   وعلم تفعيل الحرس كان يُضبط على القناة لا الخدمة، والمتصفحات أُضيفت لتطبيقات المراقبة.
> - التدفّق: لقطة → تصنيف محلي 100% في الذاكرة → Overlay + إيقاف فوري عند تجاوز 0.70 →
>   بث نتيجة (بدون أي صورة) إلى Dart للإحصاء. عنوان الخادم للجهاز الحقيقي: `192.168.0.198`
>   (قابل للتجاوز بـ `--dart-define=NAPEX_API_URL=...`).
