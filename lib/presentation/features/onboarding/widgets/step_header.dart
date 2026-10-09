import 'package:flutter/material.dart';

/// ترويسة خطوات موحدة لشاشات الـ Onboarding
/// (شريط تقدم + عدّاد + عنوان + وصف)
class OnboardingStepHeader extends StatelessWidget {
  const OnboardingStepHeader({
    required this.currentStep,
    required this.totalSteps,
    required this.title,
    super.key,
    this.subtitle,
  });

  final int currentStep;
  final int totalSteps;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: currentStep / totalSteps,
                  minHeight: 6,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$currentStep / $totalSteps',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
              height: 1.6,
            ),
          ),
        ],
      ],
    );
  }
}
