import 'dart:convert';

import 'package:napex_victim_app/domain/entities/evidence.dart';
import 'package:napex_victim_app/domain/entities/message.dart';

/// تحويل صفوف قاعدة البيانات ↔ كيانات الأدلة
abstract final class EvidenceMapper {
  static Evidence fromRow(Map<String, Object?> row) {
    final uploadedAtMs = row['uploaded_at'] as int?;
    return Evidence(
      id: row['id'] as String? ?? '',
      reportId: row['report_id'] as String? ?? '',
      filePath: row['file_path'] as String? ?? '',
      fileHash: row['file_hash'] as String? ?? '',
      fileSize: row['file_size'] as int? ?? 0,
      mediaType: MediaType.fromValue(row['media_type'] as String? ?? 'text'),
      mimeType: row['mime_type'] as String? ?? 'application/octet-stream',
      collectedAt: DateTime.fromMillisecondsSinceEpoch(
        (row['collected_at'] as int?) ?? 0,
      ),
      status: EvidenceStatus.fromValue(row['status'] as String? ?? 'collected'),
      encryptedPath: row['encrypted_path'] as String?,
      uploadedAt: uploadedAtMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(uploadedAtMs),
      remoteUrl: row['remote_url'] as String?,
      chainOfCustody: _parseCustody(row['chain_of_custody'] as String?),
    );
  }

  static Map<String, Object?> toRow(Evidence e) {
    return {
      'id': e.id,
      'report_id': e.reportId,
      'file_path': e.filePath,
      'encrypted_path': e.encryptedPath,
      'file_hash': e.fileHash,
      'file_size': e.fileSize,
      'media_type': e.mediaType.value,
      'mime_type': e.mimeType,
      'status': e.status.value,
      'collected_at': e.collectedAt.millisecondsSinceEpoch,
      'uploaded_at': e.uploadedAt?.millisecondsSinceEpoch,
      'remote_url': e.remoteUrl,
      'chain_of_custody': jsonEncode(
        e.chainOfCustody.map((c) => c.toJson()).toList(),
      ),
    };
  }

  static List<CustodyEntry> _parseCustody(String? json) {
    if (json == null || json.isEmpty) return const [];
    try {
      final list = jsonDecode(json) as List<dynamic>;
      return list
          .map((e) => CustodyEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
