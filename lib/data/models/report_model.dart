import 'package:napex_victim_app/data/models/analysis_model.dart';
import 'package:napex_victim_app/data/models/sender_model.dart';
import 'package:napex_victim_app/domain/entities/app_source.dart';
import 'package:napex_victim_app/domain/entities/report.dart';

/// DTO البلاغ — يُستخدم عند الإرسال للخادم
class ReportModel {
  const ReportModel({
    required this.id,
    required this.localId,
    this.reportNumber,
    required this.sender,
    required this.content,
    required this.sourceApp,
    this.sourcePackage,
    required this.analysis,
    required this.messageTimestamp,
    required this.createdAt,
    required this.status,
    this.syncedAt,
  });

  final String id;
  final String localId;
  final String? reportNumber;
  final SenderModel sender;
  final String content;
  final String sourceApp;
  final String? sourcePackage;
  final AnalysisModel analysis;
  final DateTime messageTimestamp;
  final DateTime createdAt;
  final String status;
  final DateTime? syncedAt;

  factory ReportModel.fromEntity(Report e) => ReportModel(
        id: e.id,
        localId: e.localId,
        reportNumber: e.reportNumber,
        sender: SenderModel.fromEntity(e.sender),
        content: e.content,
        sourceApp: e.source.app.nativePackage,
        sourcePackage: e.source.packageName,
        analysis: AnalysisModel.fromEntity(e.analysis),
        messageTimestamp: e.messageTimestamp,
        createdAt: e.createdAt,
        status: e.status.value,
        syncedAt: e.syncedAt,
      );

  Report toEntity({String? localId}) => Report(
        id: id,
        localId: localId ?? this.localId,
        reportNumber: reportNumber,
        sender: sender.toEntity(),
        content: content,
        source: MessageSource(
          app: AppSource.fromPackageName(sourceApp),
          packageName: sourcePackage ?? sourceApp,
        ),
        analysis: analysis.toEntity(),
        messageTimestamp: messageTimestamp,
        createdAt: createdAt,
        status: ReportStatus.fromValue(status),
        syncedAt: syncedAt,
      );

  factory ReportModel.fromJson(Map<String, dynamic> json) => ReportModel(
        id: json['id'] as String? ?? json['local_id'] as String? ?? '',
        localId: json['local_id'] as String? ?? json['id'] as String? ?? '',
        reportNumber: json['report_number'] as String?,
        sender:
            SenderModel.fromJson(json['sender'] as Map<String, dynamic>? ?? {}),
        content: json['content'] as String? ?? '',
        sourceApp: json['source_app'] as String? ?? 'sms',
        sourcePackage: json['source_package'] as String?,
        analysis: AnalysisModel.fromJson(
            json['analysis'] as Map<String, dynamic>? ?? {}),
        messageTimestamp:
            DateTime.tryParse(json['message_timestamp'] as String? ?? '') ??
                DateTime.now(),
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.now(),
        status: json['status'] as String? ?? 'draft',
        syncedAt: json['synced_at'] != null
            ? DateTime.tryParse(json['synced_at'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'local_id': localId,
        if (reportNumber != null) 'report_number': reportNumber,
        'sender': sender.toJson(),
        'content': content,
        'source_app': sourceApp,
        if (sourcePackage != null) 'source_package': sourcePackage,
        'analysis': analysis.toJson(),
        'message_timestamp': messageTimestamp.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'status': status,
        if (syncedAt != null) 'synced_at': syncedAt!.toIso8601String(),
      };
}
