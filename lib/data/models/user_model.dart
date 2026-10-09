import 'package:napex_victim_app/domain/entities/user.dart';

/// DTO المستخدم
class UserModel {
  const UserModel({
    required this.id,
    required this.phoneNumber,
    required this.role,
    this.fullName,
    this.email,
    this.governorate,
    this.isActive = true,
    this.isVerified = false,
    this.createdAt,
  });

  final String id;
  final String phoneNumber;
  final String role;
  final String? fullName;
  final String? email;
  final String? governorate;
  final bool isActive;
  final bool isVerified;
  final DateTime? createdAt;

  factory UserModel.fromEntity(User e) => UserModel(
        id: e.id,
        phoneNumber: e.phoneNumber,
        role: e.role.value,
        fullName: e.fullName,
        email: e.email,
        governorate: e.governorate,
        isActive: e.isActive,
        isVerified: e.isVerified,
        createdAt: e.createdAt,
      );

  User toEntity() => User(
        id: id,
        phoneNumber: phoneNumber,
        role: UserRole.fromValue(role),
        fullName: fullName,
        email: email,
        governorate: governorate,
        isActive: isActive,
        isVerified: isVerified,
        createdAt: createdAt,
      );

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String? ?? '',
        phoneNumber:
            json['phone_number'] as String? ?? json['phoneNumber'] as String? ?? '',
        role: json['role'] as String? ?? 'victim',
        fullName: json['full_name'] as String? ?? json['fullName'] as String?,
        email: json['email'] as String?,
        governorate: json['governorate'] as String?,
        isActive: json['is_active'] as bool? ?? true,
        isVerified: json['is_verified'] as bool? ?? false,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone_number': phoneNumber,
        'role': role,
        if (fullName != null) 'full_name': fullName,
        if (email != null) 'email': email,
        if (governorate != null) 'governorate': governorate,
        'is_active': isActive,
        'is_verified': isVerified,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      };
}
