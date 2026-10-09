import 'package:flutter_test/flutter_test.dart';

import 'package:napex_victim_app/domain/entities/app_source.dart';
import 'package:napex_victim_app/domain/entities/message_category.dart';

void main() {
  group('AppSource', () {
    test('fromPackageName يعيد التطبيق الصحيح', () {
      expect(AppSource.fromPackageName('com.whatsapp'), AppSource.whatsapp);
      expect(
        AppSource.fromPackageName('com.facebook.orca'),
        AppSource.messenger,
      );
      expect(
        AppSource.fromPackageName('com.unknown.app'),
        AppSource.unknown,
      );
    });

    test('الحزم المجهولة أو sms تعود كمصدر رسائل نصية', () {
      expect(AppSource.fromPackageName('sms'), AppSource.sms);
      expect(AppSource.fromPackageName(''), AppSource.sms);
    });

    test('isEndToEndEncrypted صحيح لتطبيقات التشفير', () {
      expect(AppSource.whatsapp.isEndToEndEncrypted, isTrue);
      expect(AppSource.telegram.isEndToEndEncrypted, isTrue);
      expect(AppSource.signal.isEndToEndEncrypted, isTrue);
      expect(AppSource.sms.isEndToEndEncrypted, isFalse);
    });

    test('isSupported يفرق بين المعروف والمجهول', () {
      expect(AppSource.whatsapp.isSupported, isTrue);
      expect(AppSource.unknown.isSupported, isFalse);
    });
  });

  group('MessageCategory', () {
    test('fromValue يعيد القيمة الصحيحة مع fallback آمن', () {
      expect(
        MessageCategory.fromValue('extortion'),
        MessageCategory.extortion,
      );
      expect(
        MessageCategory.fromValue('no-such-category'),
        MessageCategory.normal,
      );
    });

    test('isDangerous وrequiresAction حسب الخطورة', () {
      expect(MessageCategory.threat.isDangerous, isTrue);
      expect(MessageCategory.extortion.requiresAction, isTrue);
      expect(MessageCategory.normal.requiresAction, isFalse);
    });
  });
}
