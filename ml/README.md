# نموذج TFLite — تدريب ودمج

محرك القواعد اللغوية الحالي (`KeywordClassifier`) يعمل وتم اختباره —
هذا الدليل يرفع الدقة عبر نموذج تعلم آلي دون تغيير معمارية التطبيق:
واجهة `MLRepository` تسمح بتبديل المحرك من سطر واحد في الـ DI.

## 1. تجهيز البيانات

ملف CSV عمودين: `text,label` — الفئات المدعومة:
`normal, spam, suspicious, threat, extortion`

ابدأ بملف `dataset_sample.csv` كنموذج، ثم وسّع البيانات (الهدف: 500+ مثال لكل فئة).
مصادر التوسعة: رسائل مصنفة يدوياً، بيانات البلاغات الموثقة بعد المراجعة.

## 2. التدريب والتحويل

```bash
pip install tensorflow pandas scikit-learn
python train_extortion_classifier.py --data dataset.csv --out tflite/ --epochs 15
```

المخرجات (ثلاثة ملفات):
- `extortion_classifier.tflite` — النموذج
- `tokenizer.json` — معجم الرقمنة
- `labels.json` — الفئات بالترتيب

## 3. الدمج في Flutter

### أ. أضف الحزمة والملفات

```yaml
# pubspec.yaml
dependencies:
  tflite_flutter: ^0.11.0

flutter:
  assets:
    - assets/ml_models/
```

ضع الملفات الثلاثة في `assets/ml_models/`.

### ب. نفّذ محرك TFLite عبر نفس الواجهة

```dart
// lib/data/repositories/tflite_ml_repository_impl.dart
class TFLiteMLRepositoryImpl implements MLRepository {
  // loadModel(): يحمل النموذج + المعجم + الفئات
  // classifyText(): تطبيع عربي (نفس ArabicNormalizer) → رقمنة → استدلال → softmax
  // ادمج مع محرك القواعد: النتيجة النهائية = متوسط مرجح (0.7 * tflite + 0.3 * rules)
}
```

### ج. الاستبدال — سطر واحد

```dart
// lib/presentation/providers/core_providers.dart
final mlRepositoryProvider = Provider<MLRepository>(
  (ref) => TFLiteMLRepositoryImpl(/* ... */),  // بدل MLRepositoryImpl
);
```

لا شيء آخر يتغير — UseCases والواجهات كلها تعمل كما هي.

## 4. التوصية للمناقشة

اعرض الاثنين معاً:
1. **محرك القواعد** يعمل الآن — شفاف، قابل للتفسير (يعرض الكلمات المرصودة)، بلا بيانات.
2. **نموذج TFLite** خطة التطوير — يرفع الدقة مع البيانات ويتعلم من البلاغات المراجعة.

هذا يُظهر نضجاً هندسياً: قرار واعٍ بأجل واضح بدل وعود غير محققة.
