import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// التخزين الآمن — يلف FlutterSecureStorage (Keystore / Keychain)
class SecureStorage {
  SecureStorage(this._storage);

  final FlutterSecureStorage _storage;

  // ============ String ============
  Future<String?> readString(String key) => _storage.read(key: key);

  Future<void> writeString(String key, String value) =>
      _storage.write(key: key, value: value);

  // ============ Bool ============
  Future<bool> readBool(String key, {bool defaultValue = false}) async {
    final value = await _storage.read(key: key);
    return value == null ? defaultValue : value == 'true';
  }

  Future<void> writeBool(String key, bool value) =>
      _storage.write(key: key, value: value.toString());

  // ============ Int ============
  Future<int?> readInt(String key) async {
    final value = await _storage.read(key: key);
    return value == null ? null : int.tryParse(value);
  }

  Future<void> writeInt(String key, int value) =>
      _storage.write(key: key, value: value.toString());

  // ============ Delete ============
  Future<void> delete(String key) => _storage.delete(key: key);

  Future<void> deleteAll() => _storage.deleteAll();

  Future<bool> containsKey(String key) => _storage.containsKey(key: key);
}
