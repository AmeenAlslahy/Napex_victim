import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:napex_victim_app/core/theme/app_colors.dart';
import 'package:napex_victim_app/presentation/shared/widgets/napex_card.dart';

/// شاشة التثقيف — نصائح الحماية من الابتزاز الإلكتروني
class EducationScreen extends StatelessWidget {
  const EducationScreen({super.key});

  static const List<({String title, String body, IconData icon})> _articles = [
    (
      title: 'ما هو الابتزاز الإلكتروني؟',
      icon: Icons.help_outline,
      body: 'الابتزاز الإلكتروني هو تهديد شخص بنشر صور أو معلومات خاصة عنه '
          'ما لم يفي بمطالب المبتزِز — عادةً مالية. المبتزِز قد يكون شخصاً تعرفه '
          'أو غريباً اخترق حسابك أو انتحل هوية.\n\n'
          'الابتزاز جريمة يعاقب عليها القانون، والضحية هي الطرف المتضرر وليس المخطئ.',
    ),
    (
      title: 'كيف تحمي نفسك؟',
      icon: Icons.security_outlined,
      body: '• لا ترسل صوراً خاصة لأي شخص مهما كان.\n'
          '• لا تشارك رموز التحقق (OTP) أبداً — لا يطلبها أحد منك.\n'
          '• فعّل المصادقة الثنائية على حساباتك.\n'
          '• لا تقبل طلبات صداقة من مجهولين ولا تنقر روابط مجهولة.\n'
          '• راجع إعدادات خصوصية حساباتك دورياً.',
    ),
    (
      title: 'ماذا تفعل إذا تعرضت للابتزاز؟',
      icon: Icons.emergency_outlined,
      body: '1. لا تدفع — الدفع يفتح الباب لمطالب أكثر ولا يوقف الابتزاز.\n'
          '2. لا تحذف الرسائل — هي دليلك الأقوى.\n'
          '3. لا تستجيب للتهديدات ولا ترسل المزيد.\n'
          '4. أبلغ فوراً عبر تطبيق NAP-EX أو الجهات المختصة.\n'
          '5. أخبر شخصاً تثق به — فأنت لست وحدك، والدعم يخفف الضغط.\n\n'
          'تذكر: المبتزَز هو الضحية، والمسؤولية القانونية كاملة على المبتزِز.',
    ),
    (
      title: 'كيف يحميك تطبيق NAP-EX؟',
      icon: Icons.shield_outlined,
      body: '• يحلل الرسائل الواردة تلقائياً ويكشف محاولات الابتزاز عبر محرك '
          'ذكي يدعم العربية.\n'
          '• ينبهك فوراً عند اكتشاف رسالة خطيرة.\n'
          '• يحفظ الأدلة مشفرة على جهازك مع بصمة (هاش) تثبت عدم التلاعب.\n'
          '• ينشئ بلاغاً رسمياً جاهزاً للإرسال للجهات المختصة بضغطة واحدة.\n\n'
          'كل ما يحدث على جهازك يبقى مشفراً، ولا يُرسل إلا ما وافقت عليه.',
    ),
    (
      title: 'حقوقك القانونية',
      icon: Icons.gavel_outlined,
      body: 'معظم التشريعات العربية تعتبر الابتزاز الإلكتروني جريمة يعاقب '
          'عليها بالحبس والغرامة، سواء شمل التهديد بالنشر أو طلب المال.\n\n'
          'الإبلاغ الرسمي بحماية القانون لا يحتاج منك الكشف عن أي محتوى '
          'للعامة — البلاغات تُعامل بسرية تامة وتُعرض على جهات التحقيق فقط.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('تثقيف وحماية')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          NapexCard(
            color: AppColors.primary.withValues(alpha: 0.05),
            borderColor: AppColors.primary.withValues(alpha: 0.2),
            child: Row(
              children: [
                const Icon(Icons.school_outlined, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'معرفتك أقوى سلاح — اقرأ هذه الإرشادات وشاركها مع من تحب.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ============ الاختبار التفاعلي ============
          NapexCard(
            onTap: () => context.push('/quiz'),
            color: AppColors.secondary.withValues(alpha: 0.07),
            borderColor: AppColors.secondary.withValues(alpha: 0.3),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.quiz_outlined,
                      color: AppColors.secondary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'اختبر معرفتك',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondary,
                        ),
                      ),
                      Text(
                        '10 أسئلة سريعة — هل أنت محمي فعلاً؟',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_left, color: AppColors.secondary),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ..._articles.map(
            (article) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: NapexCard(
                padding: EdgeInsets.zero,
                child: Theme(
                  data: theme.copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    leading: Icon(article.icon, color: AppColors.primary),
                    title: Text(
                      article.title,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          article.body,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(height: 1.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
