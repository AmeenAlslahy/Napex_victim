import 'package:dio/dio.dart';

import 'package:napex_victim_app/core/constants/api_constants.dart';
import 'package:napex_victim_app/core/constants/security_constants.dart';
import 'package:napex_victim_app/core/security/secure_storage.dart';

/// اعتراض إضافة توكن المصادقة للطلبات المحمية
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required SecureStorage secureStorage,
    required Future<void> Function() onTokenExpired,
  })  : _secureStorage = secureStorage,
        _onTokenExpired = onTokenExpired;

  final SecureStorage _secureStorage;
  final Future<void> Function() _onTokenExpired;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (_isPublicEndpoint(options.path)) {
      return handler.next(options);
    }

    final token = await _secureStorage.readString(
      SecurityConstants.keyAccessToken,
    );

    if (token != null && token.isNotEmpty) {
      options.headers[ApiConstants.headerAuthorization] =
          '${ApiConstants.bearerPrefix}$token';
    }

    return handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      await _onTokenExpired();
    }
    return handler.next(err);
  }

  bool _isPublicEndpoint(String path) =>
      ApiConstants.publicEndpoints.any(path.contains);
}
