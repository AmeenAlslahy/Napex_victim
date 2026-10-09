import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:napex_victim_app/core/theme/app_colors.dart';
import 'package:napex_victim_app/presentation/providers/reports_providers.dart';
import 'package:napex_victim_app/presentation/shared/widgets/napex_empty_state.dart';
import 'package:napex_victim_app/presentation/shared/widgets/primary_button.dart';
import 'package:napex_victim_app/presentation/shared/widgets/report_card.dart';

const _statusOptions = <(String, String)>[
  ('', 'كل الحالات'),
  ('pending', 'قيد الإرسال'),
  ('submitted', 'تم الإرسال'),
  ('received', 'تم الاستلام'),
  ('under_review', 'قيد المراجعة'),
  ('investigating', 'قيد التحقيق'),
  ('resolved', 'تم الحل'),
  ('failed', 'فشل الإرسال'),
];

const _categoryOptions = <(String, String)>[
  ('', 'كل التصنيفات'),
  ('extortion', 'ابتزاز'),
  ('threat', 'تهديد'),
  ('suspicious', 'مشبوه'),
  ('spam', 'إعلانات'),
  ('normal', 'عادي'),
];

/// قائمة البلاغات — بث مباشر + فلاتر وبحث
class ReportsListScreen extends ConsumerWidget {
  const ReportsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(reportsProvider);
    final visible = reports.visibleReports;
    final theme = Theme.of(context);

    ref.listen<ReportsState>(reportsProvider, (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
      if (next.lastSyncMessage != null &&
          next.lastSyncMessage != prev?.lastSyncMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.lastSyncMessage!)),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(
          reports.hasActiveFilters
              ? 'البلاغات (${visible.length} من ${reports.reports.length})'
              : 'البلاغات',
        ),
        actions: [
          if (reports.isSyncing)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              ),
            )
          else
            IconButton(
              tooltip: 'إرسال البلاغات المعلقة',
              icon: const Icon(Icons.cloud_upload_outlined),
              onPressed: () => ref.read(reportsProvider.notifier).sync(),
            ),
        ],
      ),
      body: Column(
        children: [
          // ============ الفلاتر ============
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: TextField(
              onChanged: (value) =>
                  ref.read(reportsProvider.notifier).setSearchQuery(value),
              decoration: InputDecoration(
                hintText: 'بحث في المحتوى أو المرسل أو رقم البلاغ…',
                prefixIcon: const Icon(Icons.search_outlined),
                isDense: true,
                suffixIcon: reports.searchQuery.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () =>
                            ref.read(reportsProvider.notifier).setSearchQuery(''),
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: reports.filterStatus,
                    isDense: true,
                    decoration: const InputDecoration(
                      labelText: 'الحالة',
                      isDense: true,
                    ),
                    items: _statusOptions
                        .map((o) => DropdownMenuItem(
                              value: o.$1,
                              child: Text(o.$2,
                                  style: const TextStyle(fontSize: 13)),
                            ))
                        .toList(),
                    onChanged: (value) => ref
                        .read(reportsProvider.notifier)
                        .setStatusFilter(value ?? ''),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: reports.filterCategory,
                    isDense: true,
                    decoration: const InputDecoration(
                      labelText: 'التصنيف',
                      isDense: true,
                    ),
                    items: _categoryOptions
                        .map((o) => DropdownMenuItem(
                              value: o.$1,
                              child: Text(o.$2,
                                  style: const TextStyle(fontSize: 13)),
                            ))
                        .toList(),
                    onChanged: (value) => ref
                        .read(reportsProvider.notifier)
                        .setCategoryFilter(value ?? ''),
                  ),
                ),
                if (reports.hasActiveFilters)
                  IconButton(
                    tooltip: 'مسح الفلاتر',
                    icon: const Icon(Icons.filter_alt_off_outlined,
                        color: AppColors.primary),
                    onPressed: () =>
                        ref.read(reportsProvider.notifier).clearFilters(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // ============ القائمة ============
          Expanded(
            child: reports.reports.isEmpty
                ? NapexEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'لا توجد بلاغات',
                    subtitle: 'ستظهر هنا بلاغات الابتزاز التي يكتشفها التطبيق',
                    action: PrimaryButton(
                      label: 'إرسال البلاغات المعلقة',
                      icon: Icons.cloud_upload_outlined,
                      onPressed: () =>
                          ref.read(reportsProvider.notifier).sync(),
                    ),
                  )
                : visible.isEmpty
                    ? NapexEmptyState(
                        icon: Icons.filter_alt_off_outlined,
                        title: 'لا نتائج مطابقة',
                        subtitle: 'جرّب تعديل الفلاتر أو كلمة البحث',
                      )
                    : RefreshIndicator(
                        onRefresh: () =>
                            ref.read(reportsProvider.notifier).sync(),
                        child: ListView.builder(
                          itemCount: visible.length,
                          itemBuilder: (context, index) {
                            final report = visible[index];
                            return ReportCard(
                              report: report,
                              onTap: () => context
                                  .push('/reports/detail/${report.localId}'),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
