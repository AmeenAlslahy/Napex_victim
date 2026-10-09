import 'dart:convert';

import 'package:napex_victim_app/core/constants/db_constants.dart';
import 'package:napex_victim_app/core/error/error_handler.dart';
import 'package:napex_victim_app/core/error/failures.dart';
import 'package:napex_victim_app/core/network/network_info.dart';
import 'package:napex_victim_app/core/security/encryption_service.dart';
import 'package:napex_victim_app/core/security/hash_service.dart';
import 'package:napex_victim_app/core/utils/logger.dart';
import 'package:napex_victim_app/data/datasources/local/app_database.dart';
import 'package:napex_victim_app/data/datasources/local/daos/audit_dao.dart';
import 'package:napex_victim_app/data/datasources/local/daos/evidence_dao.dart';
import 'package:napex_victim_app/data/datasources/local/daos/report_dao.dart';
import 'package:napex_victim_app/data/datasources/remote/api/report_api.dart';
import 'package:napex_victim_app/data/mappers/report_mapper.dart';
import 'package:napex_victim_app/data/models/report_model.dart';
import 'package:napex_victim_app/domain/entities/report.dart';
import 'package:napex_victim_app/domain/repositories/report_repository.dart';

/// تنفيذ مستودع البلاغات — Offline-first:
/// يُحفظ كل بلاغ محلياً مشفراً، ويُحاول الإرسال، وعند الفشل يبقى في قائمة المزامنة
class ReportRepositoryImpl implements ReportRepository {
  ReportRepositoryImpl({
    required AppDatabase database,
    required ReportDao reportDao,
    required EvidenceDao evidenceDao,
    required AuditDao auditDao,
    required ReportApi api,
    required EncryptionService encryptionService,
    required HashService hashService,
    required NetworkInfo networkInfo,
  })  : _database = database,
        _reportDao = reportDao,
        _evidenceDao = evidenceDao,
        _auditDao = auditDao,
        _api = api,
        _encryption = encryptionService,
        _hashService = hashService,
        _networkInfo = networkInfo;

  final AppDatabase _database;
  final ReportDao _reportDao;
  final EvidenceDao _evidenceDao;
  final AuditDao _auditDao;
  final ReportApi _api;
  final EncryptionService _encryption;
  final HashService _hashService;
  final NetworkInfo _networkInfo;

  @override
  Future<(Report?, Failure?)> saveReport(Report report) async {
    try {
      final encrypted = await _encryption.encryptString(report.content);
      final row = ReportMapper.toRow(
        report,
        jsonEncode(encrypted.toJson()),
        _hashService.sha256(report.content),
      );
      await _reportDao.upsert(row);
      await _auditDao.log('report_created', 'report', report.id);
      return (report, null);
    } catch (e) {
      AppLogger.error('saveReport failed', tag: 'ReportRepo', error: e);
      return (null, ErrorHandler.mapExceptionToFailure(e));
    }
  }

  @override
  Future<(String?, Failure?)> submitReport(Report report) async {
    if (!await _networkInfo.isConnected) {
      return (null, const NoInternetFailure());
    }

    try {
      final body = ReportModel.fromEntity(report).toJson();
      final data = await _api.submit(body);

      final reportNumber = (data['report_number'] ?? data['id'])?.toString();
      await _reportDao.updateStatus(
        report.id,
        ReportStatus.submitted.value,
        syncedAt: DateTime.now(),
        reportNumber: reportNumber,
      );
      await _auditDao.log('report_submitted', 'report', report.id);
      return (reportNumber, null);
    } catch (e) {
      final failure = ErrorHandler.mapExceptionToFailure(e);
      await _reportDao.incrementRetry(report.id, failure.message);
      return (null, failure);
    }
  }

  @override
  Future<(Report?, Failure?)> getReportById(String id) async {
    try {
      final row = await _reportDao.getById(id);
      if (row == null) {
        return (null, NotFoundFailure(message: 'البلاغ غير موجود'));
      }
      return (await _decryptRow(row), null);
    } catch (e) {
      return (null, ErrorHandler.mapExceptionToFailure(e));
    }
  }

  @override
  Stream<List<Report>> watchReports() =>
      _database.watch(DbConstants.tableReports, _fetchAllDecrypted);

  @override
  Future<(List<Report>, Failure?)> getPendingReports() async {
    try {
      final rows = await _reportDao.getPending();
      final reports = <Report>[];
      for (final row in rows) {
        reports.add(await _decryptRow(row));
      }
      return (reports, null);
    } catch (e) {
      return (<Report>[], ErrorHandler.mapExceptionToFailure(e));
    }
  }

  @override
  Future<(int, Failure?)> syncReports() async {
    if (!await _networkInfo.isConnected) {
      return (0, const NoInternetFailure());
    }

    final (pending, failure) = await getPendingReports();
    if (failure != null) return (0, failure);

    var synced = 0;
    for (final report in pending.where((r) => r.status.needsSubmission)) {
      final (number, submitFailure) = await submitReport(report);
      if (submitFailure == null) synced++;
      AppLogger.info(
        'Sync report ${report.localId} → ${number ?? submitFailure?.message}',
        tag: 'Sync',
      );
    }
    return (synced, null);
  }

  @override
  Future<(bool, Failure?)> deleteReport(String id) async {
    try {
      await _evidenceDao.deleteByReport(id);
      await _reportDao.delete(id);
      await _auditDao.log('report_deleted', 'report', id);
      return (true, null);
    } catch (e) {
      return (false, ErrorHandler.mapExceptionToFailure(e));
    }
  }

  @override
  Future<(bool, Failure?)> deleteAllReports() async {
    try {
      final rows = await _reportDao.getAll();
      for (final row in rows) {
        await _evidenceDao.deleteByReport(row['id'] as String? ?? '');
      }
      await _reportDao.deleteAll();
      return (true, null);
    } catch (e) {
      return (false, ErrorHandler.mapExceptionToFailure(e));
    }
  }

  @override
  Future<int> getReportCount() => _reportDao.count();

  @override
  Future<Map<ReportStatus, int>> getCountsByStatus() async {
    final counts = await _reportDao.countsByStatus();
    return {
      for (final entry in counts.entries)
        ReportStatus.fromValue(entry.key): entry.value,
    };
  }

  // ============ Helpers ============

  Future<Report> _decryptRow(Map<String, Object?> row) async {
    final content = await _decryptContent(
      row['content_encrypted'] as String? ?? '',
    );
    return ReportMapper.fromRow(ReportRowData(row: row, content: content));
  }

  Future<String> _decryptContent(String encryptedJson) async {
    if (encryptedJson.isEmpty) return '';
    try {
      final payload = EncryptedPayload.fromJson(
        jsonDecode(encryptedJson) as Map<String, dynamic>,
      );
      return await _encryption.decryptString(payload);
    } catch (_) {
      return '';
    }
  }

  Future<List<Report>> _fetchAllDecrypted() async {
    final rows = await _reportDao.getAll();
    final reports = <Report>[];
    for (final row in rows) {
      reports.add(await _decryptRow(row));
    }
    return reports;
  }
}
