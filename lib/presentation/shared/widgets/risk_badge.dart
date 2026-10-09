import 'package:flutter/material.dart';

import 'package:napex_victim_app/domain/entities/risk_level.dart';

/// شارة مستوى الخطورة (لون + نص عربي)
class RiskBadge extends StatelessWidget {
  const RiskBadge({required this.riskLevel, super.key, this.showLabel = true});

  final RiskLevel riskLevel;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final color = Color(riskLevel.colorValue);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 4, backgroundColor: color),
          if (showLabel) ...[
            const SizedBox(width: 6),
            Text(
              riskLevel.labelAr,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
