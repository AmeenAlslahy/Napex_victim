import 'package:napex_victim_app/core/error/failures.dart';
import 'package:napex_victim_app/domain/entities/analysis_result.dart';

abstract interface class MLRepository {
  /// تهيئة محرك التحليل
  Future<(bool, Failure?)> loadModel();

  /// تحليل نص
  Future<(AnalysisResult?, Failure?)> classifyText(String text);

  /// تحليل شامل لرسالة (نص + وسائط)
  Future<(AnalysisResult?, Failure?)> analyzeMessage({
    required String content,
    String? mediaPath,
    String? mediaType,
  });

  /// هل المحرك جاهز؟
  Future<bool> isModelLoaded();

  /// تحديث قواعد الكلمات المفتاحية من الخادم
  Future<(bool, Failure?)> updateRules();
}
