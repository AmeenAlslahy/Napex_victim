import 'package:dio/dio.dart';

import 'package:napex_victim_app/core/constants/api_constants.dart';
import 'package:napex_victim_app/core/constants/app_constants.dart';
import 'package:napex_victim_app/core/network/interceptors/auth_interceptor.dart';
import 'package:napex_victim_app/core/network/interceptors/logging_interceptor.dart';
import 'package:napex_victim_app/core/network/interceptors/retry_interceptor.dart';
import 'package:napex_victim_app/core/network/interceptors/signature_interceptor.dart';

/// عميل HTTP مركزي مكوَّن بالاعتراضات الأمنية
class DioClient {
  DioClient({
    required AuthInterceptor authInterceptor,
    required LoggingInterceptor loggingInterceptor,
    required SignatureInterceptor signatureInterceptor,
  })  : _authInterceptor = authInterceptor,
        _loggingInterceptor = loggingInterceptor,
        _signatureInterceptor = signatureInterceptor;

  final AuthInterceptor _authInterceptor;
  final LoggingInterceptor _loggingInterceptor;
  final SignatureInterceptor _signatureInterceptor;

  late final Dio dio = _buildDio();

  Dio _buildDio() {
    final options = BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: AppConstants.connectionTimeout,
      receiveTimeout: AppConstants.receiveTimeout,
      sendTimeout: AppConstants.sendTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Accept-Language': 'ar',
      },
    );

    final dio = Dio(options);

    // ترتيب الاعتراضات مهم:
    // إعادة المحاولة → المصادقة → التوقيع → التسجيل
    dio.interceptors.addAll([
      RetryInterceptor(dio: dio),
      _authInterceptor,
      _signatureInterceptor,
      _loggingInterceptor,
    ]);

    return dio;
  }

  void dispose() {
    dio.close(force: true);
  }
}
