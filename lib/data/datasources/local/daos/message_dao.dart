import 'package:sqflite/sqflite.dart';

import 'package:napex_victim_app/core/constants/db_constants.dart';
import 'package:napex_victim_app/data/datasources/local/app_database.dart';

/// الوصول لجدول الرسائل
class MessageDao {
  MessageDao(this._database);

  final AppDatabase _database;

  String get _table => DbConstants.tableMessages;

  Future<void> upsert(Map<String, Object?> row) async {
    await _database.db.insert(
      _table,
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _database.notifyChange(_table);
  }

  Future<bool> exists(String id) async {
    final rows = await _database.db.query(
      _table,
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<Map<String, Object?>?> getById(String id) async {
    final rows = await _database.db.query(
      _table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, Object?>>> getRecent({int limit = 100}) async {
    return _database.db.query(
      _table,
      orderBy: 'timestamp DESC',
      limit: limit,
    );
  }

  Stream<List<Map<String, Object?>>> watchRecent({int limit = 100}) =>
      _database.watch(_table, () => getRecent(limit: limit));

  Future<int> delete(String id) async {
    final count = await _database.db
        .delete(_table, where: 'id = ?', whereArgs: [id]);
    _database.notifyChange(_table);
    return count;
  }

  Future<int> deleteOlderThan(DateTime cutoff) async {
    final count = await _database.db.delete(
      _table,
      where: 'timestamp < ?',
      whereArgs: [cutoff.millisecondsSinceEpoch],
    );
    if (count > 0) _database.notifyChange(_table);
    return count;
  }
}
