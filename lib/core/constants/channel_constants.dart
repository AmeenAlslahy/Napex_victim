/// ثوابت Platform Channels
abstract final class ChannelConstants {
  // ============ Message Collector ============
  static const String messageCollectorMethodChannel =
      'com.napex.victim/message_collector';
  static const String messageCollectorEventChannel =
      'com.napex.victim/message_stream';

  // ============ ML ============
  static const String mlMethodChannel = 'com.napex.victim/ml';

  // ============ Security ============
  static const String securityMethodChannel = 'com.napex.victim/security';

  // ============ Content Safety (VPN + NSFW Guard) ============
  static const String contentSafetyMethodChannel =
      'com.napex.victim/content_safety';
  static const String contentSafetyNsfwStream =
      'com.napex.victim/nsfw_stream';

  // ============ Method Names ============
  static const String methodIsAccessibilityEnabled = 'isAccessibilityEnabled';
  static const String methodIsNotificationListenerEnabled =
      'isNotificationListenerEnabled';
  static const String methodOpenAccessibilitySettings =
      'openAccessibilitySettings';
  static const String methodOpenNotificationSettings =
      'openNotificationSettings';
  static const String methodStartCollector = 'startCollectorService';
  static const String methodStopCollector = 'stopCollectorService';
  static const String methodGetMonitoredApps = 'getMonitoredApps';
  static const String methodClassifyText = 'classifyText';
  static const String methodLoadModel = 'loadModel';
  static const String methodIsRooted = 'isDeviceRooted';
  static const String methodIsEmulator = 'isEmulator';
  static const String methodIsDebuggerAttached = 'isDebuggerAttached';
  static const String methodVerifySignature = 'verifySignature';
}
