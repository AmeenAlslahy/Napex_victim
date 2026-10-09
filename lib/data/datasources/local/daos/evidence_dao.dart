import 'package:sqflite/sqflite.dart';

import 'package:napex_victim_app/core/constants/db_constants.dart';
import 'package:napex_victim_app/data/datasources/local/app_database.dart';

/// الوصول لجدول الأدلة الرقمية
class EvidenceDao {
  EvidenceDao(this._database);

  final AppDatabase _database;

  String get _table => DbConstants.tableEvidences;

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
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, Object?>>> getByReport(String reportId) async {
    return _database.db.query(
      _table,
      where: 'report_id = ?',
      whereArgs: [reportId],
      orderBy: 'collected_at ASC',
    );
  }

  Future<void> updateStatus(String id, String status) async {
    await _database.db.update(
      _table,
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
    _database.notifyChange(_table);
  }

  Future<void> markUploaded(String id, String remoteUrl) async {
    await _database.db.update(
      _table,
      {
        'status': 'uploaded',
        'remote_url': remoteUrl,
        'uploaded_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    _database.notifyChange(_table);
  }

  Future<int> delete(String id) async {
    final count = await _database.db
        .delete(_table, where: 'id = ?', whereArgs: [id]);
    _database.notifyChange(_table);
    return count;
  }

  Future<int> deleteByReport(String reportId) async {
    final count = await _database.db.delete(
      _table,
      where: 'report_id = ?',
      whereArgs: [reportId],
    );
    _database.notifyChange(_table);
    return count;
  }

  Future<int> count() async {
    final result = await _database.db.rawQuery(
      'SELECT COUNT(*) AS c FROM $_table',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
