import 'package:flutter_test/flutter_test.dart';

import 'package:napex_victim_app/data/datasources/ml/keyword_classifier.dart';

void main() {
  late KeywordClassifier classifier;

  setUp(() {
    classifier = KeywordClassifier();
    classifier.loadFromMap({
      'k_factor': 6.0,
      'categories': {
        'extortion': {
          'default_weight': 3.0,
          'keywords': [
            {'phrase': 'عندي صورك', 'weight': 7},
            {'phrase': 'سأنشر', 'weight': 5},
            {'phrase': 'ادفع', 'weight': 2},
          ],
        },
        'spam': {
          'default_weight': 1.0,
          'keywords': ['عرض خاص', 'اشترك الان'],
        },
      },
      'recommendations': {
        'extortion': ['لا تدفع'],
      },
    });
  });

  group('KeywordClassifier', () {
    test('يكشف رسالة ابتزاز عربية عادية الصياغة', () {
      final result = classifier.classify('عندي صورك سأنشرها إذا ما ادفعت');

      expect(result.isExtortion, isTrue);
      expect(result.category.value, 'extortion');
      expect(result.confidence, greaterThan(0.85));
      expect(result.riskLevel.level, greaterThanOrEqualTo(3));
      expect(result.recommendations, isNotEmpty);
      expect(result.processingTimeMs, greaterThanOrEqualTo(0));
    });

    test('يتجاهل رسالة عادية تماماً', () {
      final result = classifier.classify('صباح الخير كيف حالك اليوم');

      expect(result.isExtortion, isFalse);
      expect(result.category.value, 'normal');
      expect(result.riskLevel.level, 0);
    });

    test('يصنف الإعلانات كسبام وليس ابتزازاً', () {
      final result = classifier.classify('عرض خاص اشترك الان في الخدمة');

      expect(result.isExtortion, isFalse);
      expect(result.category.value, 'spam');
    });

    test('يعمل مع التشكيل وحروف الهمزات المختلفة', () {
      // نفس الرسالة سابقاً لكن بتشكيل وألف مختلفة
      final result = classifier.classify('أعندي صُورَكِ سأنشرها');

      expect(result.isExtortion, isTrue);
    });

    test('نص فارغ يعطي نتيجة عادية', () {
      final result = classifier.classify('   ');
      expect(result.category.value, 'normal');
    });

    test('مصنف غير محمل يعطي نتيجة عادية', () {
      final notLoaded = KeywordClassifier();
      final result = notLoaded.classify('عندي صورك');
      expect(result.category.value, 'normal');
    });
  });
}
