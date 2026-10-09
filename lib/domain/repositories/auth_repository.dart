import 'package:napex_victim_app/core/error/failures.dart';
import 'package:napex_victim_app/domain/entities/auth_token.dart';
import 'package:napex_victim_app/domain/entities/user.dart';

abstract interface class AuthRepository {
  Future<(User?, Failure?)> register({
    required String phoneNumber,
    String? fullName,
    String? email,
    String? governorate,
  });

  Future<(bool, Failure?)> verifyOtp({
    required String phoneNumber,
    required String otp,
  });

  Future<(AuthToken?, Failure?)> login({
    required String phoneNumber,
    required String password,
  });

  Future<(AuthToken?, Failure?)> refreshToken(String refreshToken);

  Future<(bool, Failure?)> logout();

  Future<(User?, Failure?)> getCurrentUser();

  Future<(bool, Failure?)> deleteAccount();

  Future<bool> isAuthenticated();

  /// تسجيل محلي لوضع العرض التجريبي (عند غياب الخادم)
  Future<(User?, Failure?)> registerOfflineDemo({
    required String phoneNumber,
    String? fullName,
    String? governorate,
  });
}
