import 'package:napex_victim_app/data/models/user_model.dart';
import 'package:napex_victim_app/domain/entities/auth_token.dart';

/// DTO استجابة المصادقة (توكن + مستخدم)
class AuthResponseModel {
  const AuthResponseModel({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    this.tokenType = 'Bearer',
    this.user,
  });

  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final String tokenType;
  final UserModel? user;

  AuthToken toToken() => AuthToken(
        accessToken: accessToken,
        refreshToken: refreshToken,
        tokenType: tokenType,
        expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
      );

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) =>
      AuthResponseModel(
        accessToken: json['access_token'] as String? ??
            json['accessToken'] as String? ??
            '',
        refreshToken: json['refresh_token'] as String? ??
            json['refreshToken'] as String? ??
            '',
        expiresIn: (json['expires_in'] as num? ?? json['expiresIn'] as num? ?? 3600)
            .toInt(),
        tokenType: json['token_type'] as String? ?? 'Bearer',
        user: json['user'] != null
            ? UserModel.fromJson(json['user'] as Map<String, dynamic>)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'expires_in': expiresIn,
        'token_type': tokenType,
        if (user != null) 'user': user!.toJson(),
      };
}
