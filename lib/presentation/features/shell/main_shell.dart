import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:napex_victim_app/core/theme/app_colors.dart';
import 'package:napex_victim_app/core/utils/extensions.dart';
import 'package:napex_victim_app/domain/usecases/collector/process_message_usecase.dart';
import 'package:napex_victim_app/presentation/providers/collector_providers.dart';
import 'package:napex_victim_app/presentation/providers/reports_providers.dart';

/// الهيكل الرئيسي — تنقل سفلي بين الأقسام مع التنبيهات العامة
class MainShell extends ConsumerWidget {
  const MainShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // تنبيه عام عند اكتشاف ابتزاز (يظهر في أي قسم)
    ref.listen<CollectorState>(collectorProvider, (prev, next) {
      final alert = next.lastAlert;
      if (alert != null && prev?.lastAlert?.reportId != alert.reportId) {
        _showExtortionAlert(context, ref, alert);
      }
    });

    final pendingCount = ref.watch(
      reportsProvider.select((state) => state.pendingCount),
    );

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.shield_outlined),
            selectedIcon: Icon(Icons.shield),
            label: 'الحماية',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: pendingCount > 0,
              label: Text('$pendingCount'),
              child: const Icon(Icons.receipt_long_outlined),
            ),
            selectedIcon: const Icon(Icons.receipt_long),
            label: 'البلاغات',
          ),
          const NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school),
            label: 'تثقيف',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'الإعدادات',
          ),
        ],
      ),
    );
  }

  void _showExtortionAlert(
    BuildContext context,
    WidgetRef ref,
    ProcessMessageResult alert,
  ) {
    final analysis = alert.analysis;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.gpp_bad, color: AppColors.danger, size: 48),
        title: const Text('⚠️ تم اكتشاف ابتزاز'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'من: ${alert.message.sender.displayName}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'التصنيف: ${analysis.category.labelAr} • الخطورة: ${analysis.riskLevel.labelAr} • الثقة ${analysis.confidence.asPercent}',
              style: Theme.of(dialogContext).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              alert.reportCreated
                  ? 'تم إنشاء بلاغ وحفظه مشفراً — سيُرسل تلقائياً'
                  : 'تم حفظ الرسالة مشفرة',
              style: Theme.of(dialogContext).textTheme.bodySmall,
            ),
            if (analysis.recommendations.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                '• ${analysis.recommendations.first}',
                style: const TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(collectorProvider.notifier).clearAlert();
              Navigator.of(dialogContext).pop();
            },
            child: const Text('حسناً'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(collectorProvider.notifier).clearAlert();
              Navigator.of(dialogContext).pop();
              context.go('/reports');
            },
            child: const Text('عرض البلاغات'),
          ),
        ],
      ),
    );
  }
}
