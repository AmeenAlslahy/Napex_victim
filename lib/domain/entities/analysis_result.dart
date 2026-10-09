import 'package:equatable/equatable.dart';

import 'package:napex_victim_app/domain/entities/message_category.dart';
import 'package:napex_victim_app/domain/entities/risk_level.dart';

/// نتيجة تحليل الرسالة
class AnalysisResult extends Equatable {
  const AnalysisResult({
    required this.category,
    required this.confidence,
    required this.riskLevel,
    required this.isExtortion,
    this.probabilities = const {},
    this.keywords = const [],
    this.threatPhrases = const [],
    this.recommendations = const [],
    this.analysisEngine = 'keyword-v1',
    this.processingTimeMs = 0,
  });

  final MessageCategory category;
  final double confidence;
  final RiskLevel riskLevel;
  final bool isExtortion;
  final Map<String, double> probabilities;
  final List<String> keywords;
  final List<String> threatPhrases;
  final List<String> recommendations;
  final String analysisEngine;
  final int processingTimeMs;

  /// النتيجة الافتراضية (عادي)
  static const AnalysisResult normal = AnalysisResult(
    category: MessageCategory.normal,
    confidence: 1.0,
    riskLevel: RiskLevel.none,
    isExtortion: false,
  );

  /// هل تحتاج إلى إبلاغ فوري؟
  bool get requiresImmediateReport =>
      isExtortion && confidence >= 0.85;

  /// هل تحتاج إلى إشعار المستخدم؟
  bool get requiresNotification => riskLevel.level >= 2;

  /// هل تحتاج إلى حفظ كدليل؟
  bool get requiresEvidenceStorage => riskLevel.level >= 3;

  AnalysisResult copyWith({
    MessageCategory? category,
    double? confidence,
    RiskLevel? riskLevel,
    bool? isExtortion,
    Map<String, double>? probabilities,
    List<String>? keywords,
    List<String>? threatPhrases,
    List<String>? recommendations,
    String? analysisEngine,
    int? processingTimeMs,
  }) {
    return AnalysisResult(
      category: category ?? this.category,
      confidence: confidence ?? this.confidence,
      riskLevel: riskLevel ?? this.riskLevel,
      isExtortion: isExtortion ?? this.isExtortion,
      probabilities: probabilities ?? this.probabilities,
      keywords: keywords ?? this.keywords,
      threatPhrases: threatPhrases ?? this.threatPhrases,
      recommendations: recommendations ?? this.recommendations,
      analysisEngine: analysisEngine ?? this.analysisEngine,
      processingTimeMs: processingTimeMs ?? this.processingTimeMs,
    );
  }

  Map<String, dynamic> toJson() => {
        'category': category.value,
        'confidence': confidence,
        'risk_level': riskLevel.value,
        'is_extortion': isExtortion,
        'probabilities': probabilities,
        'keywords': keywords,
        'threat_phrases': threatPhrases,
        'recommendations': recommendations,
        'analysis_engine': analysisEngine,
        'processing_time_ms': processingTimeMs,
      };

  factory AnalysisResult.fromJson(Map<String, dynamic> json) =>
      AnalysisResult(
        category: MessageCategory.fromValue(json['category'] as String? ?? 'normal'),
        confidence: (json['confidence'] as num? ?? 0).toDouble(),
        riskLevel: RiskLevel.fromValue(json['risk_level'] as String? ?? 'none'),
        isExtortion: json['is_extortion'] as bool? ?? false,
        probabilities: (json['probabilities'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, (v as num).toDouble())),
        keywords: List<String>.from(json['keywords'] as List<dynamic>? ?? []),
        threatPhrases:
            List<String>.from(json['threat_phrases'] as List<dynamic>? ?? []),
        recommendations:
            List<String>.from(json['recommendations'] as List<dynamic>? ?? []),
        analysisEngine: json['analysis_engine'] as String? ?? 'keyword-v1',
        processingTimeMs: json['processing_time_ms'] as int? ?? 0,
      );

  @override
  List<Object?> get props => [
        category,
        confidence,
        riskLevel,
        isExtortion,
        keywords,
        threatPhrases,
      ];
}
