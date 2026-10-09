import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:napex_victim_app/core/error/error_handler.dart';
import 'package:napex_victim_app/core/error/failures.dart';
import 'package:napex_victim_app/core/network/network_info.dart';
import 'package:napex_victim_app/core/security/encryption_service.dart';
import 'package:napex_victim_app/core/security/hash_service.dart';
import 'package:napex_victim_app/core/utils/logger.dart';
import 'package:napex_victim_app/data/datasources/local/daos/audit_dao.dart';
import 'package:napex_victim_app/data/datasources/local/daos/evidence_dao.dart';
import 'package:napex_victim_app/data/datasources/remote/api/evidence_api.dart';
import 'package:napex_victim_app/data/mappers/evidence_mapper.dart';
import 'package:napex_victim_app/domain/entities/evidence.dart';
import 'package:napex_victim_app/domain/entities/message.dart';
import 'package:napex_victim_app/domain/entities/report.dart';
import 'package:napex_victim_app/domain/repositories/evidence_repository.dart';

/// تنفيذ مستودع الأدلة — كل دليل يُشفَّر ويُجزَّأ ويُوثَّق في سلسلة الحفظ
class EvidenceRepositoryImpl implements EvidenceRepository {
  EvidenceRepositoryImpl({
    required EvidenceDao evidenceDao,
    required AuditDao auditDao,
    required EvidenceApi api,
    required EncryptionService encryptionService,
    required HashService hashService,
    required NetworkInfo networkInfo,
  })  : _evidenceDao = evidenceDao,
        _auditDao = auditDao,
        _api = api,
        _encryption = encryptionService,
        _hashService = hashService,
        _networkInfo = networkInfo;

  final EvidenceDao _evidenceDao;
  final AuditDao _auditDao;
  final EvidenceApi _api;
  final EncryptionService _encryption;
  final HashService _hashService;
  final NetworkInfo _networkInfo;
  final Uuid _uuid = const Uuid();

  @override
  Future<(Evidence?, Failure?)> createTextEvidence({
    required Report report,
  }) async {
    try {
      // 1. بناء مستند الدليل
      final document = {
        'report_id': report.localId,
        'content': report.content,
        'sender': report.sender.raw,
        'source_app': report.source.app.nativePackage,
        'analysis': report.analysis.toJson(),
        'message_timestamp': report.messageTimestamp.toIso8601String(),
        'collected_at': DateTime.now().toIso8601String(),
      };
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode(document)));
      final fileHash = _hashService.sha256Bytes(bytes);

      // 2. تشفير المحتوى وكتابته كـ JSON {ct, iv, mac}
      final encrypted = await _encryption.encryptBytes(bytes);
      final encryptedJson = utf8.encode(
        jsonEncode({
          'ct': base64.encode(encrypted.bytes),
          'iv': base64.encode(encrypted.iv),
          'mac': encrypted.mac,
        }),
      );

      final dir = await _evidenceDirectory();
      final id = _uuid.v4();
      final file = File(p.join(dir.path, '$id.enc'));
      await file.writeAsBytes(encryptedJson, flush: true);

      // 3. بناء الدليل مع سلسلة الحفظ
      final evidence = Evidence(
        id: id,
        reportId: report.localId,
        filePath: file.path,
        fileHash: fileHash,
        fileSize: bytes.length,
        mediaType: MediaType.text,
        mimeType: 'application/json',
        collectedAt: DateTime.now(),
        status: EvidenceStatus.encrypted,
        encryptedPath: file.path,
        chainOfCustody: [
          CustodyEntry(
            timestamp: DateTime.now(),
            action: 'collected_and_encrypted',
            performedBy: 'device',
            notes: 'SHA-256: ${fileHash.substring(0, 16)}…',
          ),
        ],
      );

