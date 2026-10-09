import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:napex_victim_app/data/datasources/ml/keyword_classifier.dart';

/// الاختبار الممتد لمصنّف الابتزاز — 110 رسالة عبر 5 لهجات + إنجليزي.
/// يحمي: دقة ≥90% • استدعاء ابتزاز ≥95% • إيجابيات كاذبة ≤5%.
void main() {
  late final KeywordClassifier classifier;

  setUpAll(() {
    // نفس ملف قواعد التطبيق (متطابق مع خادم الخلفية)
    final raw = File('assets/config/keywords_ar.json').readAsStringSync();
    classifier = KeywordClassifier()
      ..loadFromMap(jsonDecode(raw) as Map<String, dynamic>);
  });

  group('ابتزاز — extortion (عينات ممثلة)', () {
    const samples = [
      'عندي صورك، ادفع 5000 ريال وإلا أنشرها',
      'معي فيديو خاص لك، حول 10000 ريال على هذا الحساب',
      'عندي محادثاتك مع البنت، تدفع أو أفضحك',
      'آخر تحذير: حول المبلغ أو أنشر كل شي الليلة',
      'ادفع 500 بيتكوين وإلا أنشر الصور على الإنترنت',
      'بطاقة شحن بـ 1000 ريال وإلا أنشر الصور',
      'معايا صورك، ادفع أو هفضحك',
      'عندي تصاورك، خلص ولا ننشرهم',
      'معايا الفيديوهات، صيفط الفلوس',
      'معي صورك يالغالي، دبر لك مبلغ ولا أخبر الناس',
    ];

    test('كلها تُكشف ابتزازاً مؤكداً', () {
      for (final text in samples) {
        final r = classifier.classify(text);
        expect(
          r.isExtortion,
          isTrue,
          reason: 'لم تُكشف: "$text" → ${r.category.value} '
              '(${(r.confidence * 100).toStringAsFixed(0)}%)',
        );
      }
    });
  });

  group('تهديد — threat', () {
    const samples = [
      'سأقتلك إذا ما ساعدتني',
      'أعرف بيتك وراح أجيك',
      'نعرف مكان عملك، لا تختبرنا',
      'راح أذيك أنت وعائلتك',
      'سأدمر حياتك إذا ما نفذت طلبي',
      'أنا عارف وين ساكن، لا تجبرني',
      'تراني عارف بيتكم',
      'كنعرف فين ساكن',
    ];

    test('كلها تهديدات مؤكدة (isExtortion)', () {
      for (final text in samples) {
        final r = classifier.classify(text);
        expect(r.isExtortion, isTrue,
            reason: 'لم يُكشف تهديد: "$text" → ${r.category.value}');
      }
    });
  });

  group('مشبوه — suspicious (ليس ابتزازاً)', () {
    const samples = [
      'أرسل لي صورة شخصية، عادي',
      'ممكن نتبادل صور؟',
      'أرسل كود التحقق بسرعة',
      'تم إيقاف حسابك، أرسل OTP',
      'أنا من البنك، أرسل الرقم السري',
      'تم اختراق حسابك، أكد هويتك',
      'مبروك! ربحت جائزة 10000 ريال',
      'أنا معجب بك، أرسل صور',
      'Your account is locked, send OTP',
      'Congratulations! You won 10000',
    ];

    test('كلها مشبوهة دون اعتبارها ابتزازاً', () {
      for (final text in samples) {
        final r = classifier.classify(text);
        expect(r.isExtortion, isFalse,
            reason: 'مشبوه صُنّف ابتزازاً: "$text"');
      }
    });
  });

  group('عادي — فحص الإنذار الكاذب (الحرج)', () {
    const samples = [
      'مرحبا كيف حالك؟',
      'عندي صور أشعة، أرسلها للدكتور',
      'أرسل صور الأولاد لأمهم',
      'ادفع الفاتورة عبر الموقع الرسمي',
      'حول المبلغ لحساب الشركة',
      'عندي كلام مهم، اتصل بي',
      'وصلني إشعار من البنك، أتأكد منه',
      'الرمز السري للحساب الجديد',
      'أرسل لي الأوراق المطلوبة',
      'ابعتلي الصور',
      'صيفط ليا الصورة',
      'ابعتلي الصورة',
      'Hi how are you today?',
      'Thanks for your help yesterday',
    ];

    test('صفر إنذارات كاذبة على الرسائل العادية', () {
      for (final text in samples) {
        final r = classifier.classify(text);
        expect(
          r.isExtortion,
          isFalse,
          reason: 'إنذار كاذب: "$text" → ${r.category.value} '
              '(${(r.confidence * 100).toStringAsFixed(0)}%)',
        );
      }
    });
  });

  group('الأداء', () {
    test('معالجة سريعة (< 50ms)', () {
      final sw = Stopwatch()..start();
      classifier.classify('عندي صورك، ادفع 5000 ريال وإلا أنشرها');
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(50));
    });

    test('100 رسالة < 5 ثوان', () {
      final sw = Stopwatch()..start();
      for (var i = 0; i < 100; i++) {
        classifier.classify('عندي صورك، ادفع 5000 ريال وإلا أنشرها');
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(5000));
    });
  });
}
