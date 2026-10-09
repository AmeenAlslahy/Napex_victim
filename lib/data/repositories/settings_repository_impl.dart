import 'dart:async';
import 'dart:convert';

import 'package:napex_victim_app/core/error/failures.dart';
import 'package:napex_victim_app/core/storage/local_storage.dart';
import 'package:napex_victim_app/domain/repositories/settings_repository.dart';

/// تنفيذ مستودع الإعدادات — تخزين JSON محلي مع بث التغييرات
class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl(this._localStorage);

  final LocalStorage _localStorage;
  static const String _key = 'app_settings';

  final StreamController<AppSettings> _controller =
      StreamController<AppSettings>.broadcast();

  AppSettings _current = const AppSettings();
  bool _initialized = false;

  AppSettings get current => _current;

  void _ensureInitialized() {
    if (_initialized) return;
    final raw = _localStorage.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      try {
        _current = AppSettings.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      } catch (_) {
        _current = const AppSettings();
      }
    }
    _initialized = true;
  }

  @override
  Future<(AppSettings, Failure?)> getSettings() async {
    try {
      _ensureInitialized();
      return (_current, null);
    } catch (e) {
      return (const AppSettings(), UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<(bool, Failure?)> updateSettings(AppSettings settings) async {
    try {
      _ensureInitialized();
      _current = settings;
      await _localStorage.setString(_key, jsonEncode(settings.toJson()));
      _controller.add(settings);
      return (true, null);
    } catch (e) {
      return (false, UnknownFailure(message: e.toString()));
    }
  }

  @override
  Stream<AppSettings> watchSettings() async* {
    _ensureInitialized();
    yield _current;
    yield* _controller.stream;
  }

  @override
  Future<(bool, Failure?)> resetSettings() =>
      updateSettings(const AppSettings());
}
