import 'package:equatable/equatable.dart';

import 'package:napex_victim_app/domain/entities/analysis_result.dart';
import 'package:napex_victim_app/domain/entities/app_source.dart';
import 'package:napex_victim_app/domain/entities/sender.dart';

/// أنواع الوسائط
enum MediaType {
  text('text'),
  image('image'),
  audio('audio'),
  video('video'),
  document('document'),
  sticker('sticker'),
  location('location'),
  contact('contact');

  const MediaType(this.value);

  final String value;

  static MediaType fromValue(String value) {
    return MediaType.values.firstWhere(
      (t) => t.value == value,
      orElse: () => MediaType.text,
    );
  }
}

/// نموذج الرسالة المُجمَّعة من خدمات النظام
class CollectedMessage extends Equatable {
  const CollectedMessage({
    required this.id,
    required this.sender,
    required this.content,
    required this.source,
    required this.timestamp,
    this.mediaType = MediaType.text,
    this.mediaPath,
    this.mediaHash,
    this.mediaSize,
    this.mimeType,
    this.analysis,
    this.processed = false,
  });

  final String id;
  final Sender sender;
  final String content;
  final MessageSource source;
  final DateTime timestamp;
  final MediaType mediaType;
  final String? mediaPath;
  final String? mediaHash;
  final int? mediaSize;
  final String? mimeType;
  final AnalysisResult? analysis;
  final bool processed;

  bool get hasMedia => mediaPath != null;
  bool get isTextOnly => mediaType == MediaType.text;

  CollectedMessage copyWith({
    String? id,
    Sender? sender,
    String? content,
    MessageSource? source,
    DateTime? timestamp,
    MediaType? mediaType,
    String? mediaPath,
    String? mediaHash,
    int? mediaSize,
    String? mimeType,
    AnalysisResult? analysis,
    bool? processed,
  }) {
    return CollectedMessage(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      content: content ?? this.content,
      source: source ?? this.source,
      timestamp: timestamp ?? this.timestamp,
      mediaType: mediaType ?? this.mediaType,
      mediaPath: mediaPath ?? this.mediaPath,
      mediaHash: mediaHash ?? this.mediaHash,
      mediaSize: mediaSize ?? this.mediaSize,
      mimeType: mimeType ?? this.mimeType,
      analysis: analysis ?? this.analysis,
      processed: processed ?? this.processed,
    );
  }

  /// بناء من خريطة أصلية قادمة عبر EventChannel
  /// الحقول: id, sender, content, source, timestamp(ms), mediaPath, mediaType
  factory CollectedMessage.fromNativeMap(Map<dynamic, dynamic> map) {
    final senderRaw = (map['sender'] as String?) ?? 'غير معروف';
    final sourcePackage = (map['source'] as String?) ?? 'sms';
    final timestampMs = (map['timestamp'] as num?)?.toInt() ??
        DateTime.now().millisecondsSinceEpoch;

    return CollectedMessage(
      id: (map['id'] as String?) ?? '',
      sender: Sender(raw: senderRaw, displayName: senderRaw),
      content: (map['content'] as String?) ?? '',
      source: MessageSource(
        app: AppSource.fromPackageName(sourcePackage),
        packageName: sourcePackage,
        chatName: map['chatName'] as String?,
      ),
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestampMs),
      mediaType: MediaType.fromValue(map['mediaType'] as String? ?? 'text'),
      mediaPath: map['mediaPath'] as String?,
      mimeType: map['mimeType'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        sender,
        content,
        source,
        timestamp,
        mediaType,
        mediaPath,
        processed,
      ];
}
