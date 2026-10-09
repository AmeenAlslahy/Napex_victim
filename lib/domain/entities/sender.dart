import 'package:equatable/equatable.dart';

/// نموذج المُرسل
class Sender extends Equatable {
  const Sender({
    required this.raw,
    required this.displayName,
    this.phoneNumber,
    this.senderHash,
    this.isContact = false,
    this.isBlocked = false,
  });

  /// المُرسل كما ورد (رقم أو اسم)
  final String raw;

  /// الاسم المعروض
  final String displayName;

  /// رقم الهاتف (إن وُجد)
  final String? phoneNumber;

  /// Hash للرقم (للخصوصية عند المزامنة)
  final String? senderHash;

  /// هل هو جهة اتصال؟
  final bool isContact;

  /// هل هو محجوب؟
  final bool isBlocked;

  Sender copyWith({
    String? raw,
    String? displayName,
    String? phoneNumber,
    String? senderHash,
    bool? isContact,
    bool? isBlocked,
  }) {
    return Sender(
      raw: raw ?? this.raw,
      displayName: displayName ?? this.displayName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      senderHash: senderHash ?? this.senderHash,
      isContact: isContact ?? this.isContact,
      isBlocked: isBlocked ?? this.isBlocked,
    );
  }

  @override
  List<Object?> get props =>
      [raw, displayName, phoneNumber, senderHash, isContact, isBlocked];
}
