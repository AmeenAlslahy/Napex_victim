/// ثوابت قاعدة البيانات
abstract final class DbConstants {
  static const String databaseName = 'napex_victim.db';
  static const int databaseVersion = 3;

  // Tables
  static const String tableReports = 'reports';
  static const String tableEvidences = 'evidences';
  static const String tableMessages = 'messages';
  static const String tableAuditLogs = 'audit_logs';
  static const String tableBlocklist = 'blocklist_entries';
  static const String tablePersonalBlocklist = 'personal_blocklist_entries';

  // Limits
  static const int maxCachedReports = 500;
  static const int maxAuditLogs = 5000;
  static const Duration reportRetentionPeriod = Duration(days: 90);
  static const Duration messageRetentionPeriod = Duration(days: 30);
}
