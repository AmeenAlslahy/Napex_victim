import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;

/// خدمة التجزئة — SHA-256 / HMAC
class HashService {
  const HashService();

  /// SHA-256 لنص
  String sha256(String input) {
    final bytes = utf8.encode(input);
    return crypto.sha256.convert(bytes).toString();
  }

  /// SHA-256 لبايتات (ملفات/وسائط)
  String sha256Bytes(List<int> bytes) =>
      crypto.sha256.convert(bytes).toString();

  /// SHA-512 لنص
  String sha512(String input) {
    final bytes = utf8.encode(input);
    return crypto.sha512.convert(bytes).toString();
  }

  /// HMAC-SHA256
  String hmacSha256(String message, String secret) {
    final key = utf8.encode(secret);
    final hmac = crypto.Hmac(crypto.sha256, key);
    return hmac.convert(utf8.encode(message)).toString();
  }

  /// HMAC-SHA256 لبايتات
  String hmacSha256Bytes(List<int> message, List<int> key) {
    final hmac = crypto.Hmac(crypto.sha256, key);
    return hmac.convert(message).toString();
  }
}
