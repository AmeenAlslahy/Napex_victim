import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import 'package:napex_victim_app/core/constants/api_constants.dart';
import 'package:napex_victim_app/core/security/hash_service.dart';

/// إضافة توقيع رقمي ومعرّف فريد لكل طلب
/// (يمنع إعادة الإرسال ويتيح تتبع الطلبات على الخادم)
class SignatureInterceptor extends Interceptor {
  SignatureInterceptor({required HashService hashService})
      : _hashService = hashService;

  final HashService _hashService;
  final Uuid _uuid = const Uuid();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final requestId = _uuid.v4();
    final nonce = _uuid.v4();

    final payload = '${options.method}:${options.path}:$timestamp:$nonce';
    final signature = _hashService.sha256(payload);

    options.headers[ApiConstants.headerRequestId] = requestId;
    options.headers['X-Timestamp'] = timestamp;
    options.headers['X-Nonce'] = nonce;
    options.headers[ApiConstants.headerSignature] = signature;

    handler.next(options);
  }
}
