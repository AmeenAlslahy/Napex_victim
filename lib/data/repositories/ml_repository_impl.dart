import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'package:napex_victim_app/core/constants/api_constants.dart';
import 'package:napex_victim_app/core/error/error_handler.dart';
import 'package:napex_victim_app/core/error/failures.dart';
import 'package:napex_victim_app/data/datasources/ml/keyword_classifier.dart';
import 'package:napex_victim_app/domain/entities/analysis_result.dart';
import 'package:napex_victim_app/domain/repositories/ml_repository.dart';

/// تنفيذ مستودع التحليل — محرك القواعد اللغوية (قابل للاستبدال بـ TFLite)
class MLRepositoryImpl implements MLRepository {
  MLRepositoryImpl({required KeywordClassifier classifier, required Dio dio})
      : _classifier = classifier,
        _dio = dio;

  final KeywordClassifier _classifier;
  final Dio _dio;

  static const String _assetPath = 'assets/config/keywords_ar.json';

  @override
  Future<(bool, Failure?)> loadModel() async {
    if (_classifier.isLoaded) return (true, null);
    try {
      final raw = await rootBundle.loadString(_assetPath);
      _classifier.loadFromMap(jsonDecode(raw) as Map<String, dynamic>);
      return (true, null);
    } catch (e) {
      return (false, MLModelFailure(message: 'فشل تحميل قواعد التحليل: $e'));
    }
  }

  @override
  Future<(AnalysisResult?, Failure?)> classifyText(String text) async {
    // تحميل تلقائي عند أول استخدام
    if (!_classifier.isLoaded) {
      final (loaded, failure) = await loadModel();
      if (!loaded) return (null, failure);
    }

    try {
      return (_classifier.classify(text), null);
    } catch (e) {
      return (null, MLInferenceFailure(message: 'فشل التحليل: $e'));
    }
  }

  @override
  Future<(AnalysisResult?, Failure?)> analyzeMessage({
    required String content,
    String? mediaPath,
    String? mediaType,
  }) async {
    // حالياً: تحليل النص. تحليل الوسائط (صور/صوت) يُضاف عند دمج TFLite.
    return classifyText(content);
  }

  @override
  Future<bool> isModelLoaded() async => _classifier.isLoaded;

  @override
  Future<(bool, Failure?)> updateRules() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiConstants.keywords,
      );
      final data = response.data;
      if (data == null) {
        return (false, const ServerFailure(message: 'استجابة فارغة'));
      }
      _classifier.loadFromMap(data);
      return (true, null);
    } catch (e) {
      return (false, ErrorHandler.mapExceptionToFailure(e));
    }
  }
}
