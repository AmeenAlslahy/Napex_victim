import 'dart:convert';

import 'package:napex_victim_app/core/constants/db_constants.dart';
import 'package:napex_victim_app/core/error/error_handler.dart';
import 'package:napex_victim_app/core/error/failures.dart';
import 'package:napex_victim_app/core/security/encryption_service.dart';
import 'package:napex_victim_app/core/security/hash_service.dart';
import 'package:napex_victim_app/data/datasources/local/app_database.dart';
import 'package:napex_victim_app/data/datasources/local/daos/audit_dao.dart';
import 'package:napex_victim_app/data/datasources/local/daos/message_dao.dart';
import 'package:napex_victim_app/data/mappers/message_mapper.dart';
import 'package:napex_victim_app/domain/entities/message.dart';
import 'package:napex_victim_app/domain/repositories/message_repository.dart';

/// تنفيذ مستودع الرسائل — المحتوى يُخزَّن مشفراً دائماً
class MessageRepositoryImpl implements MessageRepository {
  MessageRepositoryImpl({
    required AppDatabase database,
    required MessageDao messageDao,
    required AuditDao auditDao,
    required EncryptionService encryptionService,
    required HashService hashService,
  })  : _database = database,
        _messageDao = messageDao,
        _auditDao = auditDao,
        _encryption = encryptionService,
        _hashService = hashService;

  final AppDatabase _database;
  final MessageDao _messageDao;
  final AuditDao _auditDao;
  final EncryptionService _encryption;
  final HashService _hashService;

  @override
  Future<(CollectedMessage?, Failure?)> saveMessage(
    CollectedMessage message,
  ) async {
    try {
      final encrypted = await _encryption.encryptString(message.content);
      final encryptedJson = jsonEncode(encrypted.toJson());
      final row = MessageMapper.toRow(message, encryptedJson);
      row['content_hash'] = _hashService.sha256(message.content);
      await _messageDao.upsert(row);
      await _auditDao.log('message_saved', 'message', message.id);
      return (message, null);
    } catch (e) {
      return (null, ErrorHandler.mapExceptionToFailure(e));
    }
  }

  @override
  Future<bool> messageExists(String id) => _messageDao.exists(id);

  @override
  Future<(CollectedMessage?, Failure?)> getMessageById(String id) async {
    try {
      final row = await _messageDao.getById(id);
      if (row == null) return (null, null);
      return (await _decryptRow(row), null);
    } catch (e) {
      return (null, ErrorHandler.mapExceptionToFailure(e));
    }
  }

  @override
  Future<(List<CollectedMessage>, Failure?)> getRecentMessages({
    int limit = 100,
  }) async {
    try {
      final rows = await _messageDao.getRecent(limit: limit);
      final messages = <CollectedMessage>[];
      for (final row in rows) {
        messages.add(await _decryptRow(row));
      }
      return (messages, null);
    } catch (e) {
      return (<CollectedMessage>[], ErrorHandler.mapExceptionToFailure(e));
    }
  }

  @override
  Stream<List<CollectedMessage>> watchMessages({int limit = 100}) =>
      _database.watch(
        DbConstants.tableMessages,
        () => _fetchRecentDecrypted(limit: limit),
      );

  @override
  Future<(bool, Failure?)> deleteMessage(String id) async {
    try {
      await _messageDao.delete(id);
      return (true, null);
    } catch (e) {
      return (false, ErrorHandler.mapExceptionToFailure(e));
    }
  }

  @override
  Future<(int, Failure?)> deleteOldMessages({
    required Duration olderThan,
  }) async {
    try {
      final cutoff = DateTime.now().subtract(olderThan);
      final count = await _messageDao.deleteOlderThan(cutoff);
      return (count, null);
    } catch (e) {
      return (0, ErrorHandler.mapExceptionToFailure(e));
    }
  }

  // ============ Helpers ============

  Future<CollectedMessage> _decryptRow(Map<String, Object?> row) async {
    var content = '';
    try {
      final payload = EncryptedPayload.fromJson(
        jsonDecode(row['content_encrypted'] as String? ?? '{}')
            as Map<String, dynamic>,
      );
      content = await _encryption.decryptString(payload);
    } catch (_) {
      content = '';
    }
    return MessageMapper.fromRow(MessageRowData(row: row, content: content));
  }

  Future<List<CollectedMessage>> _fetchRecentDecrypted({int limit = 100}) async {
    final rows = await _messageDao.getRecent(limit: limit);
    final messages = <CollectedMessage>[];
    for (final row in rows) {
      messages.add(await _decryptRow(row));
    }
    return messages;
  }
}
