import 'package:equatable/equatable.dart';

/// أدوار المستخدم
enum UserRole {
  victim('victim', 'ضحية'),
  investigator('investigator', 'محقق'),
  supervisor('supervisor', 'مشرف'),
  admin('admin', 'مدير');

  const UserRole(this.value, this.labelAr);

  final String value;
  final String labelAr;

  static UserRole fromValue(String value) {
    return UserRole.values.firstWhere(
      (r) => r.value == value,
      orElse: () => UserRole.victim,
    );
  }
}

/// نموذج المستخدم (الضحية)
class User extends Equatable {
  const User({
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
  final UserRole role;
  final String? fullName;
  final String? email;
  final String? governorate;
  final bool isActive;
  final bool isVerified;
  final DateTime? createdAt;

  User copyWith({
    String? id,
    String? phoneNumber,
    UserRole? role,
    String? fullName,
    String? email,
    String? governorate,
    bool? isActive,
    bool? isVerified,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      governorate: governorate ?? this.governorate,
      isActive: isActive ?? this.isActive,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone_number': phoneNumber,
        'role': role.value,
        if (fullName != null) 'full_name': fullName,
        if (email != null) 'email': email,
        if (governorate != null) 'governorate': governorate,
        'is_active': isActive,
        'is_verified': isVerified,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      };

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String? ?? '',
        phoneNumber: json['phone_number'] as String? ?? '',
        role: UserRole.fromValue(json['role'] as String? ?? 'victim'),
        fullName: json['full_name'] as String?,
        email: json['email'] as String?,
        governorate: json['governorate'] as String?,
        isActive: json['is_active'] as bool? ?? true,
        isVerified: json['is_verified'] as bool? ?? false,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
      );

  @override
  List<Object?> get props => [id, phoneNumber, role, isVerified];
}
