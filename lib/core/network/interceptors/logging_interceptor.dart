import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// تسجيل تفاصيل الطلبات (للتطوير فقط) — يحجب الحقول الحساسة
class LoggingInterceptor extends Interceptor {
  LoggingInterceptor({this.enabled = kDebugMode});

  final bool enabled;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    if (!enabled) return handler.next(options);

    developer.log('→ ${options.method} ${options.uri}', name: 'HTTP');
    developer.log('  Headers: ${_sanitize(options.headers)}', name: 'HTTP');
    if (options.data != null) {
      developer.log('  Body: ${_sanitize(options.data)}', name: 'HTTP');
    }

    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    if (!enabled) return handler.next(response);

    developer.log('← ${response.statusCode} ${response.requestOptions.uri}',
        name: 'HTTP');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (!enabled) return handler.next(err);

    developer.log(
      '✗ ${err.response?.statusCode ?? 'ERR'} ${err.requestOptions.uri}',
      name: 'HTTP',
      error: err.message,
    );
    handler.next(err);
  }

  Object _sanitize(Object? data) {
    if (data is Map) {
      const sensitiveKeys = {
        'password',
        'token',
        'access_token',
        'refresh_token',
        'authorization',
        'otp',
      };
      return Map.fromEntries(
        data.entries.map(
          (entry) => MapEntry(
            entry.key,
            sensitiveKeys.contains(entry.key.toString().toLowerCase())
                ? '***REDACTED***'
                : entry.value,
          ),
        ),
      );
    }
    return data ?? '';
  }
}
