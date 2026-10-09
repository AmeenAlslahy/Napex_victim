import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:napex_victim_app/core/theme/app_colors.dart';
import 'package:napex_victim_app/core/utils/extensions.dart';
import 'package:napex_victim_app/domain/entities/message_category.dart';
import 'package:napex_victim_app/presentation/providers/reports_providers.dart';
import 'package:napex_victim_app/presentation/shared/widgets/napex_card.dart';
import 'package:napex_victim_app/presentation/shared/widgets/napex_empty_state.dart';

/// شاشة إحصائياتي — تُحسب من بث البلاغات المحلي (بلا مستودع جديد)
class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  static const int _trendDays = 14;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(reportsProvider).reports;
    final theme = Theme.of(context);

    if (reports.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('إحصائياتي')),
        body: const NapexEmptyState(
          icon: Icons.insights_outlined,
          title: 'لا توجد بيانات كافية بعد',
          subtitle: 'عند وصول رسائل وإنشاء بلاغات ستظهر إحصائياتك هنا',
        ),
      );
    }

    final extortions = reports.where((r) => r.isExtortion).toList();
    final submitted = reports.where((r) => r.status.isSynced).length;
    final avgConfidence = extortions.isEmpty
        ? 0.0
        : extortions.map((r) => r.analysis.confidence).reduce((a, b) => a + b) /
            extortions.length;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dailyCounts = <DateTime, int>{};
    for (var i = _trendDays - 1; i >= 0; i--) {
      dailyCounts[today.subtract(Duration(days: i))] = 0;
    }
    for (final report in reports) {
      final day = DateTime(
        report.createdAt.year,
        report.createdAt.month,
        report.createdAt.day,
      );
      if (dailyCounts.containsKey(day)) {
        dailyCounts[day] = dailyCounts[day]! + 1;
      }
    }
    final maxDaily = dailyCounts.values.fold(1, (a, b) => a > b ? a : b);

    final categoryCounts = <MessageCategory, int>{};
    for (final report in reports) {
      categoryCounts[report.analysis.category] =
          (categoryCounts[report.analysis.category] ?? 0) + 1;
    }
    final sortedCategories = categoryCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      appBar: AppBar(title: const Text('إحصائياتي')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              _statCard(context, '${reports.length}', 'إجمالي الرسائل',
                  AppColors.primary),
              const SizedBox(width: 10),
              _statCard(
                  context, '${extortions.length}', 'ابتزاز مكتشف', AppColors.danger),
              const SizedBox(width: 10),
              _statCard(
                  context, '$submitted', 'بلاغ مُرسل', AppColors.success),
            ],
          ),
          const SizedBox(height: 16),

          // ============ الاتجاه اليومي ============
          NapexCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'آخر 14 يوماً',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 110,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final entry in dailyCounts.entries)
                        Expanded(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 2),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (entry.value > 0)
                                  Text(
                                    '${entry.value}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                const SizedBox(height: 3),
                                Container(
                                  height: (entry.value / maxDaily) * 70,
                                  constraints: const BoxConstraints(
                                      minHeight: 3),
                                  decoration: BoxDecoration(
                                    color: entry.value > 0
                                        ? AppColors.primary
                                        : AppColors.surfaceVariant,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(4),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${entry.key.day}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 9,
                                    color: AppColors.textDisabled,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ============ توزيع التصنيفات ============
          NapexCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'توزيع التصنيفات',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                for (final entry in sortedCategories)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              entry.key.labelAr,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${entry.value} • ${(entry.value / reports.length * 100).toStringAsFixed(0)}%',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: entry.value / reports.length,
                            minHeight: 7,
                            backgroundColor:
                                theme.colorScheme.surfaceContainerHighest,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              entry.key == MessageCategory.extortion
                                  ? AppColors.danger
                                  : entry.key == MessageCategory.threat
                                      ? AppColors.warning
                                      : AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ============ متوسط الثقة ============
          NapexCard(
            child: Row(
              children: [
                const Icon(Icons.verified_outlined, color: AppColors.secondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'متوسط ثقة الكشف في ابتزازاتك',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                Text(
                  avgConfidence.asPercent,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(
    BuildContext context,
    String value,
    String label,
    Color color,
  ) {
    final theme = Theme.of(context);
    return Expanded(
      child: NapexCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}