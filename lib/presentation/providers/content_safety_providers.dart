import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:napex_victim_app/presentation/providers/settings_providers.dart';

import 'package:napex_victim_app/domain/repositories/settings_repository.dart';
import 'package:napex_victim_app/platform/channels/content_safety_channel.dart';

/// حالة حماية المحتوى
class ContentSafetyState {
  const ContentSafetyState({
    this.webFilterRunning = false,
    this.guardEnabled = false,
    this.detectorAvailable = false,
    this.blocklistSize = 0,
    this.blockedCount = 0,
  });

  final bool webFilterRunning;
  final bool guardEnabled;
  final bool detectorAvailable;
  final int blocklistSize;
  final int blockedCount;

  ContentSafetyState copyWith({
    bool? webFilterRunning,
    bool? guardEnabled,
    bool? detectorAvailable,
    int? blocklistSize,
    int? blockedCount,
  }) {
    return ContentSafetyState(
      webFilterRunning: webFilterRunning ?? this.webFilterRunning,
      guardEnabled: guardEnabled ?? this.guardEnabled,
      detectorAvailable: detectorAvailable ?? this.detectorAvailable,
      blocklistSize: blocklistSize ?? this.blocklistSize,
      blockedCount: blockedCount ?? this.blockedCount,
    );
  }
}

/// متحكم حماية المحتوى — يربط VPN الفلترة وحرس NSFW
class ContentSafetyController extends StateNotifier<ContentSafetyState> {
  ContentSafetyController(this._channel, this._getSettings)
      : super(const ContentSafetyState()) {
    _init();
  }

  final ContentSafetyChannel _channel;
  final AppSettings Function() _getSettings;
  StreamSubscription<NsfwGuardEvent>? _guardSubscription;
  bool _initialized = false;

  Future<void> _init() async {
    if (_initialized) return;
    _initialized = true;

    final running = await _channel.isWebFilterRunning();
    final size = await _channel.loadBlocklist();
    state = state.copyWith(
      webFilterRunning: running,
      blocklistSize: size,
      detectorAvailable: await _channel.isNsfwModelAvailable(),
    );
    // استعادة الأعلام المحفوظة في الجهة الأصلية بعد كل إقلاع
    final settings = _getSettings();
    await _channel.setGuardEnabled(settings.webGuardEnabled);
    await _channel.setUrlFilterEnabled(settings.urlFilterEnabled);
    state = state.copyWith(guardEnabled: settings.webGuardEnabled);
    _listenGuard();
  }

  /// الاستماع لنتائج الحرس — الحجب نفسه يحدث في Kotlin (Overlay + إيقاف الالتقاط)
  void _listenGuard() {
    _guardSubscription?.cancel();
    _guardSubscription = _channel.nsfwStream().listen((event) {
      if (event.blocked) {
        state = state.copyWith(
          blockedCount: state.blockedCount + 1,
        );
      }
    });
  }

  Future<void> startWebFilter() async {
    await _channel.startWebFilter();
    state = state.copyWith(webFilterRunning: true);
  }

  Future<void> stopWebFilter() async {
    await _channel.stopWebFilter();
    state = state.copyWith(webFilterRunning: false);
  }

  Future<String> prepareVpn() => _channel.prepareVpn();

  /// صلاحية العرض فوق التطبيقات — شرط ظهور حاجب NSFW
  Future<bool> canDrawOverlays() => _channel.canDrawOverlays();

  Future<void> openOverlaySettings() => _channel.openOverlaySettings();

  /// فحص ذاتي: فلتر المواقع — {size, blockedOk, allowedOk}
  Future<Map<String, dynamic>?> selfTestWebFilter() =>
      _channel.selfTestWebFilter();

  /// فحص ذاتي: كاشف الصور — {available, sfw, nsfw}
  Future<Map<String, dynamic>?> selfTestNsfw() => _channel.selfTestNsfw();

  Future<void> setGuardEnabled(bool enabled) async {
    await _channel.setGuardEnabled(enabled);
    state = state.copyWith(guardEnabled: enabled);
  }

  Future<void> setUrlFilterEnabled(bool enabled) =>
      _channel.setUrlFilterEnabled(enabled);

  Future<int> refreshBlocklistSize() async {
    final size = await _channel.loadBlocklist();
    state = state.copyWith(blocklistSize: size);
    return size;
  }
}

/// مزود حماية المحتوى
final contentSafetyProvider =
    StateNotifierProvider<ContentSafetyController, ContentSafetyState>((ref) {
  return ContentSafetyController(
    ContentSafetyChannel(),
    () => ref.read(settingsProvider),
  );
});
