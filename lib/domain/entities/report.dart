import 'package:equatable/equatable.dart';

import 'package:napex_victim_app/domain/entities/analysis_result.dart';
import 'package:napex_victim_app/domain/entities/app_source.dart';
import 'package:napex_victim_app/domain/entities/evidence.dart';
import 'package:napex_victim_app/domain/entities/risk_level.dart';
import 'package:napex_victim_app/domain/entities/sender.dart';

/// حالة البلاغ
enum ReportStatus {
  draft('draft', 'مسودة'),
  pending('pending', 'قيد الإرسال'),
  submitted('submitted', 'تم الإرسال'),
  received('received', 'تم الاستلام'),
  underReview('under_review', 'قيد المراجعة'),
  investigating('investigating', 'قيد التحقيق'),
  resolved('resolved', 'تم الحل'),
  closed('closed', 'مغلق'),
  rejected('rejected', 'مرفوض'),
  failed('failed', 'فشل الإرسال');

  const ReportStatus(this.value, this.labelAr);

  final String value;
  final String labelAr;

  static ReportStatus fromValue(String value) {
    return ReportStatus.values.firstWhere(
      (s) => s.value == value,
      orElse: () => ReportStatus.draft,
    );
  }

  bool get isSynced => this != ReportStatus.draft && this != ReportStatus.pending;
  bool get isTerminal => this == ReportStatus.closed || this == ReportStatus.rejected;
  bool get needsSubmission =>
      this == ReportStatus.draft || this == ReportStatus.failed;
}

/// نموذج البلاغ
class Report extends Equatable {
  const Report({
    required this.id,
    required this.localId,
    required this.sender,
    required this.content,
    required this.source,
    required this.analysis,
    required this.messageTimestamp,
    required this.createdAt,
    this.reportNumber,
    this.evidences = const [],
    this.status = ReportStatus.draft,
    this.syncedAt,
    this.retryCount = 0,
    this.lastError,
  });

  final String id;
  final String localId;
  final String? reportNumber;
  final Sender sender;
  final String content;
  final MessageSource source;
  final AnalysisResult analysis;
  final DateTime messageTimestamp;
  final DateTime createdAt;
  final List<Evidence> evidences;
  final ReportStatus status;
  final DateTime? syncedAt;
  final int retryCount;
  final String? lastError;

  RiskLevel get riskLevel => analysis.riskLevel;
  bool get isExtortion => analysis.isExtortion;
  bool get hasEvidence => evidences.isNotEmpty;
  bool get canRetry => status == ReportStatus.failed && retryCount < 3;

  Report copyWith({
    String? id,
    String? localId,
    String? reportNumber,
    Sender? sender,
    String? content,
    MessageSource? source,
    AnalysisResult? analysis,
    DateTime? messageTimestamp,
    DateTime? createdAt,
    List<Evidence>? evidences,
    ReportStatus? status,
    DateTime? syncedAt,
    int? retryCount,
    String? lastError,
  }) {
    return Report(
      id: id ?? this.id,
      localId: localId ?? this.localId,
      reportNumber: reportNumber ?? this.reportNumber,
      sender: sender ?? this.sender,
      content: content ?? this.content,
      source: source ?? this.source,
      analysis: analysis ?? this.analysis,
      messageTimestamp: messageTimestamp ?? this.messageTimestamp,
      createdAt: createdAt ?? this.createdAt,
      evidences: evidences ?? this.evidences,
      status: status ?? this.status,
      syncedAt: syncedAt ?? this.syncedAt,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
    );
  }

  @override
  List<Object?> get props => [
        id,
        localId,
        reportNumber,
        sender,
        status,
        createdAt,
      ];
}
