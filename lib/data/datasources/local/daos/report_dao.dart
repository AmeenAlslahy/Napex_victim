import 'package:sqflite/sqflite.dart';

import 'package:napex_victim_app/core/constants/db_constants.dart';
import 'package:napex_victim_app/data/datasources/local/app_database.dart';

/// الوصول لجدول البلاغات
class ReportDao {
  ReportDao(this._database);

  final AppDatabase _database;

  String get _table => DbConstants.tableReports;

  Future<void> upsert(Map<String, Object?> row) async {
    await _database.db.insert(
      _table,
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _database.notifyChange(_table);
  }

  Future<Map<String, Object?>?> getById(String id) async {
    final rows = await _database.db.query(
      _table,
      where: 'id = ? OR local_id = ?',
      whereArgs: [id, id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, Object?>>> getAll() async {
    return _database.db.query(_table, orderBy: 'created_at DESC');
  }

  Stream<List<Map<String, Object?>>> watchAll() =>
      _database.watch(_table, getAll);

  Future<List<Map<String, Object?>>> getPending() async {
    return _database.db.query(
      _table,
      where: "status IN ('draft', 'pending', 'failed')",
      orderBy: 'created_at ASC',
    );
  }

  Future<void> updateStatus(
    String id,
    String status, {
    DateTime? syncedAt,
    String? reportNumber,
    String? lastError,
  }) async {
    final updates = <String, Object?>{
      'status': status,
      if (syncedAt != null) 'synced_at': syncedAt.millisecondsSinceEpoch,
      if (reportNumber != null) 'report_number': reportNumber,
      if (lastError != null) 'last_error': lastError,
    };
    await _database.db.update(
      _table,
      updates,
      where: 'id = ? OR local_id = ?',
      whereArgs: [id, id],
    );
    _database.notifyChange(_table);
  }

  Future<void> incrementRetry(String id, String error) async {
    await _database.db.rawUpdate(
      'UPDATE $_table SET retry_count = retry_count + 1, '
      "last_error = ?, status = 'failed' WHERE id = ? OR local_id = ?",
      [error, id, id],
    );
    _database.notifyChange(_table);
  }

  Future<int> delete(String id) async {
    final count = await _database.db
        .delete(_table, where: 'id = ? OR local_id = ?', whereArgs: [id, id]);
    _database.notifyChange(_table);
    return count;
  }

  Future<int> deleteAll() async {
    final count = await _database.db.delete(_table);
    _database.notifyChange(_table);
    return count;
  }

  Future<int> count() async {
    final result = await _database.db.rawQuery(
      'SELECT COUNT(*) AS c FROM $_table',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// عدد البلاغات حسب الحالة
  Future<Map<String, int>> countsByStatus() async {
    final rows = await _database.db.rawQuery(
      'SELECT status, COUNT(*) AS c FROM $_table GROUP BY status',
    );
    return {
      for (final row in rows)
        row['status'] as String? ?? 'unknown': Sqflite.firstIntValue([row]) ?? 0,
    };
  }
}
