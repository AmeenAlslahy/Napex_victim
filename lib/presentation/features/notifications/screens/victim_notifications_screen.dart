import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:napex_victim_app/core/theme/app_colors.dart';
import 'package:napex_victim_app/data/datasources/remote/api/victim_api.dart';
import 'package:napex_victim_app/presentation/providers/core_providers.dart';
import 'package:napex_victim_app/presentation/shared/widgets/napex_card.dart';
import 'package:napex_victim_app/presentation/shared/widgets/napex_empty_state.dart';

/// عنصر إشعار مبسط من الخادم
class VictimNotificationItem {
  const VictimNotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String type;
  final String title;
  final String message;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  static VictimNotificationItem fromMap(Map<dynamic, dynamic> map) {
    return VictimNotificationItem(
      id: map['id']?.toString() ?? '',
      type: map['type']?.toString() ?? 'case_update',
      title: map['title']?.toString() ?? '',
      message: map['message']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
              DateTime.now(),
      readAt: DateTime.tryParse(map['read_at']?.toString() ?? ''),
    );
  }
}

/// مزود الإشعارات — جلب + تعليم كمقروء
final victimNotificationsProvider =
    StateNotifierProvider<VictimNotificationsController, List<VictimNotificationItem>?>(
  (ref) => VictimNotificationsController(ref.watch(victimApiProvider)),
);

class VictimNotificationsController
    extends StateNotifier<List<VictimNotificationItem>?> {
  VictimNotificationsController(this._api) : super(null) {
    refresh();
  }

  final VictimApi _api;

  Future<void> refresh() async {
    try {
      final items = await _api.fetchMyNotifications();
      state = items
          .map((e) => VictimNotificationItem.fromMap(Map<dynamic, dynamic>.from(e)))
          .toList();
    } catch (_) {
      state = [];
    }
  }

  Future<void> markRead(VictimNotificationItem item) async {
    if (item.isRead) return;
    try {
      await _api.markRead(item.id);
      await refresh();
    } catch (_) {
      // الخادم غير متاح — تجاهل بهدوء
    }
  }
}

/// شاشة إشعارات الضحية — تطور القضية والحذف الآمن والإزالة السحابية
class VictimNotificationsScreen extends ConsumerWidget {
  const VictimNotificationsScreen({super.key});

  static const _typeMeta = {
    'files_deleted': (Icons.cleaning_services_outlined, AppColors.success, 'تم الحذف الآمن'),
    'cloud_cleaned': (Icons.cloud_done_outlined, AppColors.success, 'إزالة سحابية'),
    'case_update': (Icons.update_outlined, AppColors.info, 'تحديث قضية'),
    'general': (Icons.campaign_outlined, AppColors.warning, 'إشعار عام'),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(victimNotificationsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('إشعارات قضاياك')),
      body: notifications == null
          ? const Center(child: CircularProgressIndicator())
          : notifications.isEmpty
              ? const NapexEmptyState(
                  icon: Icons.notifications_none_outlined,
                  title: 'لا توجد إشعارات بعد',
                  subtitle:
                      'عند تطور أي قضية من قضاياك — حذف آمن أو إزالة سحابية — '
                      'سيصلك إشعار هنا تلقائياً',
                )
              : RefreshIndicator(
                  onRefresh: () =>
                      ref.read(victimNotificationsProvider.notifier).refresh(),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (final n in notifications)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: NapexCard(
                            onTap: () => ref
                                .read(victimNotificationsProvider.notifier)
                                .markRead(n),
                            color: n.isRead
                                ? null
                                : AppColors.primary.withValues(alpha: 0.04),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  _iconFor(n.type),
                                  color: _colorFor(n.type),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              n.title,
                                              style: theme.textTheme.titleSmall
                                                  ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          if (!n.isRead)
                                            Container(
                                              width: 9,
                                              height: 9,
                                              decoration: const BoxDecoration(
                                                color: AppColors.primary,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        n.message,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(height: 1.6),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '${_labelFor(n.type)} • '
                                        '${DateFormat('yyyy/MM/dd – HH:mm').format(n.createdAt)}',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                          color: AppColors.textDisabled,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  IconData _iconFor(String type) =>
      (_typeMeta[type] ?? _typeMeta['general']!).$1;

  Color _colorFor(String type) =>
      (_typeMeta[type] ?? _typeMeta['general']!).$2;

  String _labelFor(String type) =>
      (_typeMeta[type] ?? _typeMeta['general']!).$3;
}
