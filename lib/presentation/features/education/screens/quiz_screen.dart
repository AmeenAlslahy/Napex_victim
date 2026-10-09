import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:napex_victim_app/core/theme/app_colors.dart';
import 'package:napex_victim_app/presentation/shared/widgets/napex_card.dart';
import 'package:napex_victim_app/presentation/shared/widgets/primary_button.dart';

/// سؤال في الاختبار التفاعلي
class QuizQuestion {
  const QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;
}

const List<QuizQuestion> _questions = [
  QuizQuestion(
    question: 'ما أفضل تصرف عند تلقي رسالة ابتزاز تطلب المال؟',
    options: [
      'الدفع فوراً لإنهاء الموضوع',
      'عدم الدفع وحفظ الأدلة والإبلاغ',
      'الرد بالتهديد للمبتز',
      'حذف الرسالة وتجاهلها',
    ],
    correctIndex: 1,
    explanation:
        'الدفع يفتح الباب لمطالب أكثر ولا يوقف الابتزاز، والحذف يضيع دليلك. '
        'الأدلة المحفوظة هي أقوى سلاحك.',
  ),
  QuizQuestion(
    question: 'من يتحمل المسؤولية القانونية في الابتزاز الإلكتروني؟',
    options: [
      'الضحية لأنها أرسلت الصور',
      'الطرفان بالتساوي',
      'المبتز وحده — الضحية طرف متضرر',
      'لا أحد — مسألة خاصة',
    ],
    correctIndex: 2,
    explanation:
        'المبتز هو المسؤول قانونياً وحده. أنت الضحية وليس لديك أي ذنب، '
        'والإبلاغ بحماية القانون.',
  ),
  QuizQuestion(
    question: 'ماذا تفعل إذا طلب منك شخص رمز التحقق (OTP)؟',
    options: [
      'أرسله لأنه ربما موظف دعم',
      'أرسله فقط إذا كان رقم معروف',
      'لا أرسله أبداً — لا يوجد جهة رسمية تطلبه',
      'أرسل نصف الرمز فقط',
    ],
    correctIndex: 2,
    explanation:
        'رمز التحقق مفتاح حسابك. لا جهة رسمية — بنك أو تطبيق أو دعم فني — '
        'تطلب منك رمز التحقق أبداً.',
  ),
  QuizQuestion(
    question: 'لماذا لا تحذف رسائل الابتزاز؟',
    options: [
      'لتذكير نفسك بالحادثة',
      'لأنها الدليل الأقوى في البلاغ والتحقيق',
      'لأن المبتز سيعرف إن حذفتها',
      'لا سبب — يمكن حذفها',
    ],
    correctIndex: 1,
    explanation:
        'الرسائل المحفوظة (مع الهاش الذي يثبت عدم التلاعب) هي أساس '
        'البلاغ الرسمي وأداة الإثبات أمام الجهات.',
  ),
  QuizQuestion(
    question: 'كيف يحمي التشفير في NAP-EX رسائلك؟',
    options: [
      'يرسلها إلى الخادم مباشرة ليحفظها',
      'يخزنها مشفرة على جهازك بمفتاح لا يغادر الهاتف',
      'يخفيها في مجلد مخفي بدون تشفير',
      'يحذفها بعد القراءة',
    ],
    correctIndex: 1,
    explanation:
        'كل محتوى يُحفظ مشفراً AES-256 مع بصمة سلامة، والمفتاح داخل '
        'المخزن الآمن للجهاز — لا يغادر هاتفك.',
  ),
  QuizQuestion(
    question: 'ما المقصود بـ «مبتز محترف» في تحليل الأنماط؟',
    options: [
      'مبتز يعمل بوظيفة كاملة',
      'مرسل رُبط بأكثر من ضحية أو حملة بلاغات متكررة',
      'مبتز يستخدم برامج متقدمة',
      'أي مبتز أجنبي',
    ],
    correctIndex: 1,
    explanation:
        'الخادم يجمع البلاغات حسب بصمة المرسل: ضحيتان أو أكثر أو 4 بلاغات '
        'أو أكثر = نمط احترافي يستحق أولوية تحقيق أعلى.',
  ),
  QuizQuestion(
    question: 'ما فائدة بصمة (Hash) الدليل؟',
    options: [
      'تسريع فتح الملف',
      'إثبات أن الدليل لم يتغير منذ لحظة الحفظ',
      'ضغط حجم الملف',
      'إخفاء محتوى الدليل',
    ],
    correctIndex: 1,
    explanation:
        'الهاش بصمة رياضية: أي تغيير حرف واحد في الدليل يغيّرها كلياً — '
        'فتطابقها يثبت سلامة الدليل أمام الجهات.',
  ),
  QuizQuestion(
    question: 'شخص غريب أرسل لك طلب صداقة وبدأ يمتدحك ثم طلب صوراً. التصرف؟',
    options: [
      'أرسل صوراً عادية فقط',
      'أرفض وأحجبه وأبلغ عنه',
      'أتفادى الطلب بصمت دون حجب',
      'أطلب منه إثبات هويته أولاً',
    ],
    correctIndex: 1,
    explanation:
        'هذا نمط كلاسيكي لبداية الابتزاز. الرفض + الحجب + الإبلاغ يقطع '
        'الطريق من البداية.',
  ),
  QuizQuestion(
    question: 'متى تُفعّل خدمة إمكانية الوصول في التطبيق؟',
    options: [
      'لقراءة كل رسائلك وإرسالها للخادم',
      'لكشف رسائل التطبيقات محلياً على جهازك فقط',
      'لعرض إشعارات التطبيقات الملونة',
      'لتحسين سرعة الجهاز',
    ],
    correctIndex: 1,
    explanation:
        'الخدمة تقرأ محتوى الرسائل محلياً بغرض الكشف فقط، ولا يُرفع شيء '
        'إلا رسالة الابتزاز المؤكدة التي توافق على بلاغها.',
  ),
  QuizQuestion(
    question: 'ماذا يحدث لبلاغك بعد إرساله للمنصة؟',
    options: [
      'ينتهي الأمر — لا متابعة',
      'يحصل على رقم رسمي وتتابع مراحله حتى الحل مع إشعارات',
      'يُحفظ في أرشيف دون معالجة',
      'يُنشر علناً لتحذير الناس',
    ],
    correctIndex: 1,
    explanation:
        'كل بلاغ يحصل على رقم رسمي وسلسلة حفظ، وتتابع مراحله (استلام → '
        'مراجعة → تحقيق → حل) مع إشعار تلقائي عند كل تطور.',
  ),
];

