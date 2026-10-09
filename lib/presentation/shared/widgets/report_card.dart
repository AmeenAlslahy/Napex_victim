import 'package:flutter/material.dart';

import 'package:napex_victim_app/core/utils/extensions.dart';
import 'package:napex_victim_app/domain/entities/report.dart';
import 'package:napex_victim_app/presentation/shared/widgets/napex_card.dart';
import 'package:napex_victim_app/presentation/shared/widgets/risk_badge.dart';
import 'package:napex_victim_app/presentation/shared/widgets/status_chip.dart';

/// بطاقة بلاغ مختصرة (قائمة البلاغات + لوحة التحكم)
class ReportCard extends StatelessWidget {
  const ReportCard({required this.report, required this.onTap, super.key});

  final Report report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return NapexCard(
      onTap: onTap,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  report.sender.displayName,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              StatusChip(status: report.status),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                _sourceIcon(report.source.app.packageName),
                size: 14,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(width: 4),
              Text(
                report.source.app.displayName,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
              const Spacer(),
              Text(
                report.createdAt.timeAgoAr,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            report.content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              RiskBadge(riskLevel: report.riskLevel),
              const Spacer(),
              if (report.analysis.confidence > 0)
                Text(
                  'الثقة ${report.analysis.confidence.asPercent}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _sourceIcon(String package) {
    return switch (package) {
      'sms' => Icons.sms_outlined,
      'com.whatsapp' || 'com.whatsapp.w4b' => Icons.chat_bubble_outline,
      'org.telegram.messenger' => Icons.send_outlined,
      'com.facebook.orca' || 'com.facebook.katana' => Icons.facebook,
      'com.instagram.android' => Icons.camera_alt_outlined,
      _ => Icons.apps,
    };
  }
}
