import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:napex_victim_app/core/constants/app_constants.dart';
import 'package:napex_victim_app/core/theme/app_colors.dart';
import 'package:napex_victim_app/core/utils/extensions.dart';
import 'package:napex_victim_app/presentation/providers/core_providers.dart';
import 'package:napex_victim_app/presentation/shared/widgets/napex_card.dart';
import 'package:napex_victim_app/presentation/shared/widgets/napex_empty_state.dart';

/// سجل نشاط المستخدم — يقرأ AuditDao المحلي الموجود أصلاً
class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  List<Map<String, Object?>>? _entries;

  static const Map<String, (IconData, Color, String)> _actionMeta = {
    'report_created': (
      Icons.gpp_bad_outlined,
      AppColors.danger,
      'إنشاء بلاغ ابتزاز',
    ),
    'report_submitted': (
      Icons.cloud_upload_outlined,
      AppColors.info,
      'إرسال بلاغ للمنصة',
    ),
    'report_deleted': (
      Icons.delete_outline,
      AppColors.warning,
      'حذف بلاغ',
    ),
    'evidence_saved': (
      Icons.lock_outlined,
      AppColors.secondary,
      'حفظ دليل مشفر',
    ),
    'evidence_verified': (
      Icons.verified_outlined,
      AppColors.success,
      'التحقق من سلامة دليل',
    ),
    'message_saved': (
      Icons.chat_bubble_outline,
      AppColors.primary,
      'رسالة محللة ومحفوظة',
    ),
    'forensic_case_opened': (
      Icons.search_outlined,
      AppColors.info,
      'فتح قضية جنائية',
    ),
    'legal_order_issued': (
      Icons.gavel_outlined,
      AppColors.info,
      'إصدار أمر قانوني',
    ),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await ref.read(auditDaoProvider).getRecent(
          limit: AppConstants.activityLogLimit,
        );
    if (mounted) setState(() => _entries = entries);
  }

  (IconData, Color, String) _metaFor(String action) =>
      _actionMeta[action] ??
      (Icons.circle_outlined, AppColors.textSecondary, action);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('سجل النشاط')),
      body: _entries == null
          ? const Center(child: CircularProgressIndicator())
          : _entries!.isEmpty
              ? const NapexEmptyState(
                  icon: Icons.history_outlined,
                  title: 'لا يوجد نشاط بعد',
                  subtitle: 'كل إجراء يحدث في التطبيق يُوثَّق هنا',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (final entry in _entries!)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: NapexCard(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            child: Builder(
                              builder: (context) {
                                final action =
                                    entry['action'] as String? ?? '';
                                final (icon, color, label) = _metaFor(action);
                                final entityId =
                                    entry['entity_id'] as String? ?? '';

                                return Row(
                                  children: [
                                    Icon(icon, color: color, size: 22),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            label,
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          if (entityId.isNotEmpty)
                                            Text(
                                              '${entry['entity_type']}: '
                                              '${entityId.substring(0, entityId.length > 8 ? 8 : entityId.length)}…',
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                color: AppColors.textDisabled,
                                                fontSize: 11,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      DateTime.fromMillisecondsSinceEpoch(
                                        entry['created_at'] as int? ?? 0,
                                      ).formattedDateTime,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                        fontSize: 10.5,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}