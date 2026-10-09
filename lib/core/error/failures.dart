import 'package:equatable/equatable.dart';

/// الفئات الأساسية للأخطاء — طبقة Domain/Core
sealed class Failure extends Equatable {
  const Failure({required this.message, this.code, this.details});

  final String message;
  final String? code;
  final Map<String, dynamic>? details;

  @override
  List<Object?> get props => [message, code, details];
}

// ============ Network Failures ============
final class NetworkFailure extends Failure {
  const NetworkFailure({
    required super.message,
    super.code,
    super.details,
    this.statusCode,
  });

  final int? statusCode;

  @override
  List<Object?> get props => [message, code, details, statusCode];
}

final class NoInternetFailure extends Failure {
  const NoInternetFailure()
      : super(message: 'لا يوجد اتصال بالإنترنت', code: 'NO_INTERNET');
}

final class TimeoutFailure extends Failure {
  const TimeoutFailure()
      : super(message: 'انتهت مهلة الاتصال', code: 'TIMEOUT');
}

final class ServerFailure extends Failure {
  const ServerFailure({required super.message, super.code, super.details});
}

final class ForbiddenFailure extends Failure {
  const ForbiddenFailure()
      : super(message: 'ممنوع الوصول', code: 'FORBIDDEN');
}

final class RateLimitedFailure extends Failure {
  const RateLimitedFailure()
      : super(
          message: 'عدد كبير من الطلبات، حاول لاحقاً',
          code: 'RATE_LIMITED',
        );
}

// ============ Auth Failures ============
final class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure()
      : super(message: 'غير مصرح بالوصول', code: 'UNAUTHORIZED');
}

final class TokenExpiredFailure extends Failure {
  const TokenExpiredFailure()
      : super(message: 'انتهت صلاحية الجلسة', code: 'TOKEN_EXPIRED');
}

final class InvalidCredentialsFailure extends Failure {
  const InvalidCredentialsFailure()
      : super(message: 'بيانات الدخول غير صحيحة', code: 'INVALID_CREDENTIALS');
}

final class OtpInvalidFailure extends Failure {
  const OtpInvalidFailure()
      : super(message: 'رمز التحقق غير صحيح', code: 'OTP_INVALID');
}

// ============ Database Failures ============
final class DatabaseFailure extends Failure {
  const DatabaseFailure({required super.message, super.code, super.details});
}

final class NotFoundFailure extends Failure {
  const NotFoundFailure({required super.message})
      : super(code: 'NOT_FOUND');
}

// ============ ML Failures ============
final class MLModelFailure extends Failure {
  const MLModelFailure({required super.message})
      : super(code: 'ML_MODEL_ERROR');
}

final class MLInferenceFailure extends Failure {
  const MLInferenceFailure({required super.message})
      : super(code: 'ML_INFERENCE_ERROR');
}

// ============ Platform Failures ============
final class PlatformFailure extends Failure {
  const PlatformFailure({required super.message, super.code, super.details});
}

final class PermissionDeniedFailure extends Failure {
  const PermissionDeniedFailure({required super.message})
      : super(code: 'PERMISSION_DENIED');
}

final class ServiceNotEnabledFailure extends Failure {
  const ServiceNotEnabledFailure({required super.message})
      : super(code: 'SERVICE_NOT_ENABLED');
}

final class PlatformNotSupportedFailure extends Failure {
  const PlatformNotSupportedFailure({required super.message})
      : super(code: 'PLATFORM_NOT_SUPPORTED');
}

// ============ Security Failures ============
final class SecurityFailure extends Failure {
  const SecurityFailure({required super.message, super.code, super.details});
}

final class EncryptionFailure extends Failure {
  const EncryptionFailure({required super.message})
      : super(code: 'ENCRYPTION_ERROR');
}

final class IntegrityFailure extends Failure {
  const IntegrityFailure({required super.message})
      : super(code: 'INTEGRITY_ERROR');
}

// ============ Validation Failures ============
final class ValidationFailure extends Failure {
  const ValidationFailure({required super.message, super.details})
      : super(code: 'VALIDATION_ERROR');
}

final class UnknownFailure extends Failure {
  const UnknownFailure({required super.message})
      : super(code: 'UNKNOWN_ERROR');
}
