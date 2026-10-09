import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import 'package:napex_victim_app/core/constants/app_constants.dart';
import 'package:napex_victim_app/core/theme/app_colors.dart';
import 'package:napex_victim_app/core/utils/extensions.dart';
import 'package:napex_victim_app/domain/entities/report.dart';
import 'package:napex_victim_app/domain/repositories/settings_repository.dart';
import 'package:napex_victim_app/presentation/providers/settings_providers.dart';
import 'package:napex_victim_app/presentation/providers/collector_providers.dart';
import 'package:napex_victim_app/presentation/providers/reports_providers.dart';
import 'package:napex_victim_app/presentation/features/support/screens/trusted_contacts_screen.dart';
import 'package:napex_victim_app/presentation/shared/widgets/napex_card.dart';
import 'package:napex_victim_app/presentation/shared/widgets/napex_empty_state.dart';
import 'package:napex_victim_app/presentation/shared/widgets/report_card.dart';

/// لوحة التحكم — حالة الحماية والإحصائيات والإجراءات السريعة
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(collectorProvider.notifier).refreshPermissions();
      // بدء الحماية تلقائياً إن كانت مفعّلة
      if (ref.read(settingsProvider).protectionEnabled) {
        await ref.read(collectorProvider.notifier).start();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final collector = ref.watch(collectorProvider);
    final settings = ref.watch(settingsProvider);
    final reports = ref.watch(reportsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة الحماية'),
        actions: [
          IconButton(
            tooltip: 'إشعارات قضاياك',
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push('/notifications'),
          ),
          IconButton(
            tooltip: 'الأذونات',
            icon: const Icon(Icons.settings_accessibility_outlined),
            onPressed: () => context.push('/onboarding/permissions'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const SizedBox(height: 8),
          _ProtectionCard(collector: collector, settings: settings),
          const SizedBox(height: 16),
          _StatsOverview(reports: reports, collector: collector),
          const SizedBox(height: 16),
          const _QuickActions(),
          const SizedBox(height: 10),
          const _PanicButton(),
          const SizedBox(height: 16),
          _RecentReports(reports: reports.reports),
        ],
      ),
    );
  }
}

// ============ بطاقة حالة الحماية ============

class _ProtectionCard extends ConsumerWidget {
  const _ProtectionCard({required this.collector, required this.settings});

  final CollectorState collector;
  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final active = settings.protectionEnabled && collector.isRunning;

