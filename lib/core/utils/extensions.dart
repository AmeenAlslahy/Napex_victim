import 'package:intl/intl.dart';

/// إضافات التاريخ
extension DateTimeX on DateTime {
  String get formattedDate => DateFormat('yyyy/MM/dd').format(this);

  String get formattedTime => DateFormat('HH:mm').format(this);

  String get formattedDateTime => DateFormat('yyyy/MM/dd • HH:mm').format(this);

  /// منذ كم من الوقت (نص عربي مختصر)
  String get timeAgoAr {
    final diff = DateTime.now().difference(this);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'قبل ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'قبل ${diff.inHours} ساعة';
    if (diff.inDays < 30) return 'قبل ${diff.inDays} يوم';
    return formattedDate;
  }
}

/// إضافات النصوص
extension StringX on String {
  /// إخفاء جزء من رقم الهاتف للخصوصية: +967771234567 -> +967***4567
  String get masked {
    if (length <= 6) return this;
    return '${substring(0, 4)}***${substring(length - 4)}';
  }

  /// هل النص رقم هاتف (أرقام و+ فقط، 7-15 خانة)؟
  bool get isPhoneNumber => RegExp(r'^\+?[0-9]{7,15}$').hasMatch(this);
}

/// إضافات الأرقام
extension DoubleX on double {
  /// نسبة مئوية بنص
  String get asPercent => '${(this * 100).toStringAsFixed(0)}%';
}
