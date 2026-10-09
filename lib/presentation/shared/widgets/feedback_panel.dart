import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:napex_victim_app/core/theme/app_colors.dart';
import 'package:napex_victim_app/presentation/providers/core_providers.dart';
import 'package:napex_victim_app/presentation/shared/widgets/napex_card.dart';

/// أزرار التغذية الراجعة — الضحية تحكم على دقة الكشف (Feedback Loop)
class FeedbackPanel extends ConsumerStatefulWidget {
  const FeedbackPanel({required this.reportId, super.key});

  final String reportId;

  @override
  ConsumerState<FeedbackPanel> createState() => _FeedbackPanelState();
}

class _FeedbackPanelState extends ConsumerState<FeedbackPanel> {
  bool _busy = false;
  String? _submittedType;

  Future<void> _submit({
    required String type,
    String? extortionKind,
    String successMessage = 'شكراً لك — تقييمك يحسّن دقة الكشف',
  }) async {
    setState(() => _busy = true);
    try {
      await ref.read(victimApiProvider).submitFeedback(
            reportId: widget.reportId,
            feedbackType: type,
            extortionKind: extortionKind,
          );
      if (mounted) {
        setState(() => _submittedType = type);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر إرسال التقييم — سيُحاول لاحقاً: $e'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmExtortion() async {
    final kind = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('نوع الابتزاز؟'),
        children: [
          for (final (value, label) in const [
            ('financial', 'ابتزاز مالي'),
            ('sexual', 'ابتزاز جنسي'),
            ('reputation', 'التهديد بالنشر'),
            ('threat', 'تهديد بالأذى'),
            ('other', 'أخرى'),
          ])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, value),
              child: Text(label),
            ),
        ],
      ),
    );

    if (kind != null) {
      await _submit(
        type: 'confirmed',
        extortionKind: kind,
        successMessage: 'تم تأكيد الابتزاز — تقييمك يرفع دقة النظام',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return NapexCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تقييم الكشف — ساعدنا نتحسن',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            _submittedType == null
                ? 'هل تصنيف هذه الرسالة صحيح؟'
                : '✓ شكراً — تم تسجيل تقييمك',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          if (_submittedType == null)
            Row(
              children: [
                Expanded(
                  child: _feedbackButton(
                    label: 'ابتزاز ✓',
                    color: AppColors.success,
                    onPressed: _busy ? null : _confirmExtortion,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _feedbackButton(
                    label: 'سوء فهم ✗',
                    color: AppColors.danger,
                    onPressed: _busy
                        ? null
                        : () => _submit(
                              type: 'false_positive',
                              successMessage:
                                  'سُجّل كخطأ — لن نزعجك بمثل هذه الرسائل بنفس الحساسية',
                            ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _feedbackButton(
                    label: 'لست متأكداً',
                    color: AppColors.warning,
                    onPressed: _busy
                        ? null
                        : () => _submit(type: 'uncertain'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _feedbackButton({
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}
