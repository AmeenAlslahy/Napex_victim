import 'package:dio/dio.dart';

import 'package:napex_victim_app/core/error/exceptions.dart';
import 'package:napex_victim_app/core/error/failures.dart';

/// معالج الأخطاء المركزي — يحوّل الاستثناءات إلى Failures
abstract final class ErrorHandler {
  static Failure mapExceptionToFailure(Object exception) {
    return switch (exception) {
      // Network
      ServerException(:final message, :final code, :final statusCode) =>
        NetworkFailure(message: message, code: code, statusCode: statusCode),
      NetworkException(:final message) => NetworkFailure(message: message),
      RequestTimeoutException() => const TimeoutFailure(),
      DioException dioException => _mapDioException(dioException),

      // Cache
      CacheException(:final message) => DatabaseFailure(message: message),

      // Platform
      PlatformChannelException(:final message, :final code) =>
        PlatformFailure(message: message, code: code),

      // ML
      MLException(:final message) => MLModelFailure(message: message),

      // Security
      CryptoException(:final message) => EncryptionFailure(message: message),

      // Validation
      ValidationException(:final message, :final details) =>
        ValidationFailure(message: message, details: details),

      // Fallback
      _ => UnknownFailure(message: exception.toString()),
    };
  }

  static Failure _mapDioException(DioException e) {
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.transformTimeout =>
        const TimeoutFailure(),
      DioExceptionType.connectionError => const NoInternetFailure(),
      DioExceptionType.badResponse => _mapBadResponse(e),
      DioExceptionType.cancel => const NetworkFailure(
          message: 'تم إلغاء الطلب',
          code: 'CANCELLED',
        ),
      DioExceptionType.badCertificate => const SecurityFailure(
          message: 'شهادة الأمان غير صالحة',
          code: 'BAD_CERTIFICATE',
        ),
      DioExceptionType.unknown => NetworkFailure(
          message: e.message ?? 'خطأ غير معروف في الشبكة',
        ),
    };
  }

  static Failure _mapBadResponse(DioException e) {
    final statusCode = e.response?.statusCode ?? 0;
    final data = e.response?.data;
    final serverMessage = _extractMessage(data);

    return switch (statusCode) {
      400 => ValidationFailure(
          message: serverMessage ?? 'طلب غير صالح',
          details: {'statusCode': statusCode},
        ),
      401 => const UnauthorizedFailure(),
      403 => const ForbiddenFailure(),
      404 => NotFoundFailure(
          message: serverMessage ?? 'المورد غير موجود',
        ),
      422 => ValidationFailure(
          message: serverMessage ?? 'بيانات غير صالحة',
          details: data is Map ? Map<String, dynamic>.from(data) : null,
        ),
      429 => const RateLimitedFailure(),
      >= 500 => ServerFailure(
          message: serverMessage ?? 'خطأ في الخادم',
          code: 'SERVER_ERROR',
        ),
      _ => NetworkFailure(
          message: serverMessage ?? 'خطأ غير متوقع',
          statusCode: statusCode,
        ),
    };
  }

  static String? _extractMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data['message'] as String? ??
          data['error'] as String? ??
          data['detail'] as String?;
    }
    return null;
  }
}
