/// ثوابت التطبيق العامة
abstract final class AppConstants {
  // ============ App Info ============
  static const String appName = 'NAP-EX';
  static const String appNameAr = 'منصة مكافحة الابتزاز الإلكتروني';
  static const String appVersion = '1.0.0';

  // ============ Timeouts ============
  static const Duration connectionTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 20);
  static const Duration sendTimeout = Duration(seconds: 10);

  // ============ Pagination ============
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // ============ Retry Policy ============
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);

  // ============ ML Thresholds ============
  static const double extortionThreshold = 0.85;
  static const double suspiciousThreshold = 0.60;
  static const double highConfidenceThreshold = 0.95;

  // ============ Sync Intervals ============
  static const Duration reportSyncInterval = Duration(minutes: 15);

  // ============ File Limits ============
  static const int maxEvidenceSizeBytes = 25 * 1024 * 1024; // 25 MB
  static const int maxEvidenceCount = 10;

  // ============ OTP ============
  static const int otpLength = 6;
  static const Duration otpExpiry = Duration(minutes: 3);
  static const Duration otpResendDelay = Duration(seconds: 60);

  // ============ Onboarding ============
  static const String keyOnboardingCompleted = 'onboarding_completed';
  static const String keyOfflineDemoMode = 'offline_demo_mode';

  // ============ العرض ============
  /// عدد البلاغات المعروضة في «آخر البلاغات» بلوحة التحكم
  static const int recentReportsCount = 3;

  /// حد سجل النشاط المعروض للمستخدم
  static const int activityLogLimit = 200;
}
