import 'dart:math';

import 'package:dio/dio.dart';

import 'package:napex_victim_app/core/constants/app_constants.dart';

/// إعادة المحاولة تلقائياً بتراجع أُسّي مع عشوائية (Exponential Backoff + Jitter)
class RetryInterceptor extends Interceptor {
  RetryInterceptor({
    required Dio dio,
    this.maxRetries = AppConstants.maxRetries,
    this.baseDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
  }) : _dio = dio;

  final Dio _dio;
  final int maxRetries;
  final Duration baseDelay;
  final Duration maxDelay;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final attempt = err.requestOptions.extra['retry_attempt'] as int? ?? 0;

    if (!_shouldRetry(err) || attempt >= maxRetries) {
      return handler.next(err);
    }

    await Future<void>.delayed(_calculateDelay(attempt));

    try {
      final options = err.requestOptions;
      options.extra['retry_attempt'] = attempt + 1;

      final response = await _dio.fetch<dynamic>(options);
      return handler.resolve(response);
    } on DioException catch (e) {
      return handler.next(e);
    } catch (_) {
      return handler.next(err);
    }
  }

  bool _shouldRetry(DioException err) {
    // إعادة المحاولة للعمليات القرائية فقط (GET/HEAD) — إعادة POST/PUT/DELETE
    // قد تكرر أثرها (تسجيل مزدوج، بلاغ مكرر) حتى لو فشل الاتصال
    final method = err.requestOptions.method.toUpperCase();
    if (method != 'GET' && method != 'HEAD') return false;

    // لا نعيد المحاولة لأخطاء العميل 4xx
    final statusCode = err.response?.statusCode ?? 0;
    if (statusCode >= 400 && statusCode < 500) return false;

    return switch (err.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError =>
        true,
      DioExceptionType.badResponse => statusCode >= 500,
      _ => false,
    };
  }

  Duration _calculateDelay(int attempt) {
    final exponential = baseDelay * pow(2, attempt);
    final jitter = Duration(milliseconds: Random().nextInt(1000));
    final total = exponential + jitter;
    return total > maxDelay ? maxDelay : total;
  }
}
