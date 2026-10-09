import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:napex_victim_app/core/error/failures.dart';
import 'package:napex_victim_app/domain/entities/analysis_result.dart';
import 'package:napex_victim_app/domain/entities/message_category.dart';
import 'package:napex_victim_app/domain/entities/risk_level.dart';
import 'package:napex_victim_app/domain/repositories/ml_repository.dart';
import 'package:napex_victim_app/domain/usecases/analysis/analyze_message_usecase.dart';

class MockMLRepository extends Mock implements MLRepository {}

void main() {
  late AnalyzeMessageUseCase useCase;
  late MockMLRepository mockRepository;

  setUp(() {
    mockRepository = MockMLRepository();
    useCase = AnalyzeMessageUseCase(mockRepository);
  });

  group('AnalyzeMessageUseCase', () {
    test('يعيد نتيجة عادية للرسالة الفارغة دون استدعاء المستودع', () async {
      const params = AnalyzeMessageParams(content: '   ');

      final result = await useCase(params);

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Should not fail'),
        (analysis) {
          expect(analysis.category, MessageCategory.normal);
          expect(analysis.isExtortion, isFalse);
        },
      );
      verifyNever(
        () => mockRepository.analyzeMessage(
          content: any(named: 'content'),
          mediaPath: any(named: 'mediaPath'),
          mediaType: any(named: 'mediaType'),
        ),
      );
    });

    test('يستدعي المستودع للرسالة غير الفارغة', () async {
      const params = AnalyzeMessageParams(content: 'ادفع أو سأنشر');
      const expectedResult = AnalysisResult(
        category: MessageCategory.extortion,
        confidence: 0.92,
        riskLevel: RiskLevel.high,
        isExtortion: true,
      );

      when(
        () => mockRepository.analyzeMessage(
          content: any(named: 'content'),
          mediaPath: any(named: 'mediaPath'),
          mediaType: any(named: 'mediaType'),
        ),
      ).thenAnswer((_) async => (expectedResult, null));

      final result = await useCase(params);

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Should not fail'),
        (analysis) {
          expect(analysis.isExtortion, isTrue);
          expect(analysis.confidence, 0.92);
        },
      );
      verify(
        () => mockRepository.analyzeMessage(
          content: 'ادفع أو سأنشر',
          mediaPath: null,
          mediaType: null,
        ),
      ).called(1);
    });

    test('يعيد الفشل عند فشل المستودع', () async {
      const params = AnalyzeMessageParams(content: 'test');
      const failure = MLModelFailure(message: 'Model not loaded');

      when(
        () => mockRepository.analyzeMessage(
          content: any(named: 'content'),
          mediaPath: any(named: 'mediaPath'),
          mediaType: any(named: 'mediaType'),
        ),
      ).thenAnswer((_) async => (null, failure));

      final result = await useCase(params);

      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, failure),
        (_) => fail('Should fail'),
      );
    });
  });
}
