import 'package:flutter_test/flutter_test.dart';

import 'package:napex_victim_app/domain/entities/analysis_result.dart';
import 'package:napex_victim_app/domain/entities/message_category.dart';
import 'package:napex_victim_app/domain/entities/risk_level.dart';

void main() {
  group('AnalysisResult', () {
    test('يتطلب إبلاغاً فورياً عند الثقة >= 0.85', () {
      const result = AnalysisResult(
        category: MessageCategory.extortion,
        confidence: 0.90,
        riskLevel: RiskLevel.high,
        isExtortion: true,
      );

      expect(result.requiresImmediateReport, isTrue);
      expect(result.requiresNotification, isTrue);
      expect(result.requiresEvidenceStorage, isTrue);
    });

    test('لا يتطلب إبلاغاً فورياً عند الثقة < 0.85', () {
      const result = AnalysisResult(
        category: MessageCategory.extortion,
        confidence: 0.70,
        riskLevel: RiskLevel.medium,
        isExtortion: true,
      );

      expect(result.requiresImmediateReport, isFalse);
      expect(result.requiresNotification, isTrue);
    });

    test('النتيجة العادية لا تتطلب أي إجراء', () {
      const result = AnalysisResult.normal;

      expect(result.requiresImmediateReport, isFalse);
      expect(result.requiresNotification, isFalse);
      expect(result.requiresEvidenceStorage, isFalse);
    });

    test('copyWith ينشئ نسخة محدثة دون تغيير الأصل', () {
      const result = AnalysisResult.normal;
      final updated = result.copyWith(
        category: MessageCategory.extortion,
        confidence: 0.95,
        isExtortion: true,
      );

      expect(updated.category, MessageCategory.extortion);
      expect(updated.confidence, 0.95);
      expect(updated.isExtortion, isTrue);
      expect(result.category, MessageCategory.normal);
    });

    test('المساواة تعمل بشكل صحيح', () {
      const r1 = AnalysisResult(
        category: MessageCategory.extortion,
        confidence: 0.9,
        riskLevel: RiskLevel.high,
        isExtortion: true,
      );
      const r2 = AnalysisResult(
        category: MessageCategory.extortion,
        confidence: 0.9,
        riskLevel: RiskLevel.high,
        isExtortion: true,
      );

      expect(r1, equals(r2));
    });

    test('JSON round-trip يحافظ على القيم', () {
      const result = AnalysisResult(
        category: MessageCategory.threat,
        confidence: 0.88,
        riskLevel: RiskLevel.high,
        isExtortion: false,
        keywords: ['سأقتلك'],
      );

      final restored = AnalysisResult.fromJson(result.toJson());

      expect(restored.category, MessageCategory.threat);
      expect(restored.confidence, 0.88);
      expect(restored.riskLevel, RiskLevel.high);
      expect(restored.keywords, ['سأقتلك']);
    });
  });

  group('RiskLevel.fromScore', () {
    test('يجيب المستويات الصحيحة', () {
      expect(RiskLevel.fromScore(0.98), RiskLevel.critical);
      expect(RiskLevel.fromScore(0.90), RiskLevel.high);
      expect(RiskLevel.fromScore(0.70), RiskLevel.medium);
      expect(RiskLevel.fromScore(0.40), RiskLevel.low);
      expect(RiskLevel.fromScore(0.10), RiskLevel.none);
    });
  });
}
