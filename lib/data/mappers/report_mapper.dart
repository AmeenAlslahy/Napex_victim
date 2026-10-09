import 'dart:convert';

import 'package:napex_victim_app/domain/entities/analysis_result.dart';
import 'package:napex_victim_app/domain/entities/app_source.dart';
import 'package:napex_victim_app/domain/entities/report.dart';
import 'package:napex_victim_app/domain/entities/sender.dart';

/// صف جدول البلاغات + المحتوى المفكوك
class ReportRowData {
  const ReportRowData({required this.row, required this.content});

  final Map<String, Object?> row;
  final String content;
}

/// تحويل صفوف قاعدة البيانات ↔ كيانات البلاغات
abstract final class ReportMapper {
  static Report fromRow(ReportRowData data) {
    final row = data.row;
    final package = row['source_app'] as String? ?? 'sms';
    final syncedAtMs = row['synced_at'] as int?;

    return Report(
      id: row['id'] as String? ?? '',
      localId: row['local_id'] as String? ?? '',
      reportNumber: row['report_number'] as String?,
      sender: Sender(
        raw: row['sender_raw'] as String? ?? '',
        displayName: row['sender_display'] as String? ?? '',
        phoneNumber: row['sender_phone'] as String?,
        senderHash: row['sender_hash'] as String?,
      ),
      content: data.content,
      source: MessageSource(
        app: AppSource.fromPackageName(package),
        packageName: package,
      ),
      analysis: _parseAnalysis(row['analysis_json'] as String?) ??
          AnalysisResult.normal,
      messageTimestamp: DateTime.fromMillisecondsSinceEpoch(
        (row['message_timestamp'] as int?) ?? 0,
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (row['created_at'] as int?) ?? 0,
      ),
      status: ReportStatus.fromValue(row['status'] as String? ?? 'draft'),
      syncedAt: syncedAtMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(syncedAtMs),
      retryCount: row['retry_count'] as int? ?? 0,
      lastError: row['last_error'] as String?,
    );
  }

  static Map<String, Object?> toRow(
    Report report,
    String encryptedContentJson,
    String contentHash,
  ) {
    return {
      'id': report.id,
      'local_id': report.localId,
      'report_number': report.reportNumber,
      'sender_raw': report.sender.raw,
      'sender_display': report.sender.displayName,
      'sender_phone': report.sender.phoneNumber,
      'sender_hash': report.sender.senderHash,
      'content_encrypted': encryptedContentJson,
      'content_hash': contentHash,
      'source_app': report.source.app.nativePackage,
      'source_package': report.source.packageName,
      'analysis_json': jsonEncode(report.analysis.toJson()),
      'message_timestamp': report.messageTimestamp.millisecondsSinceEpoch,
      'created_at': report.createdAt.millisecondsSinceEpoch,
      'synced_at': report.syncedAt?.millisecondsSinceEpoch,
      'status': report.status.value,
      'retry_count': report.retryCount,
      'last_error': report.lastError,
    };
  }

  static AnalysisResult? _parseAnalysis(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      return AnalysisResult.fromJson(
        jsonDecode(json) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }
}
