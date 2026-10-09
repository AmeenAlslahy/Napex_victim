import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'package:napex_victim_app/core/constants/db_constants.dart';

/// قاعدة البيانات المحلية (SQLite) — تُفتح مرة واحدة كـ Singleton
/// وتوفر بث التغييرات لتحديث الواجهة مباشرة
class AppDatabase {
  AppDatabase._(this._db);

  final Database _db;
  static AppDatabase? _instance;

  final StreamController<String> _changes =
      StreamController<String>.broadcast();

  Database get db => _db;

  Stream<String> get changes => _changes.stream;

  static Future<AppDatabase> getInstance() async {
    if (_instance != null) return _instance!;
    final docsDir = await getApplicationDocumentsDirectory();
    final path = p.join(docsDir.path, DbConstants.databaseName);
    final database = await openDatabase(
      path,
      version: DbConstants.databaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        // ملاحظة: PRAGMA journal_mode=WAL يُرجع صفاً من النتائج
        // ولا يمكن تنفيذه عبر execute أثناء الفتح في sqflite.
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    _instance = AppDatabase._(database);
    return _instance!;
  }

  /// بث استعلام مباشر — يُعيد الاستعلام عند كل تغيير في الجدول
  Stream<T> watch<T>(String table, Future<T> Function() query) {
    late StreamController<T> controller;
    StreamSubscription<String>? sub;

    Future<void> emit() async {
      if (controller.isClosed) return;
      controller.add(await query());
    }

    controller = StreamController<T>(
      onListen: () async {
        sub = _changes.stream.where((t) => t == table).listen((_) => emit());
        await emit();
      },
      onCancel: () => sub?.cancel(),
    );

    return controller.stream;
  }

  void notifyChange(String table) {
    if (!_changes.isClosed) _changes.add(table);
  }

  Future<void> close() async {
    await _changes.close();
    await _db.close();
    _instance = null;
  }

  static Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    // ============ الرسائل المُجمَّعة ============
    batch.execute('''
      CREATE TABLE ${DbConstants.tableMessages} (
        id TEXT PRIMARY KEY,
        sender_raw TEXT NOT NULL,
        sender_display TEXT NOT NULL,
        sender_phone TEXT,
        sender_hash TEXT,
        content_encrypted TEXT NOT NULL,
        content_hash TEXT NOT NULL,
        source_app TEXT NOT NULL,
        source_package TEXT NOT NULL,
        chat_name TEXT,
        media_type TEXT NOT NULL DEFAULT 'text',
        media_path TEXT,
        media_hash TEXT,
        media_size INTEGER,
        mime_type TEXT,
        analysis_json TEXT,
        timestamp INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        processed INTEGER NOT NULL DEFAULT 0
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_messages_timestamp ON ${DbConstants.tableMessages}(timestamp)',
    );
    batch.execute(
      'CREATE INDEX idx_messages_source ON ${DbConstants.tableMessages}(source_app)',
    );

    // ============ البلاغات ============
    batch.execute('''
      CREATE TABLE ${DbConstants.tableReports} (
        id TEXT PRIMARY KEY,
        local_id TEXT NOT NULL UNIQUE,
        report_number TEXT,
        sender_raw TEXT NOT NULL,
        sender_display TEXT NOT NULL,
        sender_phone TEXT,
        sender_hash TEXT,
        content_encrypted TEXT NOT NULL,
        content_hash TEXT NOT NULL,
        source_app TEXT NOT NULL,
        source_package TEXT NOT NULL,
        analysis_json TEXT NOT NULL,
        message_timestamp INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        synced_at INTEGER,
        status TEXT NOT NULL DEFAULT 'draft',
        retry_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_reports_status ON ${DbConstants.tableReports}(status)',
    );
    batch.execute(
      'CREATE INDEX idx_reports_created_at ON ${DbConstants.tableReports}(created_at)',
    );

    // ============ الأدلة الرقمية ============
    batch.execute('''
      CREATE TABLE ${DbConstants.tableEvidences} (
        id TEXT PRIMARY KEY,
        report_id TEXT NOT NULL,
        file_path TEXT NOT NULL,
        encrypted_path TEXT,
        file_hash TEXT NOT NULL,
        file_size INTEGER NOT NULL,
        media_type TEXT NOT NULL,
        mime_type TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'collected',
        collected_at INTEGER NOT NULL,
        uploaded_at INTEGER,
        remote_url TEXT,
        chain_of_custody TEXT NOT NULL DEFAULT '[]'
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_evidences_report ON ${DbConstants.tableEvidences}(report_id)',
    );

    // ============ سجل التدقيق ============
    batch.execute('''
      CREATE TABLE ${DbConstants.tableAuditLogs} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id TEXT,
        details TEXT,
        created_at INTEGER NOT NULL
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_audit_created ON ${DbConstants.tableAuditLogs}(created_at)',
    );

    // ============ قائمة الحظر الوطنية (نسخة مزامنة محلية) ============
    batch.execute('''
      CREATE TABLE ${DbConstants.tableBlocklist} (
        id TEXT PRIMARY KEY,
        sender_hash TEXT NOT NULL DEFAULT '',
        phone_number TEXT,
        display_name TEXT NOT NULL DEFAULT '',
        reason TEXT NOT NULL DEFAULT '',
        related_report_id TEXT,
        added_at INTEGER NOT NULL
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_blocklist_hash ON ${DbConstants.tableBlocklist}(sender_hash)',
    );

    // ============ قائمة الحظر الشخصية (نسخة مزامنة محلية) ============
    batch.execute('''
      CREATE TABLE ${DbConstants.tablePersonalBlocklist} (
        id TEXT PRIMARY KEY,
        sender_hash TEXT NOT NULL DEFAULT '',
        phone_number TEXT,
        display_name TEXT NOT NULL DEFAULT '',
        reason TEXT NOT NULL DEFAULT '',
        added_at INTEGER NOT NULL
      )
    ''');

    await batch.commit(noResult: true);
  }

  static Future<void> _onUpgrade(Database db, int from, int to) async {
    if (from < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${DbConstants.tableBlocklist} (
          id TEXT PRIMARY KEY,
          sender_hash TEXT NOT NULL DEFAULT '',
          phone_number TEXT,
          display_name TEXT NOT NULL DEFAULT '',
          reason TEXT NOT NULL DEFAULT '',
          related_report_id TEXT,
          added_at INTEGER NOT NULL
        )
      ''');
    }
    if (from < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${DbConstants.tablePersonalBlocklist} (
          id TEXT PRIMARY KEY,
          sender_hash TEXT NOT NULL DEFAULT '',
          phone_number TEXT,
          display_name TEXT NOT NULL DEFAULT '',
          reason TEXT NOT NULL DEFAULT '',
          added_at INTEGER NOT NULL
        )
      ''');
    }
  }
}
