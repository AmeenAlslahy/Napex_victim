import 'package:napex_victim_app/core/error/failures.dart';
import 'package:napex_victim_app/domain/entities/report.dart';

abstract interface class ReportRepository {
  /// حفظ بلاغ محلياً (المحتوى يُخزَّن مشفراً)
  Future<(Report?, Failure?)> saveReport(Report report);

  /// إرسال بلاغ للخادم — يُعيد رقم البلاغ الرسمي
  Future<(String?, Failure?)> submitReport(Report report);

  /// استرجاع بلاغ بواسطة ID المحلي
  Future<(Report?, Failure?)> getReportById(String id);

  /// بث مباشر لجميع البلاغات (يُحدَّث عند أي تغيير)
  Stream<List<Report>> watchReports();

  /// البلاغات المعلقة (تحتاج إرسال/مزامنة)
  Future<(List<Report>, Failure?)> getPendingReports();

  /// مزامنة جميع البلاغات المعلقة — يُعيد عدد المرسلة
  Future<(int, Failure?)> syncReports();

  /// حذف بلاغ
  Future<(bool, Failure?)> deleteReport(String id);

  /// حذف جميع البلاغات
  Future<(bool, Failure?)> deleteAllReports();

  /// عدد البلاغات
  Future<int> getReportCount();

  /// عدد البلاغات حسب الحالة
  Future<Map<ReportStatus, int>> getCountsByStatus();
}
