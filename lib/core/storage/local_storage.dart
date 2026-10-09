import 'package:shared_preferences/shared_preferences.dart';

/// التخزين المحلي الخفيف (إعدادات عامة غير حساسة)
class LocalStorage {
  LocalStorage(this._prefs);

  final SharedPreferences _prefs;

  // ============ Bool ============
  bool getBool(String key, {bool defaultValue = false}) =>
      _prefs.getBool(key) ?? defaultValue;

  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);

  // ============ String ============
  String? getString(String key) => _prefs.getString(key);

  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  // ============ Int ============
  int? getInt(String key) => _prefs.getInt(key);

  Future<void> setInt(String key, int value) => _prefs.setInt(key, value);

  // ============ List ============
  List<String> getStringList(String key) =>
      _prefs.getStringList(key) ?? const [];

  Future<void> setStringList(String key, List<String> value) =>
      _prefs.setStringList(key, value);

  // ============ Remove ============
  Future<void> remove(String key) => _prefs.remove(key);

  Future<void> clear() => _prefs.clear();
}
