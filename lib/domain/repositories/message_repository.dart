import 'package:napex_victim_app/core/error/failures.dart';
import 'package:napex_victim_app/domain/entities/message.dart';

abstract interface class MessageRepository {
  /// حفظ رسالة مُجمَّعة (المحتوى يُخزَّن مشفراً)
  Future<(CollectedMessage?, Failure?)> saveMessage(CollectedMessage message);

  /// هل الرسالة محفوظة مسبقاً (منع التكرار)؟
  Future<bool> messageExists(String id);

  /// استرجاع رسالة
  Future<(CollectedMessage?, Failure?)> getMessageById(String id);

  /// آخر الرسائل
  Future<(List<CollectedMessage>, Failure?)> getRecentMessages({int limit = 100});

  /// بث مباشر للرسائل
  Stream<List<CollectedMessage>> watchMessages({int limit = 100});

  /// حذف رسالة
  Future<(bool, Failure?)> deleteMessage(String id);

  /// حذف الرسائل القديمة (سياسة الاحتفاظ) — يُعيد عدد المحذوفة
  Future<(int, Failure?)> deleteOldMessages({required Duration olderThan});
}
