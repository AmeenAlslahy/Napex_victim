import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:napex_victim_app/core/constants/security_constants.dart';
import 'package:napex_victim_app/domain/repositories/settings_repository.dart';
import 'package:napex_victim_app/presentation/providers/core_providers.dart';

/// متحكم الإعدادات — حالة موحدة تُبث لكل الشاشات
class SettingsController extends StateNotifier<AppSettings> {
  SettingsController(this._repository) : super(const AppSettings()) {
    _load();
  }

  final SettingsRepository _repository;

  Future<void> _load() async {
    final (settings, _) = await _repository.getSettings();
    state = settings;
  }

  Future<void> _save(AppSettings settings) async {
    state = settings;
    await _repository.updateSettings(settings);
  }

  Future<void> setProtectionEnabled(bool value) =>
      _save(state.copyWith(protectionEnabled: value));

  Future<void> setNotificationsEnabled(bool value) =>
      _save(state.copyWith(notificationsEnabled: value));

  Future<void> setAutoReport(bool value) =>
      _save(state.copyWith(autoReport: value));

  Future<void> setAutoDeleteOldMessages(bool value) =>
      _save(state.copyWith(autoDeleteOldMessages: value));

  Future<void> setShareAnalytics(bool value) =>
      _save(state.copyWith(shareAnalytics: value));

  Future<void> setSensitivity(DetectionSensitivity value) =>
      _save(state.copyWith(sensitivity: value));

  Future<void> setNotificationMode(NotificationMode value) =>
      _save(state.copyWith(notificationMode: value));

  Future<void> setProtectionHours({
    required int start,
    required int end,
  }) =>
      _save(state.copyWith(protectionStartHour: start, protectionEndHour: end));

  Future<void> setThemeMode(String value) =>
      _save(state.copyWith(themeMode: value));

  Future<void> toggleMonitoredPackage(String packageName) {
    final packages = {...state.monitoredPackages};
    if (packages.contains(packageName)) {
      packages.remove(packageName);
    } else {
      packages.add(packageName);
    }
    return _save(state.copyWith(monitoredPackages: packages));
  }

  Future<void> setMonitoredPackages(Set<String> packages) =>
      _save(state.copyWith(monitoredPackages: packages));

  Future<void> setShareLocationOnPanic(bool value) =>
      _save(state.copyWith(shareLocationOnPanic: value));

  Future<void> setWebGuardEnabled(bool value) =>
      _save(state.copyWith(webGuardEnabled: value));

  Future<void> setUrlFilterEnabled(bool value) =>
      _save(state.copyWith(urlFilterEnabled: value));

  Future<void> reset() async {
    await _repository.resetSettings();
    state = const AppSettings();
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsController, AppSettings>((ref) {
  return SettingsController(ref.watch(settingsRepositoryProvider));
});

/// هل الإبلاغ التلقائي مفعّل؟ (يُستخدم في متحكم الجمع)
/// هل القفل الأبوي مضبوط؟
final parentalPinSetProvider = FutureProvider<bool>((ref) async {
  final stored = await ref
      .watch(secureStorageProvider)
      .readString(SecurityConstants.keyParentalPin);
  return stored != null && stored.isNotEmpty;
});

final autoReportEnabledProvider = Provider<bool>(
  (ref) => ref.watch(settingsProvider).autoReport,
);

/// هل الإشعارات مفعّلة؟
final notificationsEnabledProvider = Provider<bool>(
  (ref) => ref.watch(settingsProvider).notificationsEnabled,
);
