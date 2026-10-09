import 'package:napex_victim_app/domain/entities/sender.dart';

/// DTO المُرسل
class SenderModel {
  const SenderModel({
    required this.raw,
    required this.displayName,
    this.phoneNumber,
    this.senderHash,
    this.isContact = false,
    this.isBlocked = false,
  });

  final String raw;
  final String displayName;
  final String? phoneNumber;
  final String? senderHash;
  final bool isContact;
  final bool isBlocked;

  factory SenderModel.fromEntity(Sender e) => SenderModel(
        raw: e.raw,
        displayName: e.displayName,
        phoneNumber: e.phoneNumber,
        senderHash: e.senderHash,
        isContact: e.isContact,
        isBlocked: e.isBlocked,
      );

  Sender toEntity() => Sender(
        raw: raw,
        displayName: displayName,
        phoneNumber: phoneNumber,
        senderHash: senderHash,
        isContact: isContact,
        isBlocked: isBlocked,
      );

  factory SenderModel.fromJson(Map<String, dynamic> json) => SenderModel(
        raw: json['raw'] as String? ?? '',
        displayName: json['display_name'] as String? ?? '',
        phoneNumber: json['phone_number'] as String?,
        senderHash: json['sender_hash'] as String?,
        isContact: json['is_contact'] as bool? ?? false,
        isBlocked: json['is_blocked'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'raw': raw,
        'display_name': displayName,
        if (phoneNumber != null) 'phone_number': phoneNumber,
        if (senderHash != null) 'sender_hash': senderHash,
        'is_contact': isContact,
        'is_blocked': isBlocked,
      };
}
