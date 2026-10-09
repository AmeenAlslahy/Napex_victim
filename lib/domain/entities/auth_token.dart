import 'package:equatable/equatable.dart';

/// نموذج رمز المصادقة
class AuthToken extends Equatable {
  const AuthToken({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    this.tokenType = 'Bearer',
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final String tokenType;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  bool get isAboutToExpire =>
      DateTime.now().add(const Duration(minutes: 5)).isAfter(expiresAt);

  @override
  List<Object?> get props => [accessToken, expiresAt];
}
