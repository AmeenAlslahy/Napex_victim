import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:napex_victim_app/core/error/failures.dart';
import 'package:napex_victim_app/core/theme/app_colors.dart';
import 'package:napex_victim_app/domain/repositories/collector_repository.dart';
import 'package:napex_victim_app/presentation/features/onboarding/widgets/step_header.dart';
import 'package:napex_victim_app/presentation/providers/collector_providers.dart';
import 'package:napex_victim_app/presentation/providers/core_providers.dart';
import 'package:napex_victim_app/presentation/shared/widgets/entrance.dart';
import 'package:napex_victim_app/presentation/shared/widgets/napex_card.dart';
import 'package:napex_victim_app/presentation/shared/widgets/primary_button.dart';

/// شاشة الأذونات — تفعيل حقيقي لكل صلاحية مع تحديث الحالة فور العودة للتطبيق
class PermissionsScreen extends ConsumerStatefulWidget {
  const PermissionsScreen({super.key});

  @override
  ConsumerState<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends ConsumerState<PermissionsScreen>
    with WidgetsBindingObserver {
  /// حالة كل صلاحية — null تعني "قيد الفحص"
  final Map<_PermissionKey, bool?> _statuses = {
    _PermissionKey.notifications: null,
    _PermissionKey.accessibility: null,
    _PermissionKey.notificationListener: null,
    _PermissionKey.sms: null,
  };

  _PermissionKey? _busyKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshAll());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // تحديث الحالات فور العودة من إعدادات النظام
    if (state == AppLifecycleState.resumed) {
      _refreshAll();
    }
  }

  CollectorRepository get _repository =>
      ref.read(collectorRepositoryProvider);

  /// صلاحيات خدمات النظام متاحة على أندرويد فقط
  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> _refreshAll() async {
    final notifications = _isAndroid
        ? await _repository.isNotificationPermissionGranted()
        : false;
    final accessibility = await _repository.isAccessibilityEnabled();
    final notificationListener =
        await _repository.isNotificationListenerEnabled();
    final sms =
        _isAndroid ? await _repository.isSmsPermissionGranted() : false;

    if (!mounted) return;
    setState(() {
      _statuses[_PermissionKey.notifications] = notifications;
      _statuses[_PermissionKey.accessibility] = accessibility;
      _statuses[_PermissionKey.notificationListener] = notificationListener;
      _statuses[_PermissionKey.sms] = sms;
    });

    // مزامنة حالة الأذونات مع متحكم الجمع (يقرأها لوحة التحكم)
    await ref.read(collectorProvider.notifier).refreshPermissions();
  }

  Future<void> _handleAction(_PermissionKey key) async {
    setState(() => _busyKey = key);

    switch (key) {
      case _PermissionKey.notifications:
        await _repository.requestNotificationPermission();
        await _refreshAll();
      case _PermissionKey.sms:
        await _repository.requestSmsPermission();
        await _refreshAll();
      case _PermissionKey.accessibility:
        await _openAndReport(_repository.openAccessibilitySettings);
      case _PermissionKey.notificationListener:
        await _openAndReport(_repository.openNotificationSettings);
    }

    if (mounted) setState(() => _busyKey = null);
  }

  /// فتح إعدادات النظام مع إظهار سبب الفشل إن حدث — لا فشل صامت
  Future<void> _openAndReport(
    Future<(bool, Failure?)> Function() open,
  ) async {
    final (opened, failure) = await open();
    if (!mounted) return;
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(failure?.message ?? 'تعذر فتح إعدادات النظام'),
          backgroundColor: AppColors.warning,
          duration: const Duration(seconds: 4),
        ),
      );
    }
    await _refreshAll();
  }

  int get _grantedCount =>
      _statuses.values.where((granted) => granted == true).length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('تفعيل الحماية')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Entrance(
            child: OnboardingStepHeader(
              currentStep: 1,
              totalSteps: 3,
              title: 'الأذونات المطلوبة',
              subtitle:
                  'كل صلاحية تُستخدم على جهازك فقط لحمايتك من الابتزاز. '
                  'يمكنك إكمال أي صلاحية لاحقاً من الإعدادات.',
            ),
          ),
          const SizedBox(height: 20),

          // ============ ملخص التقدم ============
          Entrance(
            delay: const Duration(milliseconds: 120),
            child: NapexCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: AppColors.primary.withValues(alpha: 0.05),
              borderColor: AppColors.primary.withValues(alpha: 0.18),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _grantedCount == 4
                          ? AppColors.success.withValues(alpha: 0.15)
                          : AppColors.primary.withValues(alpha: 0.1),
                    ),
                    child: Icon(
                      _grantedCount == 4
                          ? Icons.verified_outlined
                          : Icons.shield_outlined,
                      color: _grantedCount == 4
                          ? AppColors.success
                          : AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _grantedCount == 4
                          ? 'ممتاز! جميع الأذونات مفعّلة'
                          : 'مفعّل $_grantedCount من 4 أذونات',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ============ بطاقات الأذونات ============
          _permissionCard(
            context,
            key: _PermissionKey.notifications,
            icon: Icons.notifications_active_outlined,
            title: 'الإشعارات',
            description: 'لتنبيهك فوراً عند اكتشاف رسالة ابتزاز',
            actionLabel: 'طلب الصلاحية',
            entranceDelay: const Duration(milliseconds: 220),
          ),
          _permissionCard(
            context,
            key: _PermissionKey.accessibility,
            icon: Icons.accessibility_new_outlined,
            title: 'خدمة إمكانية الوصول',
            description:
                'لقراءة رسائل التطبيقات (واتساب، تيليجرام…) محلياً وكشف الابتزاز. '
                'فعّل «NAP-EX — كشف الابتزاز» من القائمة ثم عد إلى هنا.'
              '${_isAndroid ? '\n\nملاحظة لأندرويد 13+: إذا ظهرت رسالة «إعداد محظور»، '
                      'اضغط مطولاً على أيقونة التطبيق ← معلومات التطبيق ← '
                      'القائمة ⋮ ← «السماح بالإعدادات المحظورة» ثم أعد المحاولة.' : ''}',
            actionLabel: 'فتح الإعدادات',
            entranceDelay: const Duration(milliseconds: 300),
          ),
          _permissionCard(
            context,
            key: _PermissionKey.notificationListener,
            icon: Icons.mark_email_read_outlined,
            title: 'الاستماع للإشعارات',
            description:
                'لرصد إشعارات التطبيقات المُراقَبة حتى التي لا تظهر في شريط الحالة',
            actionLabel: 'فتح الإعدادات',
            entranceDelay: const Duration(milliseconds: 380),
          ),
          _permissionCard(
            context,
            key: _PermissionKey.sms,
            icon: Icons.sms_outlined,
            title: 'الرسائل النصية SMS',
            description: 'لكشف رسائل الابتزاز الواردة عبر الرسائل النصية',
            actionLabel: 'طلب الصلاحية',
            entranceDelay: const Duration(milliseconds: 460),
          ),

          const SizedBox(height: 8),
          Entrance(
            delay: const Duration(milliseconds: 540),
            child: NapexCard(
              color: AppColors.warning.withValues(alpha: 0.08),
              borderColor: AppColors.warning.withValues(alpha: 0.3),
              child: Row(
                children: [
                  const Icon(Icons.privacy_tip_outlined,
                      color: AppColors.warning, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'خصوصيتك أولاً: لا يُرفع أي محتوى إلا رسائل الابتزاز '
                      'المؤكدة، وكل شيء يُشفَّر قبل الحفظ على جهازك.',
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ============ المتابعة ============
          Entrance(
            delay: const Duration(milliseconds: 620),
            child: Column(
              children: [
                PrimaryButton(
                  label: 'متابعة إنشاء الحساب',
                  icon: Icons.arrow_back,
                  onPressed: () => context.go('/onboarding/register'),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => context.go('/onboarding/register'),
                  child: const Text('سأفعّل الأذونات لاحقاً'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============ بطاقة إذن واحدة ============

  Widget _permissionCard(
    BuildContext context, {
    required _PermissionKey key,
    required IconData icon,
    required String title,
    required String description,
    required String actionLabel,
    required Duration entranceDelay,
  }) {
    final theme = Theme.of(context);
    final granted = _statuses[key];
    final isBusy = _busyKey == key;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Entrance(
        delay: entranceDelay,
        child: NapexCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // أيقونة
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: granted == true
                      ? AppColors.success.withValues(alpha: 0.12)
                      : AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  granted == true ? Icons.check_rounded : icon,
                  color: granted == true ? AppColors.success : AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),

              // النصوص + الحالة + الإجراء
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (!_isAndroid)
                          _platformPill()
                        else
                          _statusPill(granted),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_isAndroid)
                      SizedBox(
                        height: 34,
                        child: isBusy
                            ? const Row(
                                children: [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'جارٍ التحقق…',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ],
                              )
                            : OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14),
                                  minimumSize: const Size(0, 34),
                                  side: BorderSide(
                                    color: granted == true
                                        ? theme.colorScheme.outline
                                        : AppColors.primary,
                                  ),
                                  foregroundColor: granted == true
                                      ? AppColors.textSecondary
                                      : AppColors.primary,
                                ),
                                onPressed: granted == true
                                    ? null
                                    : () => _handleAction(key),
                                icon: const Icon(Icons.settings_outlined,
                                    size: 16),
                                label: Text(
                                  granted == true ? 'مفعّل' : actionLabel,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusPill(bool? granted) {
    if (granted == null) {
      return const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    final color = granted ? AppColors.success : AppColors.textDisabled;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        granted ? 'مفعّل' : 'غير مفعّل',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _platformPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'أندرويد فقط',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: AppColors.info,
        ),
      ),
    );
  }
}

enum _PermissionKey { notifications, accessibility, notificationListener, sms }