      return await saveEvidence(evidence);
    } catch (e) {
      AppLogger.error('createTextEvidence failed', tag: 'Evidence', error: e);
      return (null, ErrorHandler.mapExceptionToFailure(e));
    }
  }

  @override
  Future<(Evidence?, Failure?)> saveEvidence(Evidence evidence) async {
    try {
      await _evidenceDao.upsert(EvidenceMapper.toRow(evidence));
      await _auditDao.log('evidence_saved', 'evidence', evidence.id);
      return (evidence, null);
    } catch (e) {
      return (null, ErrorHandler.mapExceptionToFailure(e));
    }
  }

  @override
  Future<(Evidence?, Failure?)> getEvidenceById(String id) async {
    try {
      final row = await _evidenceDao.getById(id);
      if (row == null) {
        return (null, NotFoundFailure(message: 'الدليل غير موجود'));
      }
      return (EvidenceMapper.fromRow(row), null);
    } catch (e) {
      return (null, ErrorHandler.mapExceptionToFailure(e));
    }
  }

  @override
  Future<(List<Evidence>, Failure?)> getEvidencesByReport(
    String reportId,
  ) async {
    try {
      final rows = await _evidenceDao.getByReport(reportId);
      final evidences = <Evidence>[];
      for (final row in rows) {
        evidences.add(EvidenceMapper.fromRow(row));
      }
      return (evidences, null);
    } catch (e) {
      return (<Evidence>[], ErrorHandler.mapExceptionToFailure(e));
    }
  }

  @override
  Future<(Evidence?, Failure?)> uploadEvidence(Evidence evidence) async {
    if (!await _networkInfo.isConnected) {
      return (null, const NoInternetFailure());
    }

    try {
      final file = File(evidence.encryptedPath ?? evidence.filePath);
      if (!await file.exists()) {
        return (null, NotFoundFailure(message: 'ملف الدليل غير موجود'));
      }

      final bytes = await file.readAsBytes();
      final response = await _api.upload(
        file: MultipartFile.fromBytes(
          bytes,
          filename: p.basename(file.path),
        ),
        reportId: evidence.reportId,
        fileHash: evidence.fileHash,
      );

      final remoteUrl = response['url']?.toString() ?? '';
      final updated = evidence.copyWith(
        status: EvidenceStatus.uploaded,
        uploadedAt: DateTime.now(),
        remoteUrl: remoteUrl.isEmpty ? null : remoteUrl,
      );
      await _evidenceDao.markUploaded(evidence.id, remoteUrl);
      await _auditDao.log('evidence_uploaded', 'evidence', evidence.id);
      return (updated, null);
    } catch (e) {
      return (null, ErrorHandler.mapExceptionToFailure(e));
    }
  }

  @override
  Future<(bool, Failure?)> verifyEvidenceIntegrity(String evidenceId) async {
    try {
      final row = await _evidenceDao.getById(evidenceId);
      if (row == null) {
        return (false, NotFoundFailure(message: 'الدليل غير موجود'));
      }

      final evidence = EvidenceMapper.fromRow(row);
      final file = File(evidence.encryptedPath ?? evidence.filePath);
      if (!await file.exists()) return (false, null);

      // فك التشفير ثم مطابقة الهاش
      final encryptedJson = jsonDecode(await file.readAsString())
          as Map<String, dynamic>;
      final decrypted = await _encryption.decryptString(
        EncryptedPayload.fromJson(encryptedJson),
      );
      final recomputedHash =
          _hashService.sha256Bytes(utf8.encode(decrypted));

      final intact = recomputedHash == evidence.fileHash;
      if (intact) {
        await _evidenceDao.updateStatus(
          evidenceId,
          EvidenceStatus.verified.value,
        );
      } else {
        await _auditDao.log('evidence_tampered', 'evidence', evidenceId);
      }
      return (intact, null);
    } catch (e) {
      return (false, ErrorHandler.mapExceptionToFailure(e));
    }
  }

  @override
  Future<(bool, Failure?)> deleteEvidence(String id) async {
    try {
      final row = await _evidenceDao.getById(id);
      if (row != null) {
        final evidence = EvidenceMapper.fromRow(row);
        final file = File(evidence.encryptedPath ?? evidence.filePath);
        if (await file.exists()) await file.delete();
      }
      await _evidenceDao.delete(id);
      return (true, null);
    } catch (e) {
      return (false, ErrorHandler.mapExceptionToFailure(e));
    }
  }

  @override
  Future<int> getEvidenceCount() => _evidenceDao.count();

  Future<Directory> _evidenceDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'evidence'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
}
