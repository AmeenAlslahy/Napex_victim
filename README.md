# NAP-EX — منصة مكافحة الابتزاز الإلكتروني

**منظومة وطنية متكاملة من ثلاثة مكونات:**

| المكون | التقنية | المسار | الحالة |
|---|---|---|---|
| 📱 تطبيق الضحية | Flutter + Kotlin | `lib/`, `android/` | ✅ مكتمل — analyze نظيف، 33 اختبار، APK مبني |
| ⚙️ الخادم المركزي | FastAPI + SQLAlchemy | `backend/` | ✅ مكتمل — 19 اختبار، مختبر حياً |
| 🖥️ لوحة التحكم الحكومية | React + TypeScript + Vite | `dashboard/` | ✅ مكتمل — TypeScript نظيف، بناء ناجح |
| 🤖 نموذج TFLite | TensorFlow | `ml/` | 📦 كود التدريب جاهز — التدريب يحتاج بيانات |

## البدء السريع (المنظومة كاملة)

```bash
# 1. الخادم — طرفية 1
cd backend && pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000

# 2. لوحة التحكم — طرفية 2
cd dashboard && npm install && npm run dev
# ثم افتح http://localhost:5173
# دخول: +967000000000 / Admin@123

# 3. التطبيق — طرفية 3
flutter run    # على محاكي أندرويد (10.0.2.2 يوجه للخادم المحلي تلقائياً)
```

**رحلة كاملة للتجربة:** سجّل في التطبيق (أي OTP من 6 أرقام في وضع التطوير) →
اضغط «تحليل رسالة» والصق نص ابتزاز (مثال في `ml/dataset_sample.csv`) →
يُنشأ بلاغ برقم رسمي → يظهر **فوراً** في لوحة التحكم عبر WebSocket →
المحقق يحدّث حالة القضية وترى سلسلة الحفظ كاملة.

---

# 📱 تطبيق الضحية (تفاصيل)

تطبيق Flutter لحماية ضحايا الابتزاز الإلكتروني: يراقب الرسائل الواردة على الجهاز،
يحللها بمحرك ذكي يدعم العربية لكشف محاولات الابتزاز، ينبه المستخدم فوراً،
يحفظ الأدلة مشفرة مع بصمة (Hash) وسلسلة حفظ (Chain of Custody)،
وينشئ بلاغاً رسمياً يُرسل للمنصة الوطنية.

## ✅ حالة المشروع

| الفحص | النتيجة |
|---|---|
| `flutter analyze` | ✅ No issues found (0) |
| `flutter test` | ✅ 33/33 نجحت |
| `flutter build apk --debug` | ✅ تم البناء |
| المنصات | Android (كامل) + Windows/Web/Linux (وضع تجريبي بدون خدمات النظام) |

## 🏗️ المعمارية — Clean Architecture

```
┌────────────────────────────────────────────┐
│  Presentation  (Screens, Riverpod, Router) │
├────────────────────────────────────────────┤
│  Domain        (Entities, UseCases, Repos) │  ← نقي 100%
├────────────────────────────────────────────┤
│  Data          (Models, DAOs, APIs, Mappers)│
├────────────────────────────────────────────┤
│  Platform      (Kotlin Services, Channels) │
└────────────────────────────────────────────┘
```

- **Presentation → Domain فقط.** Domain لا يعتمد على شيء. Data → Domain.
- **DI:** Riverpod يدوياً (بدون codegen) — كل الاعتماديات في `presentation/providers/core_providers.dart`.
- **النتائج:** `Either<Failure, T>` (dartz) + صفوف Records `(T?, Failure?)` في المستودعات.
- **Offline-first:** كل بلاغ يُحفظ محلياً مشفراً أولاً، ويُحاول الإرسال، والفاشل يبقى في قائمة المزامنة.

## 🗂️ هيكل المشروع

```
lib/
├── main.dart                  # bootstrap: التهيئة + حقن الاعتماديات
├── app.dart                   # MaterialApp.router (عربي RTL)
├── core/
│   ├── constants/             # app, api, db, channels, security
│   ├── error/                 # failures (sealed), exceptions, error_handler
│   ├── network/               # dio_client + 4 interceptors (auth/retry/signature/logging)
│   ├── security/              # encryption (AES-256 + HMAC), secure storage, hash
│   ├── storage/               # local_storage (SharedPreferences)
│   ├── utils/                 # logger, arabic_normalizer, extensions
│   ├── theme/                 # ألوان وثيم موحد
│   └── router/                # go_router + redirect حسب حالة التدفق
├── domain/
│   ├── entities/              # message, report, evidence, analysis, user, sender…
│   ├── repositories/          # 7 واجهات
│   └── usecases/              # auth, analysis, report, collector
├── data/
│   ├── models/ + mappers/     # DTOs وتحويل صفوف DB
│   ├── datasources/local/     # sqflite + DAOs (messages/reports/evidences/audit)
│   ├── datasources/remote/    # Auth/Report/Evidence APIs (Dio يدوي)
│   ├── datasources/ml/        # KeywordClassifier (محرك القواعد العربية)
│   └── repositories/          # 7 تنفيذات (تشفير المحتوى قبل الحفظ دائماً)
├── platform/channels/         # MessageCollectorChannel + SecurityChannel
└── presentation/
    ├── providers/             # core, flow, auth, collector, reports, settings
    ├── features/              # onboarding, dashboard, reports, education, settings, shell
    ├── services/              # الإشعارات المحلية
    └── shared/widgets/        # بطاقات، أزرار، شارات خطورة، OTP…

android/…/kotlin/com/napex/napex_victim_app/
├── channels/                  # MessageCollectorChannel + SecurityChannel (Kotlin)
├── services/                  # Accessibility, NotificationListener, Sms, Foreground, EventBus
├── receivers/                 # SmsReceiver, BootReceiver
├── parser/ + config/          # محلل الإشعارات + التطبيقات المراقبة
assets/config/keywords_ar.json # معجم كشف الابتزاز (قابل للتحديث من الخادم)
```