    return NapexCard(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: active
          ? AppColors.success.withValues(alpha: 0.08)
          : AppColors.danger.withValues(alpha: 0.08),
      borderColor: active
          ? AppColors.success.withValues(alpha: 0.4)
          : AppColors.danger.withValues(alpha: 0.4),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (active ? AppColors.success : AppColors.danger)
                      .withValues(alpha: 0.15),
                ),
                child: Icon(
                  active ? Icons.shield : Icons.shield_outlined,
                  color: active ? AppColors.success : AppColors.danger,
                  size: 32,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      active ? 'الحماية مفعّلة' : 'الحماية غير مفعّلة',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      collector.error ??
                          (active
                              ? 'يتم تحليل الرسائل الواردة تلقائياً'
                              : 'فعّل الحماية لبدء مراقبة الابتزاز'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: settings.protectionEnabled,
                onChanged: (value) async {
                  await ref
                      .read(settingsProvider.notifier)
                      .setProtectionEnabled(value);
                  if (value) {
                    await ref.read(collectorProvider.notifier).start();
                  } else {
                    await ref.read(collectorProvider.notifier).stop();
                  }
                },
              ),
            ],
          ),
          if (settings.protectionEnabled && !collector.isRunning) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: AppColors.warning),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    collector.accessibilityEnabled
                        ? 'جارٍ تجهيز الخدمة…'
                        : 'خدمة إمكانية الوصول غير مفعّلة — اضغط لتعيينها',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.warning),
                  ),
                ),
                if (!collector.accessibilityEnabled)
                  TextButton(
                    onPressed: () => context.go('/onboarding/permissions'),
                    child: const Text('تعيين'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ============ الإحصائيات ============

class _StatsOverview extends StatelessWidget {
  const _StatsOverview({required this.reports, required this.collector});

  final ReportsState reports;
  final CollectorState collector;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _statCard(
            context,
            Icons.gpp_bad_outlined,
            '${reports.detectedCount}',
            'بلاغ ابتزاز',
            AppColors.danger,
          ),
          const SizedBox(width: 10),
          _statCard(
            context,
            Icons.schedule,
            '${reports.pendingCount}',
            'قيد الإرسال',
            AppColors.warning,
          ),
          const SizedBox(width: 10),
          _statCard(
            context,
            Icons.visibility_outlined,
            '${collector.processedCount}',
            'رسالة محللة',
            AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _statCard(
    BuildContext context,
    IconData icon,
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
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              value,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            Text(
              label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ============ الإجراءات السريعة ============

class _QuickActions extends ConsumerWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _actionButton(
              context,
              icon: Icons.analytics_outlined,
              label: 'تحليل رسالة',
              onTap: () => _showAnalyzeDialog(context, ref),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _actionButton(
              context,
              icon: Icons.cloud_upload_outlined,
              label: 'إرسال البلاغات',
              onTap: () => ref.read(reportsProvider.notifier).sync(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _actionButton(
              context,
              icon: Icons.insights_outlined,
              label: 'إحصائياتي',
              onTap: () => context.push('/analytics'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return NapexCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAnalyzeDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تحليل رسالة'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'الصق نص الرسالة هنا لتحليلها وكشف الابتزاز…',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('تحليل'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final processed = await ref
        .read(collectorProvider.notifier)
        .analyzeManually(controller.text);

    if (!context.mounted) return;

    final analysis = processed?.analysis;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          analysis == null
              ? 'تعذر التحليل — حاول مجدداً'
              : 'النتيجة: ${analysis.category.labelAr} • الثقة ${analysis.confidence.asPercent}'
                  '${(processed?.reportCreated ?? false) ? ' • تم إنشاء بلاغ' : ''}',
        ),
        backgroundColor: (analysis?.isExtortion ?? false)
            ? AppColors.danger
            : AppColors.success,
      ),
    );
  }
}

// ============ زر الطوارئ ============

class _PanicButton extends ConsumerWidget {
  const _PanicButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.danger,
            side: const BorderSide(color: AppColors.danger, width: 1.5),
            backgroundColor: AppColors.danger.withValues(alpha: 0.05),
          ),
          icon: const Icon(Icons.emergency_outlined),
          label: const Text(
            'وضع الطوارئ — بلاغ عاجل + إشعار جهاتك',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          onPressed: () => _confirmPanic(context, ref),
        ),
      ),
    );
  }

  Future<void> _confirmPanic(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.emergency_outlined,
            color: AppColors.danger, size: 44),
        title: const Text('تفعيل وضع الطوارئ؟'),
        content: const Text(
          'سيُنشأ بلاغ عاجل للجهات المختصة فوراً، وستُجهَّز رسالة إشعار '
          'لجهاتك الموثوقة لمشاركتها بضغطة واحدة.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('نعم — طوارئ الآن'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final processed =
        await ref.read(collectorProvider.notifier).triggerPanic();
    final reportNumber = processed?.reportId;

    if (!context.mounted) return;

    // إرفاق الموقع اختيارياً — حسب إعداد المستخدم الصريح
    var locationLine = '';
    if (ref.read(settingsProvider).shareLocationOnPanic) {
      try {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          final position = await Geolocator.getCurrentPosition();
          locationLine =
              '\n📍 موقعي التقريبي: ${position.latitude.toStringAsFixed(5)}, '
              '${position.longitude.toStringAsFixed(5)}';
        }
      } catch (_) {
        // الموقع غير متاح — تُرسل الرسالة بلا موقع
      }
    }

    // تجهيز نص المشاركة لجهات الاتصال الموثوقة
    await shareText(
      buildPanicShareText(
        contactName: 'جهتي الموثوقة',
        reportNumber: reportNumber,
      ) +
          locationLine,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '🆘 بلاغ طارئ أُنشئ — شارك رسالة الإشعار مع جهاتك من نافذة المشاركة',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }
}

// ============ آخر البلاغات ============

class _RecentReports extends StatelessWidget {
  const _RecentReports({required this.reports});

  final List<Report> reports;

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 40),
        child: NapexEmptyState(
          icon: Icons.inbox_outlined,
          title: 'لا توجد بلاغات بعد',
          subtitle: 'عند اكتشاف رسالة ابتزاز سيُنشأ بلاغ تلقائياً ويظهر هنا',
        ),
      );
    }

    final recent = reports.take(AppConstants.recentReportsCount).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'آخر البلاغات',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              TextButton(
                onPressed: () => context.go('/reports'),
                child: const Text('عرض الكل'),
              ),
            ],
          ),
        ),
        ...recent.map(
          (report) => ReportCard(
            report: report,
            onTap: () => context.push('/reports/detail/${report.localId}'),
          ),
        ),
      ],
    );
  }
}
