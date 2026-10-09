import 'dart:convert';

import 'package:napex_victim_app/core/constants/db_constants.dart';
import 'package:napex_victim_app/data/datasources/local/app_database.dart';

/// سجل التدقيق — توثيق كل إجراء على الأدلة (سلسلة الحفظ)
class AuditDao {
  AuditDao(this._database);

  final AppDatabase _database;

  String get _table => DbConstants.tableAuditLogs;

  Future<void> log(
    String action,
    String entityType,
    String? entityId, {
    Map<String, dynamic>? details,
  }) async {
    await _database.db.insert(_table, {
      'action': action,
      'entity_type': entityType,
      'entity_id': entityId,
      'details': details == null ? null : jsonEncode(details),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    await _trim();
  }

  Future<List<Map<String, Object?>>> getByEntity(
    String entityType,
    String entityId,
  ) async {
    return _database.db.query(
      _table,
      where: 'entity_type = ? AND entity_id = ?',
      whereArgs: [entityType, entityId],
      orderBy: 'created_at ASC',
    );
  }

  /// أحدث السجلات — لشاشة سجل النشاط
  Future<List<Map<String, Object?>>> getRecent({int limit = 200}) async {
    return _database.db.query(
      _table,
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }

  /// إبقاء آخر [maxRows] سجل فقط
  Future<void> _trim() async {
    await _database.db.rawDelete('''
      DELETE FROM $_table WHERE id NOT IN (
        SELECT id FROM $_table ORDER BY created_at DESC LIMIT ?
      )
    ''', [DbConstants.maxAuditLogs]);
  }
}
