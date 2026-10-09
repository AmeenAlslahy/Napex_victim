import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:napex_victim_app/core/constants/channel_constants.dart';
import 'package:napex_victim_app/core/utils/logger.dart';

/// جسر قناة الأمان — فحص الجهاز (Root/محاكي/Debugger) والتوقيع
class SecurityChannel {
  static final SecurityChannel _instance = SecurityChannel._internal();

  factory SecurityChannel() => _instance;

  SecurityChannel._internal();

  static const MethodChannel _channel = MethodChannel(
    ChannelConstants.securityMethodChannel,
  );

  bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

  Future<bool> isDeviceRooted() => _invoke<bool>(
        ChannelConstants.methodIsRooted,
        fallback: false,
      );

  Future<bool> isEmulator() => _invoke<bool>(
        ChannelConstants.methodIsEmulator,
        fallback: false,
      );

  Future<bool> isDebuggerAttached() => _invoke<bool>(
        ChannelConstants.methodIsDebuggerAttached,
        fallback: false,
      );

  Future<bool> verifySignature() => _invoke<bool>(
        ChannelConstants.methodVerifySignature,
        fallback: true,
      );

  Future<String> getSignatureHash() =>
      _invoke<String>('getSignatureHash', fallback: '');

  /// ملخص أمني للجهاز
  Future<Map<String, bool>> securitySummary() async {
    final results = await Future.wait([
      isDeviceRooted(),
      isEmulator(),
      isDebuggerAttached(),
      verifySignature(),
    ]);
    return {
      'rooted': results[0],
      'emulator': results[1],
      'debugger': results[2],
      'signatureValid': results[3],
    };
  }

  Future<T> _invoke<T>(String method, {required T fallback}) async {
    if (!_isAndroid) return fallback;
    try {
      return await _channel.invokeMethod<T>(method) ?? fallback;
    } on MissingPluginException {
      return fallback;
    } on PlatformException catch (e) {
      AppLogger.error('$method failed: ${e.message}', tag: 'Security');
      return fallback;
    }
  }
}
