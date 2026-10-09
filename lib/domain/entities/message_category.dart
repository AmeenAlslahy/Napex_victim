import 'package:equatable/equatable.dart';

/// تصنيفات الرسائل — مرتبة حسب الخطورة
enum MessageCategory {
  normal('normal', 'عادي', 0),
  spam('spam', 'إعلانات', 1),
  suspicious('suspicious', 'مشبوه', 2),
  threat('threat', 'تهديد', 3),
  extortion('extortion', 'ابتزاز', 4),
  harmful('harmful', 'محتوى ضار', 5);

  const MessageCategory(this.value, this.labelAr, this.severity);

  final String value;
  final String labelAr;
  final int severity;

  static MessageCategory fromValue(String value) {
    return MessageCategory.values.firstWhere(
      (c) => c.value == value,
      orElse: () => MessageCategory.normal,
    );
  }

  bool get isDangerous => severity >= 3;
  bool get requiresAction => severity >= 4;
}

/// تصنيف موسّع قابل للربط ببيانات إضافية (للاستخدام المستقبلي في ML)
class MessageCategoryInfo extends Equatable {
  const MessageCategoryInfo({required this.category, this.description});

  final MessageCategory category;
  final String? description;

  @override
  List<Object?> get props => [category, description];
}
