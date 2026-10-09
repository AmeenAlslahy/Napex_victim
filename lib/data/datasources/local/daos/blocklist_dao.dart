import 'package:sqflite/sqflite.dart';

import 'package:napex_victim_app/core/constants/db_constants.dart';
import 'package:napex_victim_app/data/datasources/local/app_database.dart';

/// الوصول للنسخة المحلية من قائمة الحظر الوطنية
class BlocklistDao {
  BlocklistDao(this._database);

  final AppDatabase _database;

  String get _table => DbConstants.tableBlocklist;

  /// استبدال كامل بمزامنة جديدة (القائمة تُدار مركزياً)
  Future<void> replaceAll(List<Map<String, Object?>> rows) async {
    final db = _database.db;
    final batch = db.batch();
    batch.delete(_table);
    for (final row in rows) {
      batch.insert(_table, row, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  /// فحص المرسل بالهاش أو الرقم — يُعيد الصف عند التطابق
  Future<Map<String, Object?>?> findByHashOrPhone({
    required String senderHash,
    required String? phone,
  }) async {
    final db = _database.db;

    if (senderHash.isNotEmpty) {
      final rows = await db.query(
        _table,
        where: 'sender_hash = ?',
        whereArgs: [senderHash],
        limit: 1,
      );
      if (rows.isNotEmpty) return rows.first;
    }

    if (phone != null && phone.isNotEmpty) {
      final rows = await db.query(
        _table,
        where: 'phone_number = ?',
        whereArgs: [phone],
        limit: 1,
      );
      if (rows.isNotEmpty) return rows.first;
    }

    return null;
  }

  Future<int> count() async {
    final result = await _database.db.rawQuery(
      'SELECT COUNT(*) AS c FROM $_table',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}

/// الوصول للنسخة المحلية من قائمة الحظر الشخصية
class PersonalBlocklistDao {
  PersonalBlocklistDao(this._database);

  final AppDatabase _database;

  String get _table => DbConstants.tablePersonalBlocklist;

  /// كل السجلات (الأحدث أولاً) — من الجهاز فقط
  Future<List<Map<String, Object?>>> getAll() async =>
      _database.db.query(_table, orderBy: 'added_at DESC');

  Future<void> insert(Map<String, Object?> row) async =>
      _database.db.insert(_table, row, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<int> delete(String id) async =>
      _database.db.delete(_table, where: 'id = ?', whereArgs: [id]);

  Future<Map<String, Object?>?> findByHashOrPhone({
    required String senderHash,
    required String? phone,
  }) async {
    final db = _database.db;

    if (senderHash.isNotEmpty) {
      final rows = await db.query(
        _table,
        where: 'sender_hash = ?',
        whereArgs: [senderHash],
        limit: 1,
      );
      if (rows.isNotEmpty) return rows.first;
    }

    if (phone != null && phone.isNotEmpty) {
      final rows = await db.query(
        _table,
        where: 'phone_number = ?',
        whereArgs: [phone],
        limit: 1,
      );
      if (rows.isNotEmpty) return rows.first;
    }

    return null;
  }
}
