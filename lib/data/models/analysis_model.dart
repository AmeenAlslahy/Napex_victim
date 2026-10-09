import 'package:napex_victim_app/domain/entities/analysis_result.dart';
import 'package:napex_victim_app/domain/entities/message_category.dart';
import 'package:napex_victim_app/domain/entities/risk_level.dart';

/// DTO نتيجة التحليل للشبكة/التخزين
class AnalysisModel {
  const AnalysisModel({
    required this.category,
    required this.confidence,
    required this.riskLevel,
    required this.isExtortion,
    this.probabilities = const {},
    this.keywords = const [],
    this.threatPhrases = const [],
  });

  final String category;
  final double confidence;
  final String riskLevel;
  final bool isExtortion;
  final Map<String, double> probabilities;
  final List<String> keywords;
  final List<String> threatPhrases;

  factory AnalysisModel.fromEntity(AnalysisResult e) => AnalysisModel(
        category: e.category.value,
        confidence: e.confidence,
        riskLevel: e.riskLevel.value,
        isExtortion: e.isExtortion,
        probabilities: e.probabilities,
        keywords: e.keywords,
        threatPhrases: e.threatPhrases,
      );

  AnalysisResult toEntity() => AnalysisResult(
        category: MessageCategory.fromValue(category),
        confidence: confidence,
        riskLevel: RiskLevel.fromValue(riskLevel),
        isExtortion: isExtortion,
        probabilities: probabilities,
        keywords: keywords,
        threatPhrases: threatPhrases,
      );

  factory AnalysisModel.fromJson(Map<String, dynamic> json) => AnalysisModel(
        category: json['category'] as String? ?? 'normal',
        confidence: (json['confidence'] as num? ?? 0).toDouble(),
        riskLevel: json['risk_level'] as String? ?? 'none',
        isExtortion: json['is_extortion'] as bool? ?? false,
        probabilities: (json['probabilities'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, (v as num).toDouble())),
        keywords: List<String>.from(json['keywords'] as List<dynamic>? ?? []),
        threatPhrases:
            List<String>.from(json['threat_phrases'] as List<dynamic>? ?? []),
      );

  Map<String, dynamic> toJson() => {
        'category': category,
        'confidence': confidence,
        'risk_level': riskLevel,
        'is_extortion': isExtortion,
        'probabilities': probabilities,
        'keywords': keywords,
        'threat_phrases': threatPhrases,
      };
}
