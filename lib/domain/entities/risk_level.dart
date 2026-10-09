/// مستويات الخطورة
enum RiskLevel {
  none('none', 'لا يوجد', 0, 0xFF4CAF50),
  low('low', 'منخفض', 1, 0xFF8BC34A),
  medium('medium', 'متوسط', 2, 0xFFFFC107),
  high('high', 'عالي', 3, 0xFFFF9800),
  critical('critical', 'حرج', 4, 0xFFF44336);

  const RiskLevel(this.value, this.labelAr, this.level, this.colorValue);

  final String value;
  final String labelAr;
  final int level;
  final int colorValue;

  static RiskLevel fromValue(String value) {
    return RiskLevel.values.firstWhere(
      (r) => r.value == value,
      orElse: () => RiskLevel.none,
    );
  }

  static RiskLevel fromScore(double score) {
    if (score >= 0.95) return RiskLevel.critical;
    if (score >= 0.85) return RiskLevel.high;
    if (score >= 0.60) return RiskLevel.medium;
    if (score >= 0.30) return RiskLevel.low;
    return RiskLevel.none;
  }
}
