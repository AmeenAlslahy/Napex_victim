import 'package:napex_victim_app/core/error/failures.dart';
import 'package:napex_victim_app/domain/entities/evidence.dart';
import 'package:napex_victim_app/domain/entities/report.dart';

abstract interface class EvidenceRepository {
  /// إنشاء دليل نصي مشفر من بلاغ (ملف JSON مشفر + هاش)
  Future<(Evidence?, Failure?)> createTextEvidence({required Report report});

  /// حفظ دليل (كتابة الملف + التجزئة + التشفير)
  Future<(Evidence?, Failure?)> saveEvidence(Evidence evidence);

  /// استرجاع دليل
  Future<(Evidence?, Failure?)> getEvidenceById(String id);

  /// أدلة بلاغ معيّن
  Future<(List<Evidence>, Failure?)> getEvidencesByReport(String reportId);

  /// رفع دليل للخادم
  Future<(Evidence?, Failure?)> uploadEvidence(Evidence evidence);

  /// التحقق من سلامة الدليل (مطابقة الهاش)
  Future<(bool, Failure?)> verifyEvidenceIntegrity(String evidenceId);

  /// حذف دليل
  Future<(bool, Failure?)> deleteEvidence(String id);

  /// عدد الأدلة
  Future<int> getEvidenceCount();
}
