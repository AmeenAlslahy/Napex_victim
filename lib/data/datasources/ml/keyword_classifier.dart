import 'package:napex_victim_app/core/utils/arabic_normalizer.dart';
import 'package:napex_victim_app/core/utils/logger.dart';
import 'package:napex_victim_app/domain/entities/analysis_result.dart';
import 'package:napex_victim_app/domain/entities/message_category.dart';
import 'package:napex_victim_app/domain/entities/risk_level.dart';

/// تعريف فئة الكلمات المفتاحية
class KeywordRule {
  const KeywordRule({required this.phrase, required this.weight});

  final String phrase; // مخزنة مُطبَّعة
  final double weight;
}

/// تعريف فئة تصنيف
class CategoryRule {
  const CategoryRule({
    required this.name,
    required this.defaultWeight,
    required this.keywords,
  });

  final String name;
  final double defaultWeight;
  final List<KeywordRule> keywords;
}

/// محرك التصنيف القائم على القواعد اللغوية العربية
/// - يحمل قواعد الكلمات من JSON (assets أو من الخادم)
/// - يطبّع النص العربي ثم يجمع أوزان الكلمات المتطابقة
/// - يحوّل المجموع إلى ثقة باستخدام منحنى 1 - e^(-S/k)
/// هيكل قابل للاستبدال لاحقاً بمحرك TFLite عبر MLRepository نفسه
class KeywordClassifier {
  KeywordClassifier();

  bool _loaded = false;
  final Map<String, CategoryRule> _categories = {};
  final Map<String, List<String>> _recommendations = {};
  double _kFactor = 6.0;

  bool get isLoaded => _loaded;

  /// تحميل القواعد من خريطة JSON (بنية assets/config/keywords_ar.json)
  void loadFromMap(Map<String, dynamic> json) {
    _categories.clear();
    _recommendations.clear();

    _kFactor = (json['k_factor'] as num? ?? 6.0).toDouble();

    final categories = json['categories'] as Map<String, dynamic>? ?? {};
    categories.forEach((name, raw) {
      final catMap = raw as Map<String, dynamic>;
      final keywords = <KeywordRule>[];

      final rules = catMap['keywords'] as List<dynamic>? ?? [];
      for (final rule in rules) {
        if (rule is Map<String, dynamic>) {
          keywords.add(
            KeywordRule(
              phrase: ArabicNormalizer.normalize(rule['phrase'] as String),
              weight: (rule['weight'] as num? ?? 1.0).toDouble(),
            ),
          );
        } else if (rule is String) {
          keywords.add(
            KeywordRule(
              phrase: ArabicNormalizer.normalize(rule),
              weight: (catMap['default_weight'] as num? ?? 1.0).toDouble(),
            ),
          );
        }
      }

      _categories[name] = CategoryRule(
        name: name,
        defaultWeight: (catMap['default_weight'] as num? ?? 1.0).toDouble(),
        keywords: keywords,
      );
    });

    final recs = json['recommendations'] as Map<String, dynamic>? ?? {};
    recs.forEach((key, value) {
      _recommendations[key] =
          (value as List<dynamic>).cast<String>().toList();
    });

    _loaded = true;
    AppLogger.info(
      'Loaded classifier: ${_categories.length} categories',
      tag: 'ML',
    );
  }

  /// تصنيف نص وتحويله إلى AnalysisResult
  AnalysisResult classify(String text) {
    final sw = Stopwatch()..start();

    if (!_loaded || text.trim().isEmpty) {
      return AnalysisResult.normal;
    }

    final normalized = ArabicNormalizer.normalize(text);
    if (normalized.isEmpty) return AnalysisResult.normal;

    final scores = <String, double>{};
    final matched = <String>[];

    _categories.forEach((name, category) {
      var score = 0.0;
      for (final rule in category.keywords) {
        if (rule.phrase.isEmpty) continue;
        if (normalized.contains(rule.phrase)) {
          score += rule.weight;
          matched.add(rule.phrase);
        }
      }
      if (score > 0) scores[name] = score;
    });

    sw.stop();

    // لا تطابق إطلاقاً → عادي
    if (scores.isEmpty) {
      return AnalysisResult(
        category: MessageCategory.normal,
        confidence: 0.95,
        riskLevel: RiskLevel.none,
        isExtortion: false,
        analysisEngine: 'keyword-v1',
        processingTimeMs: sw.elapsedMilliseconds,
      );
    }

    // الفئة الأعلى وزناً
    final best = scores.entries.reduce(
      (a, b) => a.value >= b.value ? a : b,
    );

    // ثقة عبر منحنى أُسي سالب: S=6 → 0.63 ، S=12 → 0.86 ، S=18 → 0.95
    final confidence = 1 - _exp(-best.value / _kFactor);

    final category = _mapCategory(best.key);
    final riskLevel = RiskLevel.fromScore(confidence);
    // فئة التهديد الصريح بثقة تجاوز عتبة الحساسية المتوسطة = ابتزاز مؤكد
    // (القديمة 0.95 كانت تتطلب S≈18 — عملياً لا يُبلغ أي تهديد أبداً)
    final isExtortion = category == MessageCategory.extortion ||
        category == MessageCategory.threat && confidence >= 0.85;

    return AnalysisResult(
      category: category,
      confidence: confidence,
      riskLevel: riskLevel,
      isExtortion: isExtortion,
      probabilities: scores
          .map((k, v) => MapEntry(k, 1 - _exp(-v / _kFactor))),
      keywords: matched,
      threatPhrases: matched.take(5).toList(),
      recommendations: _recommendations[best.key] ?? const [],
      analysisEngine: 'keyword-v1',
      processingTimeMs: sw.elapsedMilliseconds,
    );
  }

  static MessageCategory _mapCategory(String name) {
    return MessageCategory.values.firstWhere(
      (c) => c.value == name,
      orElse: () => MessageCategory.suspicious,
    );
  }

  static double _exp(double x) {
    // منحنى أسي سالب باستخدام دوال dart الأساسية
    final result = _expSeries(-x);
    return result;
  }

  /// e^(-x) عبر متسلسلة مقاربة سريعة وثابتة
  static double _expSeries(double x) {
    // x هنا موجب دائماً (S/k) — نستخدم التقريب القياسي
    if (x < 0) return 1;
    if (x > 20) return 0; // تجنب تجاوز الدقة
    var term = 1.0;
    var sum = 1.0;
    for (var i = 1; i < 12; i++) {
      term *= x / i;
      sum += term;
    }
    return 1 / sum; // e^(-x)
  }
}
