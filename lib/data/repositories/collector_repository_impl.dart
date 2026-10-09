import 'package:flutter/services.dart' show MissingPluginException;

import 'package:napex_victim_app/core/error/error_handler.dart';
import 'package:napex_victim_app/core/error/failures.dart';
import 'package:napex_victim_app/core/storage/local_storage.dart';
import 'package:napex_victim_app/core/utils/logger.dart';
import 'package:napex_victim_app/platform/channels/message_collector_channel.dart';
import 'package:napex_victim_app/domain/entities/message.dart';
import 'package:napex_victim_app/domain/repositories/collector_repository.dart';
import 'package:permission_handler/permission_handler.dart';

/// تنفيذ مستودع الجمع — يربط بين Domain وقناة المنصة الأصلية
///
/// على المنصات غير الأندرويد (ويندوز/ويب للتطوير) تعمل الدوال بلا أثر
/// (No-op) كي يبقى التطبيق قابلاً للتشغيل والاختبار.
class CollectorRepositoryImpl implements CollectorRepository {
  CollectorRepositoryImpl(this._channel, this._localStorage);

  final MessageCollectorChannel _channel;
  final LocalStorage _localStorage;

  /// علم يقرأه BootReceiver بعد إعادة تشغيل الجهاز — لا اعتماد على JSON داخلي
  static const String _protectionActiveKey = 'protection_active';

  @override
  Future<(bool, Failure?)> startCollection() async {
    try {
      await _channel.startCollectorService();
      await _localStorage.setBool(_protectionActiveKey, true);
      return (true, null);
    } catch (e) {
      if (e is MissingPluginException) return (true, null);
      return (false, ErrorHandler.mapExceptionToFailure(e));
    }
  }

  @override
  Future<(bool, Failure?)> stopCollection() async {
    try {
      await _channel.stopCollectorService();
      await _localStorage.setBool(_protectionActiveKey, false);
      return (true, null);
    } catch (e) {
      if (e is MissingPluginException) return (true, null);
      return (false, ErrorHandler.mapExceptionToFailure(e));
    }
  }

  @override
  Future<bool> isCollecting() async {
    try {
      return await _channel.isCollectorServiceRunning();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> isAccessibilityEnabled() async {
    try {
      return await _channel.isAccessibilityEnabled();
    } on MissingPluginException {
      return true; // منصات غير أندرويد: لا تحجب
    } catch (e) {
      // فشل حقيقي — نعرض «غير مفعّل» بدل ادعاء ناجح كاذب
      AppLogger.error(
        'isAccessibilityEnabled check failed',
        tag: 'Collector',
        error: e,
      );
      return false;
    }
  }

  @override
  Future<bool> isNotificationListenerEnabled() async {
    try {
      return await _channel.isNotificationListenerEnabled();
    } on MissingPluginException {
      return true;
    } catch (e) {
      AppLogger.error(
        'isNotificationListenerEnabled check failed',
        tag: 'Collector',
        error: e,
      );
      return false;
    }
  }

  @override
  Future<(bool, Failure?)> openAccessibilitySettings() =>
      _openSystemSettings(_channel.openAccessibilitySettings);

  @override
  Future<(bool, Failure?)> openNotificationSettings() =>
      _openSystemSettings(_channel.openNotificationSettings);

  /// سلسلة فتح إعدادات النظام مع بدائل واضحة — لا فشل صامت:
  /// 1) القناة الأصلية (أندرويد)  2) إعدادات التطبيق  3) رسالة سبب واضح
  Future<(bool, Failure?)> _openSystemSettings(
    Future<bool> Function() open,
  ) async {
    try {
      if (await open()) return (true, null);
    } on MissingPluginException {
      // منصة غير أندرويد — لا توجد خدمات نظام للجمع هناك
      return (
        false,
        const PlatformNotSupportedFailure(
          message: 'هذه الصلاحية تعمل على أندرويد فقط — على ويندوز استخدم زر «تحليل رسالة» للتجربة',
        ),
      );
    } catch (_) {
      // نجرّب البديل أدناه
    }

    // بديل عام: صفحة إعدادات التطبيق نفسها
    try {
      if (await openAppSettings()) {
        return (true, null);
      }
    } catch (_) {
      // الفشل النهائي أدناه
    }

    return (
      false,
      const PlatformFailure(
        message: 'تعذر فتح إعدادات النظام — افتح إعدادات الجهاز ثم إمكانية الوصول يدوياً',
      ),
    );
  }

  @override
  Future<bool> requestNotificationPermission() async {
    try {
      final status = await Permission.notification.request();
      return status.isGranted || status.isLimited;
    } catch (_) {
      return true; // منصات لا تحتاج صلاحية إشعارات
    }
  }

  @override
  Future<bool> isNotificationPermissionGranted() async {
    try {
      return await Permission.notification.isGranted;
    } catch (_) {
      return true;
    }
  }

  @override
  Future<bool> requestSmsPermission() async {
    try {
      final status = await Permission.sms.request();
      return status.isGranted || status.isLimited;
    } catch (_) {
      return true;
    }
  }

  @override
  Future<bool> isSmsPermissionGranted() async {
    try {
      return await Permission.sms.isGranted;
    } catch (_) {
      return true;
    }
  }

  @override
  Stream<CollectedMessage> get messageStream => _channel.messages;

  @override
  Future<List<String>> getMonitoredApps() async {
    try {
      return await _channel.getMonitoredApps();
    } catch (_) {
      return [];
    }
  }
}
