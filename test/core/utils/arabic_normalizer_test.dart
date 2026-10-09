import 'package:flutter_test/flutter_test.dart';

import 'package:napex_victim_app/core/utils/arabic_normalizer.dart';

void main() {
  group('ArabicNormalizer', () {
    test('يزيل التشكيل', () {
      expect(
        ArabicNormalizer.normalize('سَأَنْشُرُ صُوَرَك'),
        'سانشر صورك',
      );
    });

    test('يوحد أشكال الألف', () {
      expect(
        ArabicNormalizer.normalize('أنا آخذ إذنك'),
        'انا اخذ اذنك',
      );
    });

    test('يوحد الياء المقصورة والتاء المربوطة', () {
      expect(ArabicNormalizer.normalize('مستشفى صغيرة'), 'مستشفي صغيره');
    });

    test('يحول الأرقام العربية إلى لاتينية', () {
      expect(ArabicNormalizer.normalize('خلال ٢٤ ساعة'), 'خلال 24 ساعه');
    });

    test('يزيل التطويل ويوحد المسافات', () {
      expect(ArabicNormalizer.normalize('ادفـــع    الآن'), 'ادفع الان');
    });

    test('نص فارغ يبقى فارغاً', () {
      expect(ArabicNormalizer.normalize(''), '');
    });
  });
}
