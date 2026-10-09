
/// بطاقة موحدة بحدود ناعمة (بدون ظلال — تصميم مسطح نظيف)
import 'package:flutter/material.dart';

/// بطاقة موحّدة بحدود ناعمة — Material كجذر حتى يعمل ListTile وInkWell
/// (Container/DecoratedBox كان يخفي خلفية ListTile وink splash — 40+ تحذير)
class NapexCard extends StatelessWidget {
  const NapexCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.borderColor,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.surface;
    final effectiveBorder = borderColor ??
        theme.dividerTheme.color ??
        theme.colorScheme.outlineVariant;
    final radius = BorderRadius.circular(16);

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Material(
        color: effectiveColor,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: effectiveBorder),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