/// شاشة الاختبار التفاعلي — التثقيف العملي
class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _index = 0;
  int? _selected;
  int _score = 0;
  bool _finished = false;

  void _answer(int optionIndex) {
    if (_selected != null) return;
    final question = _questions[_index];
    setState(() {
      _selected = optionIndex;
      if (optionIndex == question.correctIndex) _score++;
    });
  }

  void _next() {
    if (_index < _questions.length - 1) {
      setState(() {
        _index++;
        _selected = null;
      });
    } else {
      setState(() => _finished = true);
    }
  }

  void _retry() {
    setState(() {
      _index = 0;
      _selected = null;
      _score = 0;
      _finished = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_finished) {
      final percentage = (_score / _questions.length * 100).round();
      final message = percentage >= 80
          ? 'ممتاز! أنت واعٍ ومحمي 💪'
          : percentage >= 50
              ? 'جيد — راجع شاشة التثقيف لتقوية نقاطك'
              : 'أعد القراءة في شاشة التثقيف ثم حاول مجدداً';

      return Scaffold(
        appBar: AppBar(title: const Text('نتيجتك')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (percentage >= 80
                            ? AppColors.success
                            : percentage >= 50
                                ? AppColors.warning
                                : AppColors.danger)
                        .withValues(alpha: 0.1),
                    border: Border.all(
                      color: percentage >= 80
                          ? AppColors.success
                          : percentage >= 50
                              ? AppColors.warning
                              : AppColors.danger,
                      width: 3,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$percentage%',
                      style: theme.textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '$_score من ${_questions.length}',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 28),
                PrimaryButton(
                  label: 'إعادة الاختبار',
                  icon: Icons.refresh,
                  onPressed: _retry,
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('عودة للتثقيف'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final question = _questions[_index];
    final isAnswered = _selected != null;
    final isCorrect = _selected == question.correctIndex;

    return Scaffold(
      appBar: AppBar(
        title: Text('اختبار معرفتك ${_index + 1}/${_questions.length}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (_index + (isAnswered ? 1 : 0)) / _questions.length,
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            question.question,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          for (var i = 0; i < question.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _optionTile(question, i),
            ),
          if (isAnswered) ...[
            const SizedBox(height: 8),
            NapexCard(
              color: isCorrect
                  ? AppColors.success.withValues(alpha: 0.08)
                  : AppColors.danger.withValues(alpha: 0.08),
              borderColor: isCorrect
                  ? AppColors.success.withValues(alpha: 0.35)
                  : AppColors.danger.withValues(alpha: 0.35),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isCorrect
                            ? Icons.check_circle_outline
                            : Icons.info_outline,
                        color: isCorrect ? AppColors.success : AppColors.danger,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isCorrect ? 'إجابة صحيحة!' : 'الإجابة الصحيحة: '
                            '${question.options[question.correctIndex]}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color:
                              isCorrect ? AppColors.success : AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    question.explanation,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.7),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: _index < _questions.length - 1
                  ? 'السؤال التالي'
                  : 'عرض النتيجة',
              icon: Icons.arrow_back,
              onPressed: _next,
            ),
          ],
        ],
      ),
    );
  }

  Widget _optionTile(QuizQuestion question, int optionIndex) {
    final theme = Theme.of(context);
    final isAnswered = _selected != null;
    final isThisCorrect = optionIndex == question.correctIndex;
    final isThisSelected = _selected == optionIndex;

    Color? borderColor;
    Color? fillColor;
    IconData? trailingIcon;
    Color? trailingColor;

    if (isAnswered && isThisCorrect) {
      borderColor = AppColors.success;
      fillColor = AppColors.success.withValues(alpha: 0.08);
      trailingIcon = Icons.check_circle;
      trailingColor = AppColors.success;
    } else if (isAnswered && isThisSelected && !isThisCorrect) {
      borderColor = AppColors.danger;
      fillColor = AppColors.danger.withValues(alpha: 0.06);
      trailingIcon = Icons.cancel;
      trailingColor = AppColors.danger;
    }

    return NapexCard(
      onTap: isAnswered ? null : () => _answer(optionIndex),
      color: fillColor,
      borderColor: borderColor,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              question.options[optionIndex],
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: isThisSelected ? FontWeight.bold : null,
              ),
            ),
          ),
          if (trailingIcon != null) Icon(trailingIcon, color: trailingColor),
        ],
      ),
    );
  }
}