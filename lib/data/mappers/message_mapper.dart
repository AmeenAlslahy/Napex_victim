import 'dart:convert';

import 'package:napex_victim_app/domain/entities/app_source.dart';
import 'package:napex_victim_app/domain/entities/analysis_result.dart';
import 'package:napex_victim_app/domain/entities/message.dart';
import 'package:napex_victim_app/domain/entities/sender.dart';

/// صف جدول الرسائل كما هو من قاعدة البيانات + المحتوى المفكوك
class MessageRowData {
  const MessageRowData({required this.row, required this.content});

  final Map<String, Object?> row;
  final String content;
}

/// تحويل صفوف قاعدة البيانات ↔ كيانات الرسائل
abstract final class MessageMapper {
  /// صف → كيان. [decryptedContent] هو المحتوى بعد فك التشفير.
  static CollectedMessage fromRow(MessageRowData data) {
    final row = data.row;
    final package = row['source_app'] as String? ?? 'sms';

    return CollectedMessage(
      id: row['id'] as String? ?? '',
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
        chatName: row['chat_name'] as String?,
      ),
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (row['timestamp'] as int?) ?? 0,
      ),
      mediaType: MediaType.fromValue(row['media_type'] as String? ?? 'text'),
      mediaPath: row['media_path'] as String?,
      mediaHash: row['media_hash'] as String?,
      mediaSize: row['media_size'] as int?,
      mimeType: row['mime_type'] as String?,
      analysis: _parseAnalysis(row['analysis_json'] as String?),
      processed: (row['processed'] as int? ?? 0) == 1,
    );
  }

  /// كيان → صف جاهز للإدراج. [encryptedContentJson] هو JSON التشفير.
  static Map<String, Object?> toRow(
    CollectedMessage message,
    String encryptedContentJson,
  ) {
    return {
      'id': message.id,
      'sender_raw': message.sender.raw,
      'sender_display': message.sender.displayName,
      'sender_phone': message.sender.phoneNumber,
      'sender_hash': message.sender.senderHash,
      'content_encrypted': encryptedContentJson,
      'content_hash': '', // يُعبأ في المستودع
      'source_app': message.source.app.nativePackage,
      'source_package': message.source.packageName,
      'chat_name': message.source.chatName,
      'media_type': message.mediaType.value,
      'media_path': message.mediaPath,
      'media_hash': message.mediaHash,
      'media_size': message.mediaSize,
      'mime_type': message.mimeType,
      'analysis_json': message.analysis == null
          ? null
          : jsonEncode(message.analysis!.toJson()),
      'timestamp': message.timestamp.millisecondsSinceEpoch,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'processed': message.processed ? 1 : 0,
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
