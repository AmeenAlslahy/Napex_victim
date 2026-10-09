import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

import 'package:napex_victim_app/core/constants/security_constants.dart';
import 'package:napex_victim_app/core/error/exceptions.dart';
import 'package:napex_victim_app/core/security/secure_storage.dart';

/// حاوية النص المشفر — قابلة للتخزين كـ JSON
class EncryptedPayload {
  const EncryptedPayload({
    required this.cipherText,
    required this.iv,
    required this.mac,
  });

  final String cipherText; // base64
  final String iv; // base64
  final String mac; // hex (HMAC-SHA256)

  Map<String, dynamic> toJson() =>
      {'ct': cipherText, 'iv': iv, 'mac': mac};

  factory EncryptedPayload.fromJson(Map<String, dynamic> json) =>
      EncryptedPayload(
        cipherText: json['ct'] as String,
        iv: json['iv'] as String,
        mac: json['mac'] as String,
      );
}

/// حاوية البايتات المشفرة (للملفات)
class EncryptedBytes {
  const EncryptedBytes({required this.bytes, required this.iv, required this.mac});

  final Uint8List bytes;
  final Uint8List iv;
  final String mac;
}

/// خدمة التشفير — AES-256-CBC مع HMAC-SHA256 (نمط Encrypt-then-MAC)
/// المفتاح الرئيسي يُولَّد عشوائياً مرة واحدة ويُخزَّن في التخزين الآمن،
/// ثم تُشتق منه مفاتيح منفصلة للتشفير والتحقق.
class EncryptionService {
  EncryptionService(this._secureStorage);

  final SecureStorage _secureStorage;

  static const int _masterKeyLength = 32; // 256 bits
  static const int _ivLength = 16; // AES block size (CBC)

  // ذاكرة مؤقتة — الاشتقاق يحدث مرة واحدة في عمر العملية
  Uint8List? _cachedMasterKey;
  ({Uint8List encryptionKey, Uint8List macKey})? _cachedDerivedKeys;

  // ============ النصوص ============

  Future<EncryptedPayload> encryptString(String plainText) async {
    final payload = await encryptBytes(Uint8List.fromList(utf8.encode(plainText)));
    return EncryptedPayload(
      cipherText: base64.encode(payload.bytes),
      iv: base64.encode(payload.iv),
      mac: payload.mac,
    );
  }

  Future<String> decryptString(EncryptedPayload payload) async {
    final decrypted = await decryptBytes(
      EncryptedBytes(
        bytes: Uint8List.fromList(base64.decode(payload.cipherText)),
        iv: Uint8List.fromList(base64.decode(payload.iv)),
        mac: payload.mac,
      ),
    );
    return utf8.decode(decrypted);
  }

  // ============ البايتات ============

  Future<EncryptedBytes> encryptBytes(Uint8List data) async {
    try {
      final keys = await _deriveKeys();
      final iv = _generateIv();

      final encrypter = enc.Encrypter(
        enc.AES(enc.Key(keys.encryptionKey), mode: enc.AESMode.cbc),
      );
      final encrypted = encrypter.encryptBytes(data, iv: enc.IV(iv));

      return EncryptedBytes(
        bytes: Uint8List.fromList(encrypted.bytes),
        iv: iv,
        mac: _computeMac(iv, encrypted.bytes, keys.macKey),
      );
    } catch (e) {
      throw CryptoException(message: 'فشل التشفير: $e');
    }
  }

  Future<Uint8List> decryptBytes(EncryptedBytes payload) async {
    try {
      final keys = await _deriveKeys();

      // التحقق من السلامة قبل فك التشفير
      final expectedMac = _computeMac(payload.iv, payload.bytes, keys.macKey);
      if (!_constantTimeEquals(expectedMac, payload.mac)) {
        throw const CryptoException(message: 'فشل التحقق من سلامة البيانات');
      }

      final encrypter = enc.Encrypter(
        enc.AES(enc.Key(keys.encryptionKey), mode: enc.AESMode.cbc),
      );
      final decrypted = encrypter.decryptBytes(
        enc.Encrypted(payload.bytes),
        iv: enc.IV(payload.iv),
      );
      return Uint8List.fromList(decrypted);
    } on CryptoException {
      rethrow;
    } catch (e) {
      throw CryptoException(message: 'فشل فك التشفير: $e');
    }
  }

  // ============ المفاتيح ============

  Future<Uint8List> _getOrCreateMasterKey() async {
    final cached = _cachedMasterKey;
    if (cached != null) return cached;

    final stored = await _secureStorage.readString(
      SecurityConstants.keyEncryptionKey,
    );

    Uint8List key;
    if (stored != null && stored.isNotEmpty) {
      key = Uint8List.fromList(base64.decode(stored));
    } else {
      final random = Random.secure();
      key = Uint8List.fromList(
        List.generate(_masterKeyLength, (_) => random.nextInt(256)),
      );
      await _secureStorage.writeString(
        SecurityConstants.keyEncryptionKey,
        base64.encode(key),
      );
    }

    _cachedMasterKey = key;
    return key;
  }

  Future<({Uint8List encryptionKey, Uint8List macKey})> _deriveKeys() async {
    final cached = _cachedDerivedKeys;
    if (cached != null) return cached;

    final master = await _getOrCreateMasterKey();
    final encryptionKey =
        sha256.convert([...master, ...utf8.encode('napex/enc')]).bytes;
    final macKey =
        sha256.convert([...master, ...utf8.encode('napex/mac')]).bytes;
    final derived = (
      encryptionKey: Uint8List.fromList(encryptionKey),
      macKey: Uint8List.fromList(macKey),
    );

    _cachedDerivedKeys = derived;
    return derived;
  }

  // ============ Helpers ============

  Uint8List _generateIv() {
    final random = Random.secure();
    return Uint8List.fromList(
      List.generate(_ivLength, (_) => random.nextInt(256)),
    );
  }

  String _computeMac(List<int> iv, List<int> cipher, List<int> macKey) {
    final hmac = Hmac(sha256, macKey);
    return hmac.convert([...iv, ...cipher]).toString();
  }

  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
