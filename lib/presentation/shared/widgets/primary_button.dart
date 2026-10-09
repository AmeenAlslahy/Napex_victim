import 'package:flutter/material.dart';

/// زر أساسي بحالة تحميل مدمجة
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.isLoading = false,
    this.isDanger = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isDanger;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onPressed != null && !isLoading;

    return SizedBox(
      height: 52,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isDanger ? theme.colorScheme.error : theme.colorScheme.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor:
              (isDanger ? theme.colorScheme.error : theme.colorScheme.primary)
                  .withValues(alpha: 0.5),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
                  Text(label),
                ],
              ),
      ),
    );
  }
}
