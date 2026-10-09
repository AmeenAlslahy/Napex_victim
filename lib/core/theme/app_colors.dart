import 'package:flutter/material.dart';

/// ألوان الهوية البصرية لمنصة NAP-EX
abstract final class AppColors {
  // ============ Primary ============
  static const Color primary = Color(0xFF0D3B66); // كحلي رسمي
  static const Color primaryLight = Color(0xFF1E5A96);
  static const Color primaryDark = Color(0xFF092A4A);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // ============ Secondary ============
  static const Color secondary = Color(0xFF1B998B); // أخضر أزرق
  static const Color secondaryLight = Color(0xFF3FB8AA);
  static const Color onSecondary = Color(0xFFFFFFFF);

  // ============ Semantic ============
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF4A259);
  static const Color danger = Color(0xFFD64545);
  static const Color critical = Color(0xFFB71C1C);
  static const Color info = Color(0xFF2196F3);

  // ============ Background / Surface ============
  static const Color background = Color(0xFFF5F7FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFE8EDF4);
  static const Color outline = Color(0xFFCBD5E1);

  // ============ Text ============
  static const Color textPrimary = Color(0xFF14213D);
  static const Color textSecondary = Color(0xFF5A6A85);
  static const Color textDisabled = Color(0xFF9AA7BC);

  /// لون مستوى الخطورة
  static Color riskColor(int level) => switch (level) {
        0 => success,
        1 => Color(0xFF8BC34A),
        2 => warning,
        3 => danger,
        _ => critical,
      };
}
