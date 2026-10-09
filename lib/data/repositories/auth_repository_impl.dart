import 'package:uuid/uuid.dart';

import 'package:napex_victim_app/core/constants/app_constants.dart';
import 'package:napex_victim_app/core/constants/security_constants.dart';
import 'package:napex_victim_app/core/error/error_handler.dart';
import 'package:napex_victim_app/core/error/failures.dart';
import 'package:napex_victim_app/core/security/secure_storage.dart';
import 'package:napex_victim_app/core/storage/local_storage.dart';
import 'package:napex_victim_app/data/datasources/remote/api/auth_api.dart';
import 'package:napex_victim_app/data/models/auth_response_model.dart';
import 'package:napex_victim_app/data/models/user_model.dart';
import 'package:napex_victim_app/domain/entities/auth_token.dart';
import 'package:napex_victim_app/domain/entities/user.dart';
import 'package:napex_victim_app/domain/repositories/auth_repository.dart';

/// تنفيذ مستودع المصادقة — وضعان:
/// 1) خادم حقيقي (تسجيل + OTP + توكنات)
/// 2) وضع عرض تجريبي محلي (عند غياب الخادم) عبر registerOfflineDemo
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthApi api,
    required SecureStorage secureStorage,
    required LocalStorage localStorage,
  })  : _api = api,
        _secureStorage = secureStorage,
        _localStorage = localStorage;

  final AuthApi _api;
  final SecureStorage _secureStorage;
  final LocalStorage _localStorage;
  final Uuid _uuid = const Uuid();

  @override
  Future<(User?, Failure?)> register({
    required String phoneNumber,
    String? fullName,
    String? email,
    String? governorate,
  }) async {
    try {
      final data = await _api.register({
        'phone_number': phoneNumber,
        if (fullName != null && fullName.isNotEmpty) 'full_name': fullName,
        if (email != null && email.isNotEmpty) 'email': email,
        if (governorate != null && governorate.isNotEmpty)
          'governorate': governorate,
      });
      final user = UserModel.fromJson(
        (data['user'] as Map<String, dynamic>?) ?? data,
      );
      return (user.toEntity(), null);
    } catch (e) {
      return (null, ErrorHandler.mapExceptionToFailure(e));
    }
  }

  @override
  Future<(bool, Failure?)> verifyOtp({
    required String phoneNumber,
    required String otp,
  }) async {
    try {
      final data = await _api.verifyOtp({
        'phone_number': phoneNumber,
        'otp': otp,
      });

      final authResponse = AuthResponseModel.fromJson(data);
      if (authResponse.accessToken.isEmpty) {
        return (false, const ServerFailure(message: 'استجابة فارغة من الخادم'));
      }

      await _saveAuthData(authResponse);
      return (true, null);
    } catch (e) {
      return (false, ErrorHandler.mapExceptionToFailure(e));
    }
  }

  @override
  Future<(AuthToken?, Failure?)> login({
    required String phoneNumber,
    required String password,
  }) async {
    try {
      final data = await _api.login({
        'phone_number': phoneNumber,
        'password': password,
      });
      final authResponse = AuthResponseModel.fromJson(data);
      await _saveAuthData(authResponse);
      return (authResponse.toToken(), null);
    } catch (e) {
      return (null, ErrorHandler.mapExceptionToFailure(e));
    }
  }

  @override
  Future<(AuthToken?, Failure?)> refreshToken(String refreshToken) async {
    try {
      final data = await _api.refreshToken({'refresh_token': refreshToken});
      final authResponse = AuthResponseModel.fromJson(data);
      await _saveAuthData(authResponse);
      return (authResponse.toToken(), null);
    } catch (e) {
      return (null, ErrorHandler.mapExceptionToFailure(e));
    }
  }

  @override
  Future<(bool, Failure?)> logout() async {
    try {
      await _api.logout();
    } catch (_) {
      // حتى لو فشل الاتصال، نحذف البيانات محلياً
    }
    await _clearAuthData();
    return (true, null);
  }

  @override
  Future<(User?, Failure?)> getCurrentUser() async {
    // الوضع التجريبي
    if (_localStorage.getBool(AppConstants.keyOfflineDemoMode)) {
      return (_readCachedUser(), null);
    }

    try {
      final data = await _api.getCurrentUser();
      final user = UserModel.fromJson(
        (data['user'] as Map<String, dynamic>?) ?? data,
      );
      await _secureStorage.writeString(
        SecurityConstants.keyUserData,
        user.toJson().toString(),
      );
      return (user.toEntity(), null);
    } catch (e) {
      return (null, ErrorHandler.mapExceptionToFailure(e));
    }
  }

  @override
  Future<(bool, Failure?)> deleteAccount() async {
    try {
      await _api.deleteAccount();
    } catch (_) {}
    await _clearAuthData();
    return (true, null);
  }

  @override
  Future<bool> isAuthenticated() async {
    if (_localStorage.getBool(AppConstants.keyOfflineDemoMode)) return true;
    final token = await _secureStorage.readString(
      SecurityConstants.keyAccessToken,
    );
    return token != null && token.isNotEmpty;
  }

  @override
  Future<(User?, Failure?)> registerOfflineDemo({
    required String phoneNumber,
    String? fullName,
    String? governorate,
  }) async {
    final user = User(
      id: _uuid.v4(),
      phoneNumber: phoneNumber,
      role: UserRole.victim,
      fullName: fullName ?? 'مستخدم تجريبي',
      governorate: governorate,
      isVerified: true,
      createdAt: DateTime.now(),
    );

    await _secureStorage.writeString(
      SecurityConstants.keyUserData,
      user.id,
    );
    await _localStorage.setBool(AppConstants.keyOfflineDemoMode, true);
    await _localStorage.setString('demo_phone', phoneNumber);
    return (user, null);
  }

  // ============ Helpers ============

  User? _readCachedUser() {
    final phone = _localStorage.getString('demo_phone') ?? '';
    return User(
      id: 'demo-user',
      phoneNumber: phone,
      role: UserRole.victim,
      fullName: 'مستخدم تجريبي',
      isVerified: true,
    );
  }

  Future<void> _saveAuthData(AuthResponseModel response) async {
    await _secureStorage.writeString(
      SecurityConstants.keyAccessToken,
      response.accessToken,
    );
    await _secureStorage.writeString(
      SecurityConstants.keyRefreshToken,
      response.refreshToken,
    );
  }

  Future<void> _clearAuthData() async {
    await _secureStorage.delete(SecurityConstants.keyAccessToken);
    await _secureStorage.delete(SecurityConstants.keyRefreshToken);
    await _secureStorage.delete(SecurityConstants.keyUserData);
    await _localStorage.setBool(AppConstants.keyOfflineDemoMode, false);
    await _localStorage.remove('demo_phone');
  }
}
