import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:napex_victim_app/presentation/features/onboarding/screens/welcome_screen.dart';
import 'package:napex_victim_app/presentation/shared/widgets/napex_card.dart';

void main() {
  group('Widget smoke tests', () {
    testWidgets('شاشة الترحيب تعرض العنوان وزر البدء', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: WelcomeScreen()),
      );
      // إنهاء مؤقتات الدخول المتحرك والرسوم
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(find.text('NAP-EX'), findsOneWidget);
      expect(find.text('منصة مكافحة الابتزاز الإلكتروني'), findsOneWidget);
      expect(find.text('ابدأ الآن'), findsOneWidget);
    });

    testWidgets('NapexCard يعرض المحتوى الداخلي', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NapexCard(child: Text('محتوى البطاقة')),
          ),
        ),
      );

      expect(find.text('محتوى البطاقة'), findsOneWidget);
    });
  });
}
