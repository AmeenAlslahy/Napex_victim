/// استثناءات طبقة البيانات
sealed class AppException implements Exception {
  const AppException({required this.message, this.code, this.details});

  final String message;
  final String? code;
  final Map<String, dynamic>? details;

  @override
  String toString() => '$runtimeType: $message';
}

// ============ Network ============
final class ServerException extends AppException {
  const ServerException({
    required super.message,
    super.code,
    super.details,
    this.statusCode,
  });

  final int? statusCode;
}

final class NetworkException extends AppException {
  const NetworkException({required super.message});
}

final class RequestTimeoutException extends AppException {
  const RequestTimeoutException() : super(message: 'Connection timed out');
}

// ============ Cache ============
final class CacheException extends AppException {
  const CacheException({required super.message});
}

// ============ Platform ============
final class PlatformChannelException extends AppException {
  const PlatformChannelException({required super.message, super.code});
}

// ============ ML ============
final class MLException extends AppException {
  const MLException({required super.message});
}

// ============ Security ============
final class CryptoException extends AppException {
  const CryptoException({required super.message});
}

// ============ Validation ============
final class ValidationException extends AppException {
  const ValidationException({required super.message, super.details});
}
