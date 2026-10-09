import 'package:napex_victim_app/core/error/failures.dart';

/// حساسية الكشف — العتبة الدنيا لاعتبار الرسالة ابتزازاً مؤكداً
/// (أعلى حساسية = عتبة أقل = كشف أكثر)
enum DetectionSensitivity {
  low('low', 'منخفضة — أخطاء أقل', 0.95),
  medium('medium', 'متوسطة — متوازنة', 0.85),
  high('high', 'عالية — كشف أكثر', 0.70);

  const DetectionSensitivity(this.value, this.labelAr, this.threshold);

  final String value;
  final String labelAr;
  final double threshold;

  static DetectionSensitivity fromValue(String value) {
    return DetectionSensitivity.values.firstWhere(
      (s) => s.value == value,
      orElse: () => DetectionSensitivity.medium,
    );
  }
}

/// نمط التنبيه عند الاكتشاف
enum NotificationMode {
  immediate('immediate', 'فورية'),
  silent('silent', 'صامتة — سجل فقط');

  const NotificationMode(this.value, this.labelAr);

  final String value;
  final String labelAr;

  static NotificationMode fromValue(String value) {
    return NotificationMode.values.firstWhere(
      (m) => m.value == value,
      orElse: () => NotificationMode.immediate,
    );
  }
}

/// إعدادات التطبيق
class AppSettings {
  const AppSettings({
    this.protectionEnabled = true,
    this.notificationsEnabled = true,
    this.autoReport = true,
    this.autoDeleteOldMessages = true,
    this.shareAnalytics = false,
    this.sensitivity = DetectionSensitivity.medium,
    this.notificationMode = NotificationMode.immediate,
    this.protectionStartHour = 0,
    this.protectionEndHour = 24,
    this.themeMode = 'system',
    this.monitoredPackages = const {},
    this.shareLocationOnPanic = false,
    this.language = 'ar',
    this.webGuardEnabled = false,
    this.urlFilterEnabled = true,
  });

  final bool protectionEnabled;
  final bool notificationsEnabled;
  final bool autoReport;
  final bool autoDeleteOldMessages;
  final bool shareAnalytics;
  final DetectionSensitivity sensitivity;
  final NotificationMode notificationMode;

  /// نافذة ساعات الحماية (0-24) — خارجها: تجميع بلا إزعاج
  final int protectionStartHour;
  final int protectionEndHour;

  /// system | light | dark
  final String themeMode;

  /// التطبيقات المُراقَبة (أسماء الحزم) — فارغ = كل التطبيقات المدعومة
  final Set<String> monitoredPackages;

  /// مشاركة الموقع عند تفعيل الطوارئ (افتراضياً معطلة — خصوصية)
  final bool shareLocationOnPanic;
  final String language;

  /// حرس المحتوى (NSFW) — يُحفظ ليبقى مفعلاً بعد إعادة التشغيل
  final bool webGuardEnabled;

  /// فلترة روابط المتصفح — تعمل بدون VPN (متوافقة مع أي VPN)
  final bool urlFilterEnabled;

  bool get isFullDay => protectionStartHour == 0 && protectionEndHour == 24;

  /// هل الساعة الحالية داخل نافذة الحماية؟ (يدعم النوافذ الملتفة مثل 20→6)
  bool isWithinProtectionHours(DateTime now) {
    if (isFullDay) return true;
    final hour = now.hour;
    if (protectionStartHour <= protectionEndHour) {
      return hour >= protectionStartHour && hour < protectionEndHour;
    }
    // نافذة ملتفة (مثال: 20 → 6)
    return hour >= protectionStartHour || hour < protectionEndHour;
  }

  /// هل تُراقَب هذه الحزمة؟ (قائمة فارغة = كل التطبيقات المدعومة)
  bool isPackageMonitored(String packageName) {
    if (monitoredPackages.isEmpty) return true;
    return monitoredPackages.contains(packageName);
  }

  AppSettings copyWith({
    bool? protectionEnabled,
    bool? notificationsEnabled,
    bool? autoReport,
    bool? autoDeleteOldMessages,
    bool? shareAnalytics,
    DetectionSensitivity? sensitivity,
    NotificationMode? notificationMode,
    int? protectionStartHour,
    int? protectionEndHour,
    String? themeMode,
    Set<String>? monitoredPackages,
    bool? shareLocationOnPanic,
    String? language,
    bool? webGuardEnabled,
    bool? urlFilterEnabled,
  }) {
    return AppSettings(
      protectionEnabled: protectionEnabled ?? this.protectionEnabled,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      autoReport: autoReport ?? this.autoReport,
      autoDeleteOldMessages:
          autoDeleteOldMessages ?? this.autoDeleteOldMessages,
      shareAnalytics: shareAnalytics ?? this.shareAnalytics,
      sensitivity: sensitivity ?? this.sensitivity,
      notificationMode: notificationMode ?? this.notificationMode,
      protectionStartHour: protectionStartHour ?? this.protectionStartHour,
      protectionEndHour: protectionEndHour ?? this.protectionEndHour,
      themeMode: themeMode ?? this.themeMode,
      monitoredPackages: monitoredPackages ?? this.monitoredPackages,
      shareLocationOnPanic: shareLocationOnPanic ?? this.shareLocationOnPanic,
      language: language ?? this.language,
      webGuardEnabled: webGuardEnabled ?? this.webGuardEnabled,
      urlFilterEnabled: urlFilterEnabled ?? this.urlFilterEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'protection_enabled': protectionEnabled,
        'notifications_enabled': notificationsEnabled,
        'auto_report': autoReport,
        'auto_delete_old_messages': autoDeleteOldMessages,
        'share_analytics': shareAnalytics,
        'sensitivity': sensitivity.value,
        'notification_mode': notificationMode.value,
        'protection_start_hour': protectionStartHour,
        'protection_end_hour': protectionEndHour,
        'theme_mode': themeMode,
        'monitored_packages': monitoredPackages.toList(),
        'share_location_on_panic': shareLocationOnPanic,
        'language': language,
        'web_guard_enabled': webGuardEnabled,
        'url_filter_enabled': urlFilterEnabled,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        protectionEnabled: json['protection_enabled'] as bool? ?? true,
        notificationsEnabled: json['notifications_enabled'] as bool? ?? true,
        autoReport: json['auto_report'] as bool? ?? true,
        autoDeleteOldMessages:
            json['auto_delete_old_messages'] as bool? ?? true,
        shareAnalytics: json['share_analytics'] as bool? ?? false,
        sensitivity: DetectionSensitivity.fromValue(
          json['sensitivity'] as String? ?? 'medium',
        ),
        notificationMode: NotificationMode.fromValue(
          json['notification_mode'] as String? ?? 'immediate',
        ),
        protectionStartHour: json['protection_start_hour'] as int? ?? 0,
        protectionEndHour: json['protection_end_hour'] as int? ?? 24,
        themeMode: json['theme_mode'] as String? ?? 'system',
        monitoredPackages: Set<String>.from(
          json['monitored_packages'] as List<dynamic>? ?? [],
        ),
        shareLocationOnPanic:
            json['share_location_on_panic'] as bool? ?? false,
        language: json['language'] as String? ?? 'ar',
        webGuardEnabled: json['web_guard_enabled'] as bool? ?? false,
        urlFilterEnabled: json['url_filter_enabled'] as bool? ?? true,
      );
}

abstract interface class SettingsRepository {
  Future<(AppSettings, Failure?)> getSettings();

  Future<(bool, Failure?)> updateSettings(AppSettings settings);

  Stream<AppSettings> watchSettings();

  Future<(bool, Failure?)> resetSettings();
}
