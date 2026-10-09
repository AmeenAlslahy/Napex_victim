import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:napex_victim_app/data/datasources/ml/keyword_classifier.dart';

/// عينات ابتزاز واقعية (لهجة دارجة) — حماية من تراجع محرك الكشف.
/// أي رسالة من هذه يجب أن تُكشف ابتزازاً مؤكداً دائماً.
void main() {
  final classifier = KeywordClassifier();

  setUpAll(() {
    final raw = File('assets/config/keywords_ar.json').readAsStringSync();
    classifier.loadFromMap(jsonDecode(raw) as Map<String, dynamic>);
  });

  const samples = [
    'اذا ما ترسل لي 500 الف بنشر صورك واسمع بك',
    'اذا ما تنفذ اللي طلبته منه اعرف ان فضيحتك بتكون بين كل الناس',
    'معك مهله يومين والا ما تلوم الا نفسك',
    'اسمعي يابنت اذا ما ترسلي صورك وانت عارية كل شي بيوصل لعند اهلك ولعند الناس',
    'عندي صورك وادفع والا سارسلها لعائلتك',
    // الجولة الثانية — إخفاقات أُصلحت (حماية من التراجع)
    'أعرف وين تسكن، وراح أجيك أنت وعائلتك إذا ما ساعدتني',
    'انتبه لنفسك، أنا مستعد لك وأعرف مكان عملك',
    'راح أخبر كل الناس عنك وافضحك في كل مكان إذا ما سويت اللي أبغاه',
    'أنا لا أحب المشاكل، فقط أبغى حقي. عندي أشياء لك، إذا ما تفاهمنا ممكن تنتشر',
    'ههههه إذا ما ساعدتني راح أنشر صورك، أمزح أمزح',
  ];

  test('عينات الابتزاز الواقعية تُكشف مؤكدة بثقة كافية', () {
    for (final text in samples) {
      final result = classifier.classify(text);
      expect(
        result.isExtortion,
        isTrue,
        reason: 'لم تُكشف: "$text" → ${result.category.value} '
            '(${(result.confidence * 100).toStringAsFixed(0)}%)',
      );
      expect(
        result.confidence,
        greaterThanOrEqualTo(0.85),
        reason: 'ثقة منخفضة لـ "$text": ${result.confidence}',
      );
    }
  });

  test('الرسائل العادية لا تُنذر كذباً', () {
    const innocent = [
      'وين وصلت يا اخي اتصل بي لما تفضى',
      'عندي عرض خاص على الاشتراك خصم 50 بالمئة',
      'صباح الخير كيف حالك اليوم',
      // مشبوه/إزعاج — ليس ابتزازاً
      'مرحبا، ممكن ترسل لي صورة لك؟ أبي أتعرف عليك أكثر',
      'توصيل سريع لجميع المناطق، اتصل الآن: 777123456',
    ];
    for (final text in innocent) {
      final result = classifier.classify(text);
      expect(
        result.isExtortion,
        isFalse,
        reason: 'إنذار كاذب لـ "$text" → ${result.category.value} '
            '(${(result.confidence * 100).toStringAsFixed(0)}%)',
      );
    }
  });
}
