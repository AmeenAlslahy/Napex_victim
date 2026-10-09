import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:napex_victim_app/core/constants/security_constants.dart';
import 'package:napex_victim_app/core/utils/logger.dart';

/// خدمة الإشعارات المحلية — تنبيه المستخدم عند اكتشاف ابتزاز
class AppNotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// يُربط بموجّه التطبيق — نقرة الإشعار تفتح مساراً محدداً
  void Function(String route)? onNotificationTap;

  Future<void> init() async {
    if (_initialized) return;
    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const settings = InitializationSettings(android: androidInit);
      await _plugin.initialize(
        settings,
        onDidReceiveNotificationResponse: (details) {
          final route = details.payload;
          if (route != null && route.isNotEmpty) {
            onNotificationTap?.call(route);
          }
        },
      );
      _initialized = true;
    } catch (e) {
      AppLogger.error('Notification init failed', tag: 'Notify', error: e);
    }
  }

  /// إشعار تنبيه ابتزاز عالي الأولوية — النقر عليه يفتح قائمة البلاغات
  Future<void> showExtortionAlert({
    required String title,
    required String body,
  }) async {
    if (!_initialized) await init();
    try {
      const androidDetails = AndroidNotificationDetails(
        SecurityConstants.alertChannelId,
        SecurityConstants.alertChannelName,
        channelDescription: SecurityConstants.alertChannelDescription,
        importance: Importance.max,
        priority: Priority.high,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
      );
      const details = NotificationDetails(android: androidDetails);
      await _plugin.show(
        DateTime.now().millisecondsSinceEpoch % 100000,
        title,
        body,
        details,
        payload: '/reports',
      );
    } catch (e) {
      AppLogger.error('Notification show failed', tag: 'Notify', error: e);
    }
  }

  Future<void> cancelAll() => _plugin.cancelAll();
}

/// تفعيل الخدمة عند بدء التشغيل — تُستدعى من bootstrap (متجاهَلة النتيجة)
Future<void> initNotifications(AppNotificationService service) async {
  if (!kIsWeb) await service.init();
}
