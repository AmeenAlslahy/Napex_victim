import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:napex_victim_app/core/error/failures.dart';
import 'package:napex_victim_app/domain/entities/analysis_result.dart';
import 'package:napex_victim_app/domain/entities/app_source.dart';
import 'package:napex_victim_app/domain/entities/message.dart';
import 'package:napex_victim_app/domain/entities/message_category.dart';
import 'package:napex_victim_app/domain/entities/report.dart';
import 'package:napex_victim_app/domain/entities/risk_level.dart';
import 'package:napex_victim_app/domain/entities/sender.dart';
import 'package:napex_victim_app/domain/usecases/collector/process_message_usecase.dart';
import 'package:napex_victim_app/domain/usecases/analysis/analyze_message_usecase.dart';
import 'package:napex_victim_app/domain/usecases/report/create_report_usecase.dart';
import 'package:napex_victim_app/domain/usecases/report/submit_report_usecase.dart';

class MockAnalyzeMessageUseCase extends Mock implements AnalyzeMessageUseCase {}

class MockCreateReportUseCase extends Mock implements CreateReportUseCase {}

class MockSubmitReportUseCase extends Mock implements SubmitReportUseCase {}

void main() {
  late MockAnalyzeMessageUseCase mockAnalyze;
  late MockCreateReportUseCase mockCreate;
  late MockSubmitReportUseCase mockSubmit;
  late ProcessMessageUseCase useCase;

  final message = CollectedMessage(
    id: 'm-1',
    sender: const Sender(raw: '+967700000000', displayName: 'مبتز'),
    content: 'ادفع',
    source: MessageSource.sms,
    timestamp: DateTime(2026, 10, 5),
  );

  Report reportFor(AnalysisResult analysis) => Report(
        id: 'r-1',
        localId: 'l-1',
        sender: message.sender,
        content: message.content,
        source: message.source,
        analysis: analysis,
        messageTimestamp: message.timestamp,
        createdAt: DateTime(2026, 10, 5),
      );

  setUp(() {
    mockAnalyze = MockAnalyzeMessageUseCase();
    mockCreate = MockCreateReportUseCase();
    mockSubmit = MockSubmitReportUseCase();
    useCase = ProcessMessageUseCase(mockAnalyze, mockCreate, mockSubmit);
  });

  setUpAll(() {
    registerFallbackValue(AnalyzeMessageParams(content: ''));
    registerFallbackValue(
      CreateReportParams(
        message: message,
        analysis: AnalysisResult.normal,
      ),
    );
    registerFallbackValue(
      SubmitReportParams(
        report: Report(
          id: 'fallback',
          localId: 'fallback',
          sender: message.sender,
          content: '',
          source: message.source,
          analysis: AnalysisResult.normal,
          messageTimestamp: message.timestamp,
          createdAt: message.timestamp,
        ),
      ),
    );
  });

  AnalysisResult extortionAt(double confidence) => AnalysisResult(
        category: MessageCategory.extortion,
        confidence: confidence,
        riskLevel: RiskLevel.fromScore(confidence),
        isExtortion: true,
      );

  group('ProcessMessageUseCase — عتبة حساسية الكشف', () {
    test(
      'الثقة 0.80 تحت العتبة الافتراضية 0.85 → لا بلاغ',
      () async {
        when(() => mockAnalyze.call(any()))
            .thenAnswer((_) async => Right(extortionAt(0.80)));

        final result = await useCase(ProcessMessageParams(message: message));

        expect(result.isRight(), isTrue);
        result.fold(
          (_) => fail('should not fail'),
          (r) => expect(r.reportCreated, isFalse),
        );
        verifyNever(() => mockCreate.call(any()));
      },
    );

    test(
      'الثقة 0.80 مع حساسية عالية (عتبة 0.70) → يُنشأ بلاغ',
      () async {
        final analysis = extortionAt(0.80);
        when(() => mockAnalyze.call(any()))
            .thenAnswer((_) async => Right(analysis));
        when(() => mockCreate.call(any()))
            .thenAnswer((_) async => Right(reportFor(analysis)));
        when(() => mockSubmit.call(any()))
            .thenAnswer((_) async => const Right('EXT-2026-TEST01'));

        final result = await useCase(
          ProcessMessageParams(message: message, detectionThreshold: 0.70),
        );

        expect(result.isRight(), isTrue);
        result.fold(
          (_) => fail('should not fail'),
          (r) {
            expect(r.reportCreated, isTrue);
            expect(r.reportNumber, 'EXT-2026-TEST01');
          },
        );
        verify(() => mockCreate.call(any())).called(1);
      },
    );

    test('رسالة عادية بثقة عالية → لا بلاغ مهما كانت العتبة', () async {
      when(() => mockAnalyze.call(any())).thenAnswer(
        (_) async => const Right(AnalysisResult.normal),
      );

      final result = await useCase(
        ProcessMessageParams(message: message, detectionThreshold: 0.30),
      );

      result.fold(
        (_) => fail('should not fail'),
        (r) => expect(r.reportCreated, isFalse),
      );
      verifyNever(() => mockCreate.call(any()));
    });

    test('فشل التحليل → يسار بنفس الفشل', () async {
      const failure = MLModelFailure(message: 'model offline');
      when(() => mockAnalyze.call(any())).thenAnswer((_) async => Left(failure));

      final result = await useCase(ProcessMessageParams(message: message));

      expect(result.isLeft(), isTrue);
      result.fold((f) => expect(f, failure), (_) => fail('should fail'));
    });
  });
}