## 🔄 سير العمل الأساسي

1. خدمة Kotlin تلتقط الرسالة (Accessibility / NotificationListener / SMS).
2. `MessageEventBus` → **EventChannel** → `MessageCollectorChannel` (Dart).
3. `CollectorController` → حفظ الرسالة مشفرة → `ProcessMessageUseCase`.
4. `KeywordClassifier` يحلل النص (تطبيع عربي + أوزان + منحنى ثقة `1-e^(-S/k)`).
5. ابتزاز مؤكد (ثقة ≥ 0.85) → إنشاء بلاغ → محاولة إرسال → إشعار فوري + حوار تنبيه.
6. البلاغات المعلقة تُزامَن يدوياً أو عند فتح التطبيق.

## 🔐 الأمان

- تشفير **AES-256-CBC + HMAC-SHA256** (Encrypt-then-MAC) لكل محتوى محفوظ.
- المفتاح الرئيسي في **flutter_secure_storage** (Keystore).
- تجزئة SHA-256 لكل دليل + تحقق سلامة + سجل تدقيق (سلسلة الحفظ).
- ترويسات توقيع لكل طلب (`X-Signature`, `X-Nonce`, `X-Request-Id`).
- إعادة محاولة بتراجع أُسّي، وتسجيل آمن يحجب الحقول الحساسة.

## 🧭 قرارات هندسية موثقة (Architecture Decision Notes)

| القرار | البديل المرفوض | السبب |
|---|---|---|
| **Either** في الـ UseCases و**Records** `(T?, Failure?)` في المستودعات | توحيد النمطين | نمطان متعمدان بحدود واضحة: المستودعات تُعيد Records (استدعاء مباشر خفيف)، والـ UseCases تلفها بـ `Either` لتوحيد دلالة الخطأ في Presentation. القاعدة موثقة هنا ومطبقة باتساق |
| **AES-CBC + HMAC (Encrypt-then-MAC)** | AES-GCM | حزمة `encrypt` لا توفر GCM بشكل موثوق؛ التحقق يتم **قبل** فك التشفير بمقارنة زمن ثابت — مكافئ أمنياً عملياً |
| محرك **القواعد اللغوية** كأول محرك | الانتظار لنموذج ML | يعمل الآن بلا بيانات، **قابل للتفسير** (يعرض العبارات المرصودة — مهم قضائياً)، والواجهة `MLRepository` تسمح باستبداله بنموذج TFLite من سطر واحد (كود التدريب في `ml/`) |
| الإعدادات في **SharedPreferences (JSON واحد)** | جدول settings في SQLite | إعدادات غير حساسة تُقرأ كتلة واحدة عند الإقلاع؛ SQLite محجوزة للبيانات الحساسة المشفرة |
| **دلالة فشل صريحة** في كل فتح إعدادات/صلاحية | ابتلاع الاستثناءات | أي فشل يظهر للمستخدم برسالة سبب + سلسلة بدائل |

## 🚀 التشغيل

```bash
# 1. الخادم — طرفية 1
cd backend && pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000

# 2. لوحة التحكم — طرفية 2
cd dashboard && npm install && npm run dev
# ثم افتح http://localhost:5173
# دخول: +967000000000 / Admin@123

# 3. التطبيق — طرفية 3
flutter run    # على محاكي أندرويد (10.0.2.2 يوجه للخادم المحلي تلقائياً)
```

**CI/CD:** `.github/workflows/ci.yml` يشغّل تلقائياً عند كل push:
`flutter analyze + flutter test` و`pytest` للخادم و`tsc + vite build` للوحة.

**وضع تجريبي محلي:** عند غياب الخادم، تظهر شاشة التسجيل خيار
«المتابعة في الوضع التجريبي» — الحماية والتحليل يعملان كاملاً على الجهاز،
والبلاغات تُرسل تلقائياً عند توفر الخادم.

## ⚙️ الإعداد للإنتاج

1. غيّر `ApiConstants.baseUrl` في `lib/core/constants/api_constants.dart`.
2. فعّل التحقق من بصمة التوقيع في `SecurityChannel.kt` (verifySignature).
3. أضف pinned certificates عند توفر شهادات الإنتاج.
4. لدمج نموذج TFLite لاحقاً: طبّق `MLRepository` بمحرك جديد دون تغيير أي طبقة أخرى.

> **ملاحظة عن أذونات SMS/Accessibility:** متجر Play يقيد هذه الأذونات؛
> هذا التطبيق موجه للتوزيع الحكومي/الرسمي أو التثبيت المباشر.
