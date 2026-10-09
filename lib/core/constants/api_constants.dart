/// ثوابت API
abstract final class ApiConstants {
  // ============ Base URLs ============
  static const String baseUrlProd = 'https://api.napex.gov.ye';
  static const String baseUrlStaging = 'https://staging-api.napex.gov.ye';
  /// 10.0.2.2 يعمل على المحاكي فقط — للجهاز الحقيقي عنوان الشبكة المحلية للكمبيوتر.
  /// تغييره بدون تعديل الكود: flutter run --dart-define=NAPEX_API_URL=http://192.168.x.x:8000
  static const String baseUrlDev = String.fromEnvironment(
    'NAPEX_API_URL',
    defaultValue: 'http://192.168.0.198:8000',
  );

  /// البيئة الحالية — غيّرها حسب بيئة البناء
  static const String baseUrl = baseUrlDev;

  // ============ API Version ============
  static const String apiVersion = 'v1';
  static const String apiPrefix = '/api/$apiVersion';

  // ============ Endpoints ============
  // Auth
  static const String register = '$apiPrefix/auth/register';
  static const String verifyOtp = '$apiPrefix/auth/verify-otp';
  static const String login = '$apiPrefix/auth/login';
  static const String refreshToken = '$apiPrefix/auth/refresh';
  static const String logout = '$apiPrefix/auth/logout';
  static const String me = '$apiPrefix/auth/me';
  static const String deleteAccount = '$apiPrefix/auth/account';

  // Reports
  static const String reports = '$apiPrefix/reports';
  static String reportById(String id) => '$apiPrefix/reports/$id';
  static String reportStatus(String id) => '$apiPrefix/reports/$id/status';

  // Evidence
  static const String uploadEvidence = '$apiPrefix/evidence/upload';
  static String evidenceById(String id) => '$apiPrefix/evidence/$id';

  // Config
  static const String config = '$apiPrefix/config';
  static const String keywords = '$apiPrefix/config/keywords';

  // Blocklist
  static const String blocklist = '$apiPrefix/blocklist';

  // Victim
  static const String victimNotifications = '$apiPrefix/victim/notifications';

  // Health
  static const String health = '$apiPrefix/health';

  // ============ Headers ============
  static const String headerAuthorization = 'Authorization';
  static const String headerContentType = 'Content-Type';
  static const String headerAcceptLanguage = 'Accept-Language';
  static const String headerDeviceId = 'X-Device-Id';
  static const String headerAppVersion = 'X-App-Version';
  static const String headerRequestId = 'X-Request-Id';
  static const String headerSignature = 'X-Signature';

  // ============ Auth ============
  static const String bearerPrefix = 'Bearer ';

  // ============ Public endpoints (بدون مصادقة) ============
  static const List<String> publicEndpoints = [
    '/auth/register',
    '/auth/login',
    '/auth/verify-otp',
    '/auth/refresh',
    '/health',
  ];
}
