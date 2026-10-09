import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:napex_victim_app/core/constants/channel_constants.dart';

/// حدث من حرس الوسائط (يصنّف Kotlin على الجهاز) — لا صور تُبث أبداً
class NsfwGuardEvent {
  const NsfwGuardEvent({
    required this.blocked,
    required this.score,
    required this.at,
  });

  factory NsfwGuardEvent.fromMap(Map<Object?, Object?> map) => NsfwGuardEvent(
        blocked: map['type'] == 'nsfw_blocked',
        score: (map['score'] as num?)?.toDouble() ?? 0.0,
        at: DateTime.fromMillisecondsSinceEpoch(
          (map['at'] as num?)?.toInt() ?? 0,
        ),
      );

  final bool blocked;
  final double score;
  final DateTime at;
}

/// قناة حماية المحتوى — فلترة DNS (VPN) + حرس NSFW (التصنيف داخل Kotlin)
class ContentSafetyChannel {
  ContentSafetyChannel();

  static const MethodChannel _method = MethodChannel(
    ChannelConstants.contentSafetyMethodChannel,
  );
  static const EventChannel _nsfwStream = EventChannel(
    ChannelConstants.contentSafetyNsfwStream,
  );

  /// نتائج حرس الوسائط من Kotlin — الحجب يحدث أصلاً في الطرف الأصلي
  /// (Overlay + إيقاف الالتقاط)؛ هنا للإحصاءات وواجهة المستخدم فقط.
  Stream<NsfwGuardEvent> nsfwStream() {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const Stream.empty();
    }
    return _nsfwStream.receiveBroadcastStream().map((event) {
      if (event is Map) return NsfwGuardEvent.fromMap(event);
      throw StateError('bad nsfw event');
    });
  }

  Future<int> loadBlocklist() async {
    try {
      return await _method.invokeMethod<int>('loadBlocklist') ?? 0;
    } on MissingPluginException {
      return 0;
    }
  }

  /// هل نموذج NSFW مضمّن في هذا البناء؟ (يفحص الجهة الأصلية)
  Future<bool> isNsfwModelAvailable() async {
    try {
      return await _method.invokeMethod<bool>('isNsfwModelAvailable') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  /// "granted" | "consent_needed" | "unavailable"
  Future<String> prepareVpn() async {
    try {
      return await _method.invokeMethod<String>('prepareVpn') ?? 'consent_needed';
    } on MissingPluginException {
      return 'unavailable';
    }
  }

  Future<void> startWebFilter() async {
    try {
      await _method.invokeMethod<void>('startWebFilter');
    } on MissingPluginException {
      // منصة غير مدعومة
    }
  }

  Future<void> stopWebFilter() async {
    try {
      await _method.invokeMethod<void>('stopWebFilter');
    } on MissingPluginException {
      // منصة غير مدعومة
    }
  }

  Future<bool> isWebFilterRunning() async {
    try {
      return await _method.invokeMethod<bool>('isWebFilterRunning') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  /// هل صلاحية "العرض فوق التطبيقات" ممنوحة؟ (بدونها لا يظهر حاجب NSFW)
  Future<bool> canDrawOverlays() async {
    try {
      return await _method.invokeMethod<bool>('canDrawOverlays') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  /// فتح إعدادات منح صلاحية العرض فوق التطبيقات
  Future<void> openOverlaySettings() async {
    try {
      await _method.invokeMethod<void>('openOverlaySettings');
    } on MissingPluginException {
      // منصة غير مدعومة
    }
  }

  /// فحص ذاتي لفلتر المواقع — {size, blockedOk, allowedOk}
  Future<Map<String, dynamic>?> selfTestWebFilter() async {
    try {
      return await _method.invokeMapMethod<String, dynamic>('selfTestWebFilter');
    } on MissingPluginException {
      return null;
    }
  }

  /// فحص ذاتي لكاشف الصور — {available, sfw, nsfw}
  Future<Map<String, dynamic>?> selfTestNsfw() async {
    try {
      return await _method.invokeMapMethod<String, dynamic>('selfTestNsfw');
    } on MissingPluginException {
      return null;
    }
  }

  /// فلتر روابط المتصفح — بدون VPN، متوافق مع أي VPN
  Future<void> setUrlFilterEnabled(bool enabled) async {
    try {
      await _method.invokeMethod<void>(
        'setUrlFilterEnabled',
        {'enabled': enabled},
      );
    } on MissingPluginException {
      // منصة غير مدعومة
    }
  }

  Future<void> setGuardEnabled(bool enabled) async {
    try {
      await _method.invokeMethod<void>(
        'setGuardEnabled',
        {'enabled': enabled},
      );
    } on MissingPluginException {
      // منصة غير مدعومة
    }
  }
}
