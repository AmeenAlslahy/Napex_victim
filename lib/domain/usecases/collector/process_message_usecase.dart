import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import 'package:napex_victim_app/core/constants/app_constants.dart';
import 'package:napex_victim_app/core/error/failures.dart';
import 'package:napex_victim_app/domain/entities/analysis_result.dart';
import 'package:napex_victim_app/domain/entities/message.dart';
import 'package:napex_victim_app/domain/usecases/analysis/analyze_message_usecase.dart';
import 'package:napex_victim_app/domain/usecases/base_usecase.dart';
import 'package:napex_victim_app/domain/usecases/report/create_report_usecase.dart';

/// نتيجة معالجة الرسالة
class ProcessMessageResult extends Equatable {
  const ProcessMessageResult({
    required this.message,
    required this.analysis,
    required this.reportCreated,
    this.reportId,
    this.reportNumber,
  });

  final CollectedMessage message;
  final AnalysisResult analysis;
  final bool reportCreated;
  final String? reportId;
  final String? reportNumber;

  bool get needsUserAlert => analysis.requiresNotification;

  @override
  List<Object?> get props =>
      [message, analysis, reportCreated, reportId, reportNumber];
}

class ProcessMessageParams extends Equatable {
  const ProcessMessageParams({
    required this.message,
    this.autoReport = true,
    this.forcedAnalysis,
    this.detectionThreshold = AppConstants.extortionThreshold,
  });

  final CollectedMessage message;

  /// هل الإبلاغ التلقائي مفعّل؟ (عند الإيقاف: تحليل وتنبيه فقط دون إنشاء بلاغ)
  final bool autoReport;

  /// تحليل مفروض — يُستخدم لتطابق قائمة الحظر الوطنية (يرجع فوق أي محرك)
  final AnalysisResult? forcedAnalysis;

  /// عتبة الحساسية — من إعدادات المستخدم (حساسية أعلى = عتبة أقل)
  final double detectionThreshold;

  @override
  List<Object?> get props =>
      [message, autoReport, forcedAnalysis, detectionThreshold];
}

/// المعالجة الشاملة لرسالة مُجمَّعة:
/// تحليل → (إن كانت ابتزازاً عالي الثقة) إنشاء بلاغ → محاولة إرسال
class ProcessMessageUseCase
    extends UseCase<ProcessMessageResult, ProcessMessageParams> {
  ProcessMessageUseCase(
    this._analyzeMessage,
    this._createReport,
  );

  final AnalyzeMessageUseCase _analyzeMessage;
  final CreateReportUseCase _createReport;

  @override
  Future<Either<Failure, ProcessMessageResult>> call(
    ProcessMessageParams params,
  ) async {
    // 1. تحليل الرسالة — أو تحليل مفروض (تطابق قائمة الحظر)
    final Either<Failure, AnalysisResult> analysisResult =
        params.forcedAnalysis != null
            ? Right(params.forcedAnalysis!)
            : await _analyzeMessage(
                AnalyzeMessageParams(content: params.message.content),
              );

    return analysisResult.fold(
      Left<Failure, ProcessMessageResult>.new,
      (analysis) async {
        // 2. حفظ الرسالة كمعالجة — حتى غير الابتزاز تُحفظ لفترة قصيرة
        final message = params.message.copyWith(
          analysis: analysis,
          processed: true,
        );

        // 3. لا بلاغ إن كان الإبلاغ التلقائي موقوفاً أو تحت عتبة الحساسية
        final meetsThreshold =
            analysis.confidence >= params.detectionThreshold;
        if (!analysis.isExtortion || !meetsThreshold || !params.autoReport) {
          return Right(
            ProcessMessageResult(
              message: message,
              analysis: analysis,
              reportCreated: false,
            ),
          );
        }

        // 4. إنشاء البلاغ — محلياً فقط.
        // سياسة الإرسال: لا يُرسل أي بلاغ للخادم تلقائياً — الإرسال
        // بيد المستخدم حصراً (زر "إرسال" من تفاصيل البلاغ).
        final reportResult = await _createReport(
          CreateReportParams(message: message, analysis: analysis),
        );

        return reportResult.fold(
          Left<Failure, ProcessMessageResult>.new,
          (report) => Right(
            ProcessMessageResult(
              message: message,
              analysis: analysis,
              reportCreated: true,
              reportId: report.localId,
            ),
          ),
        );
      },
    );
  }
}
