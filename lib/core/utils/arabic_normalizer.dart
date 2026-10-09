/// أداة تطبيع النص العربي — تُستخدم قبل التحليل لضمان تطابق الكلمات
abstract final class ArabicNormalizer {
  /// التشكيل والحروف الزائدة
  static final RegExp _diacritics = RegExp('[\u064B-\u065F\u0670]');
  static final RegExp _tatweel = RegExp('\u0640');
  static final RegExp _whitespace = RegExp(r'\s+');

  /// الأرقام العربية الهندية
  static final RegExp _arabicDigits = RegExp('[\u0660-\u0669]');
  static final RegExp _persianDigits = RegExp('[\u06F0-\u06F9]');

  /// تطبيع النص:
  /// - إزالة التشكيل والتطويل
  /// - توحيد الألف (أ إ آ ٱ → ا)
  /// - توحيد الياء والألف المقصورة (ى → ي)
  /// - توحيد التاء المربوطة (ة → ه)
  /// - توحيد الهمزات (ؤ → و ، ئ → ي)
  /// - تحويل الأرقام العربية إلى لاتينية
  /// - توحيد المسافات وتحويل لحروف صغيرة
  static String normalize(String input) {
    if (input.isEmpty) return input;

    var text = input;

    // إزالة التشكيل والتطويل
    text = text.replaceAll(_diacritics, '');
    text = text.replaceAll(_tatweel, '');

    // توحيد الحروف
    text = text
        .replaceAll('\u0623', '\u0627') // أ -> ا
        .replaceAll('\u0625', '\u0627') // إ -> ا
        .replaceAll('\u0622', '\u0627') // آ -> ا
        .replaceAll('\u0671', '\u0627') // ٱ -> ا
        .replaceAll('\u0649', '\u064A') // ى -> ي
        .replaceAll('\u0629', '\u0647') // ة -> ه
        .replaceAll('\u0624', '\u0648') // ؤ -> و
        .replaceAll('\u0626', '\u064A'); // ئ -> ي

    // الأرقام
    text = text.replaceAllMapped(_arabicDigits, (m) {
      return String.fromCharCode(m[0]!.codeUnitAt(0) - 0x0660 + 0x30);
    });
    text = text.replaceAllMapped(_persianDigits, (m) {
      return String.fromCharCode(m[0]!.codeUnitAt(0) - 0x06F0 + 0x30);
    });

    // المسافات والحالة
    text = text.replaceAll(_whitespace, ' ').trim().toLowerCase();

    return text;
  }
}
