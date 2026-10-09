import 'package:dio/dio.dart';

import 'package:napex_victim_app/core/constants/api_constants.dart';

/// واجهة مصادقة الخادم — تُعيد خرائط JSON خام (التحليل في المستودع)
class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> register(Map<String, dynamic> body) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiConstants.register,
      data: body,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> verifyOtp(Map<String, dynamic> body) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiConstants.verifyOtp,
      data: body,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> login(Map<String, dynamic> body) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiConstants.login,
      data: body,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> refreshToken(Map<String, dynamic> body) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiConstants.refreshToken,
      data: body,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<void> logout() => _dio.post(ApiConstants.logout);

  Future<Map<String, dynamic>> getCurrentUser() async {
    final response = await _dio.get<Map<String, dynamic>>(ApiConstants.me);
    return response.data ?? <String, dynamic>{};
  }

  Future<void> deleteAccount() => _dio.delete(ApiConstants.deleteAccount);
}
