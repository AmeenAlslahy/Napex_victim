/// ثوابت الأمان
abstract final class SecurityConstants {
  // ============ Encryption ============
  static const int aesKeyLength = 256;
  static const int gcmIvLength = 12;

  // ============ Hashing ============
  static const String hashAlgorithm = 'SHA-256';

  // ============ Storage Keys ============
  static const String keyAccessToken = 'access_token';
  static const String keyRefreshToken = 'refresh_token';
  static const String keyUserData = 'user_data';
  static const String keyDeviceId = 'device_id';
  static const String keyEncryptionKey = 'encryption_key';
  static const String keyBiometricEnabled = 'biometric_enabled';
  static const String keyParentalPin = 'parental_pin_hash';

  // ============ Notification Channel ============
  static const String alertChannelId = 'napex_alerts';
  static const String alertChannelName = 'تنبيهات الابتزاز';
  static const String alertChannelDescription =
      'تنبيهات فورية عند اكتشاف رسائل ابتزاز';
}
