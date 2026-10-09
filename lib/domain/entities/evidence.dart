import 'package:equatable/equatable.dart';

import 'package:napex_victim_app/domain/entities/message.dart';

/// حالة الدليل
enum EvidenceStatus {
  collected('collected', 'تم الجمع'),
  hashed('hashed', 'تم التجزئة'),
  encrypted('encrypted', 'تم التشفير'),
  uploaded('uploaded', 'تم الرفع'),
  verified('verified', 'تم التحقق');

  const EvidenceStatus(this.value, this.labelAr);

  final String value;
  final String labelAr;

  static EvidenceStatus fromValue(String value) {
    return EvidenceStatus.values.firstWhere(
      (s) => s.value == value,
      orElse: () => EvidenceStatus.collected,
    );
  }
}

/// عنصر في سلسلة الحفظ (Chain of Custody)
class CustodyEntry extends Equatable {
  const CustodyEntry({
    required this.timestamp,
    required this.action,
    required this.performedBy,
    this.notes,
    this.signature,
  });

  final DateTime timestamp;
  final String action;
  final String performedBy;
  final String? notes;
  final String? signature;

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'action': action,
        'performed_by': performedBy,
        if (notes != null) 'notes': notes,
        if (signature != null) 'signature': signature,
      };

  factory CustodyEntry.fromJson(Map<String, dynamic> json) => CustodyEntry(
        timestamp: DateTime.parse(json['timestamp'] as String),
        action: json['action'] as String,
        performedBy: json['performed_by'] as String,
        notes: json['notes'] as String?,
        signature: json['signature'] as String?,
      );

  @override
  List<Object?> get props => [timestamp, action, performedBy];
}

/// نموذج الدليل الرقمي
class Evidence extends Equatable {
  const Evidence({
    required this.id,
    required this.reportId,
    required this.filePath,
    required this.fileHash,
    required this.fileSize,
    required this.mediaType,
    required this.mimeType,
    required this.collectedAt,
    this.status = EvidenceStatus.collected,
    this.encryptedPath,
    this.uploadedAt,
    this.remoteUrl,
    this.chainOfCustody = const [],
  });

  final String id;
  final String reportId;
  final String filePath;
  final String fileHash;
  final int fileSize;
  final MediaType mediaType;
  final String mimeType;
  final DateTime collectedAt;
  final EvidenceStatus status;
  final String? encryptedPath;
  final DateTime? uploadedAt;
  final String? remoteUrl;
  final List<CustodyEntry> chainOfCustody;

  Evidence copyWith({
    String? id,
    String? reportId,
    String? filePath,
    String? fileHash,
    int? fileSize,
    MediaType? mediaType,
    String? mimeType,
    DateTime? collectedAt,
    EvidenceStatus? status,
    String? encryptedPath,
    DateTime? uploadedAt,
    String? remoteUrl,
    List<CustodyEntry>? chainOfCustody,
  }) {
    return Evidence(
      id: id ?? this.id,
      reportId: reportId ?? this.reportId,
      filePath: filePath ?? this.filePath,
      fileHash: fileHash ?? this.fileHash,
      fileSize: fileSize ?? this.fileSize,
      mediaType: mediaType ?? this.mediaType,
      mimeType: mimeType ?? this.mimeType,
      collectedAt: collectedAt ?? this.collectedAt,
      status: status ?? this.status,
      encryptedPath: encryptedPath ?? this.encryptedPath,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      chainOfCustody: chainOfCustody ?? this.chainOfCustody,
    );
  }

  @override
  List<Object?> get props => [id, reportId, fileHash, status, uploadedAt];
}
