import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:napex_victim_app/core/constants/app_constants.dart';
import 'package:napex_victim_app/core/constants/security_constants.dart';
import 'package:napex_victim_app/core/theme/app_colors.dart';
import 'package:napex_victim_app/domain/entities/app_source.dart';
import 'package:napex_victim_app/domain/repositories/settings_repository.dart';
import 'package:napex_victim_app/presentation/providers/auth_providers.dart';
import 'package:napex_victim_app/presentation/providers/collector_providers.dart';
import 'package:napex_victim_app/presentation/providers/content_safety_providers.dart';
import 'package:napex_victim_app/presentation/providers/core_providers.dart';
import 'package:napex_victim_app/presentation/providers/reports_providers.dart';
import 'package:napex_victim_app/presentation/providers/settings_providers.dart';
import 'package:napex_victim_app/presentation/shared/widgets/napex_card.dart';

const String _parentalPinKey = SecurityConstants.keyParentalPin;

/// شاشة الإعدادات — كل الأقسام + القفل الأبوي على إعدادات الحماية
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Future<bool> _ensurePinAllowed() async {
    final messenger = ScaffoldMessenger.of(context);
    final storage = ref.read(secureStorageProvider);
    final stored = await storage.readString(_parentalPinKey);
    if (stored == null || stored.isEmpty) return true;
    if (!mounted) return false;

    final entered = await _promptPin('أدخل القفل الأبوي');
    if (entered == null || !mounted) return false;
    final ok =
        crypto.sha256.convert(utf8.encode(entered)).toString() == stored;
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('القفل الأبوي غير صحيح')),
      );
    }
    return ok;
  }

  Future<void> _setParentalPin() async {
    final messenger = ScaffoldMessenger.of(context);
    final storage = ref.read(secureStorageProvider);
    final existing = await storage.readString(_parentalPinKey);
    if (!mounted) return;

    final entered = await _promptPin(
      existing == null
          ? 'اضبط قفلاً أبوياً (4-6 أرقام)'
          : 'أدخل القفل الحالي للتغيير',
    );
    if (entered == null || !mounted) return;

    if (existing != null &&
        existing !=
            crypto.sha256.convert(utf8.encode(entered)).toString()) {
      messenger.showSnackBar(
        const SnackBar(content: Text('القفل الحالي غير صحيح')),
      );
      return;
    }

    final confirm = await _promptPin('أعد إدخال القفل للتأكيد');
    if (confirm == null || !mounted) return;
    if (confirm != entered) {
      messenger.showSnackBar(
        const SnackBar(content: Text('غير متطابق — لم يُحفظ القفل')),
      );
      return;
    }

    await storage.writeString(
      _parentalPinKey,
      crypto.sha256.convert(utf8.encode(confirm)).toString(),
    );
    ref.invalidate(parentalPinSetProvider);
    if (mounted) {
      messenger.showSnackBar(
        const SnackBar(content: Text('تم ضبط القفل الأبوي')),
      );
    }
  }

  Future<String?> _promptPin(String title) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(hintText: '••••'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final collector = ref.watch(collectorProvider);
    final safety = ref.watch(contentSafetyProvider);
    final reports = ref.watch(reportsProvider);
    final pinSet = ref.watch(parentalPinSetProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ============ الحماية ============
          _sectionTitle(context, 'الحماية'),
          NapexCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.shield_outlined,
                      color: AppColors.primary),
                  title: const Text('الحماية التلقائية'),
                  subtitle: const Text('تحليل الرسائل الواردة وكشف الابتزاز'),
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
                _divider(),
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_outlined,
                      color: AppColors.primary),
                  title: const Text('الإشعارات'),
                  subtitle: const Text('تنبيه فوري عند اكتشاف رسالة خطيرة'),
                  value: settings.notificationsEnabled,
                  onChanged: (value) => ref
                      .read(settingsProvider.notifier)
                      .setNotificationsEnabled(value),
                ),
                _divider(),
                SwitchListTile(
                  secondary: const Icon(Icons.drive_file_rename_outline,
                      color: AppColors.primary),
                  title: const Text('الإبلاغ التلقائي'),
                  subtitle: const Text('إنشاء بلاغ تلقائي عند تأكد الابتزاز'),
                  value: settings.autoReport,
                  onChanged: (value) =>
                      ref.read(settingsProvider.notifier).setAutoReport(value),
                ),
                _divider(),
                SwitchListTile(
                  secondary: const Icon(Icons.auto_delete_outlined,
                      color: AppColors.primary),
                  title: const Text('حذف الرسائل القديمة'),
                  subtitle: const Text('حذف الرسائل غير المبلَّغة بعد 30 يوماً'),
                  value: settings.autoDeleteOldMessages,
                  onChanged: (value) => ref
                      .read(settingsProvider.notifier)
                      .setAutoDeleteOldMessages(value),
                ),
                _divider(),
                ListTile(
                  leading: const Icon(Icons.tune_outlined,
                      color: AppColors.primary),
                  title: const Text('حساسية الكشف'),
                  subtitle: Text(
                    settings.sensitivity.labelAr,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                  trailing: SizedBox(
                    width: 120,
                    child: DropdownButtonFormField<DetectionSensitivity>(
                      initialValue: settings.sensitivity,
                      items: DetectionSensitivity.values
                          .map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(
                                  s == DetectionSensitivity.low
                                      ? 'منخفضة'
                                      : s == DetectionSensitivity.medium
                                          ? 'متوسطة'
                                          : 'عالية',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          ref
                              .read(settingsProvider.notifier)
                              .setSensitivity(value);
                        }
                      },
                    ),
                  ),
                ),
                _divider(),
                SwitchListTile(
                  secondary: const Icon(Icons.do_not_disturb_outlined,
                      color: AppColors.primary),
                  title: const Text('تنبيهات فورية'),
                  subtitle: Text(
                    settings.notificationMode == NotificationMode.immediate
                        ? 'إشعار فوري عند كل اكتشاف'
                        : 'صامتة — الحفظ في السجل فقط',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                  value:
                      settings.notificationMode == NotificationMode.immediate,
                  onChanged: (value) => ref
                      .read(settingsProvider.notifier)
                      .setNotificationMode(
                        value
                            ? NotificationMode.immediate
                            : NotificationMode.silent,
                      ),
                ),
                _divider(),
                ListTile(
                  leading: const Icon(Icons.schedule_outlined,
                      color: AppColors.primary),
                  title: const Text('ساعات الحماية'),
                  subtitle: Text(
                    settings.isFullDay
                        ? 'مفعّلة 24 ساعة'
                        : 'من ${settings.protectionStartHour}:00 إلى ${settings.protectionEndHour}:00',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                  trailing: SizedBox(
                    width: 160,
                    child: Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            isExpanded: true,
                            initialValue: settings.protectionStartHour,
                            items: List.generate(25, (h) => h)
                                .map((h) => DropdownMenuItem(
                                      value: h,
                                      child: Text('$h',
                                          style: const TextStyle(
                                              fontSize: 12)),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                ref
                                    .read(settingsProvider.notifier)
                                    .setProtectionHours(
                                      start: value,
                                      end: settings.protectionEndHour,
                                    );
                              }
                            },
                          ),
                        ),
                        const Text('—',
                            style: TextStyle(
                                color: AppColors.textSecondary)),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            isExpanded: true,
                            initialValue: settings.protectionEndHour,
                            items: List.generate(25, (h) => h)
                                .map((h) => DropdownMenuItem(
                                      value: h,
                                      child: Text('$h',
                                          style: const TextStyle(
                                              fontSize: 12)),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                ref
                                    .read(settingsProvider.notifier)
                                    .setProtectionHours(
                                      start: settings.protectionStartHour,
                                      end: value,
                                    );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ============ المظهر والتطبيقات ============
          _sectionTitle(context, 'المظهر والتطبيقات'),
          NapexCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.dark_mode_outlined,
                      color: AppColors.primary),
                  title: const Text('المظهر'),
                  subtitle: Text(
                    settings.themeMode == 'dark'
                        ? 'داكن'
                        : settings.themeMode == 'light'
                            ? 'فاتح'
                            : 'حسب النظام',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                  trailing: SizedBox(
                    width: 110,
                    child: DropdownButtonFormField<String>(
                      initialValue: settings.themeMode,
                      items: const [
                        DropdownMenuItem(
                            value: 'system', child: Text('النظام')),
                        DropdownMenuItem(
                            value: 'light', child: Text('فاتح')),
                        DropdownMenuItem(value: 'dark', child: Text('داكن')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          ref
                              .read(settingsProvider.notifier)
                              .setThemeMode(value);
                        }
                      },
                    ),
                  ),
                ),
                _divider(),
                ListTile(
                  leading: const Icon(Icons.apps_outlined,
                      color: AppColors.primary),
                  title: const Text('التطبيقات المُراقَبة'),
                  subtitle: Text(
                    settings.monitoredPackages.isEmpty
                        ? 'كل التطبيقات المدعومة'
                        : '${settings.monitoredPackages.length} تطبيق محدد',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: _editMonitoredApps,
                ),
                _divider(),
                SwitchListTile(
                  secondary: const Icon(Icons.location_on_outlined,
                      color: AppColors.primary),
                  title: const Text('موقع الطوارئ'),
                  subtitle: const Text(
                    'إرفاق الموقع برسالة الطوارئ عند التفعيل — معطل افتراضياً',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                  value: settings.shareLocationOnPanic,
                  onChanged: (value) => ref
                      .read(settingsProvider.notifier)
                      .setShareLocationOnPanic(value),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ============ حماية المحتوى ============
          _sectionTitle(context, 'حماية المحتوى'),
          NapexCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.link_off_outlined,
                      color: AppColors.danger),
                  title: const Text('فلترة روابط المتصفح'),
                  subtitle: Text(
                    'حجب فوري عند فتح موقع محجوب — تعمل مع أي VPN '
                    '${settings.urlFilterEnabled ? '(مفعّلة)' : '(معطّلة)'}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                  value: settings.urlFilterEnabled,
                  onChanged: (value) async {
                    if (!await _ensurePinAllowed()) return;
                    await ref
                        .read(settingsProvider.notifier)
                        .setUrlFilterEnabled(value);
                    await ref
                        .read(contentSafetyProvider.notifier)
                        .setUrlFilterEnabled(value);
                  },
                ),
                _divider(),
                SwitchListTile(
                  secondary: const Icon(Icons.block_outlined,
                      color: AppColors.danger),
                  title: const Text('فلترة المواقع الإباحية'),
                  subtitle: Text(
                    safety.webFilterRunning
                        ? 'نشطة — ${safety.blocklistSize} نطاق محجوب'
                        : 'VPN محلي لفلترة DNS — معطل',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                  isThreeLine: true,
                  value: safety.webFilterRunning,
                  onChanged: (value) async {
                    if (!await _ensurePinAllowed()) return;
                    final controller =
                        ref.read(contentSafetyProvider.notifier);
                    if (value) {
                      final vpn = await controller.prepareVpn();
                      if (vpn == 'consent_needed' && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'اسمح بـ VPN في نافذة النظام ثم أعد التفعيل'),
                          ),
                        );
                        return;
                      }
                      if (vpn == 'unavailable' && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('متاحة على أندرويد فقط'),
                          ),
                        );
                        return;
                      }
                      await controller.startWebFilter();
                    } else {
                      await controller.stopWebFilter();
                    }
                  },
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Text(
                    'وضع صارم اختياري — يستبدل أي VPN آخر أثناء عمله. '
                    'للتوافق مع VPN المستخدم اعتمد "فلترة روابط المتصفح" أعلاه.',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                ),
                _divider(),
                SwitchListTile(
                  secondary: const Icon(Icons.visibility_off_outlined,
                      color: AppColors.danger),
                  title: const Text('حرس المحتوى (NSFW)'),
                  subtitle: Text(
                    safety.detectorAvailable
                        ? 'حجب تلقائي عند فتح محتوى غير لائق'
                        : 'النموذج غير مضمّن في هذا البناء',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                  value: safety.guardEnabled && safety.detectorAvailable,
                  onChanged: safety.detectorAvailable
                      ? (value) async {
                          if (!await _ensurePinAllowed()) return;
                          if (value) {
                            // بدون صلاحية "العرض فوق التطبيقات" لا يظهر الحاجب
                            final can =
                                await ref
                                    .read(contentSafetyProvider.notifier)
                                    .canDrawOverlays();
                            if (!context.mounted) return;
                            if (!can) {
                              final go = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('صلاحية مطلوبة'),
                                  content: const Text(
                                    'لإغلاق المحتوى غير اللائق يحتاج التطبيق '
                                    'صلاحية "العرض فوق التطبيقات". '
                                    'افتح الإعدادات وامنحها ثم أعد التفعيل.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('لاحقاً'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('فتح الإعدادات'),
                                    ),
                                  ],
                                ),
                              );
                              if (go == true && context.mounted) {
                                await ref
                                    .read(contentSafetyProvider.notifier)
                                    .openOverlaySettings();
                              }
                              return;
                            }
                          }
                          await ref
                              .read(contentSafetyProvider.notifier)
                              .setGuardEnabled(value);
                          await ref
                              .read(settingsProvider.notifier)
                              .setWebGuardEnabled(value);
                        }
                      : null,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.fact_check_outlined, size: 18),
                          label: const Text('فحص فلتر المواقع',
                              overflow: TextOverflow.ellipsis),
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final r = await ref
                                .read(contentSafetyProvider.notifier)
                                .selfTestWebFilter();
                            if (!mounted) return;
                            final ok = r != null &&
                                (r['blockedOk'] == true) &&
                                (r['allowedOk'] == true);
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  r == null
                                      ? 'الفحص غير متاح على هذه المنصة'
                                      : ok
                                          ? 'الفلتر يعمل: ${r['size']} نطاق — '
                                              'المحجوب يُحجب والمسموح يُمرر ✓'
                                          : 'خلل في الفلتر — أعد تفعيله',
                                ),
                                backgroundColor: ok
                                    ? AppColors.success
                                    : AppColors.warning,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.psychology_outlined, size: 18),
                          label: const Text('فحص محرك الكشف',
                              overflow: TextOverflow.ellipsis),
                          onPressed: () async {
                            final (result, failure) = await ref
                                .read(mlRepositoryProvider)
                                .classifyText(
                                  'عندي صورك وادفع والا سارسلها لعائلتك',
                                );
                            if (!mounted) return;
                            final ok = result != null && result.isExtortion;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  result == null
                                      ? 'تعذر الفحص: ${failure?.message ?? ''}'
                                      : ok
                                          ? 'المحرك يعمل: '
                                              '${result.category.labelAr} '
                                              'بثقة ${(result.confidence * 100).toStringAsFixed(0)}% ✓'
                                          : 'نتيجة غير متوقعة: '
                                              '${result.category.labelAr} '
                                              '(${(result.confidence * 100).toStringAsFixed(0)}%)',
                                ),
                                backgroundColor: ok
                                    ? AppColors.success
                                    : AppColors.warning,
                              ),
                            );
                          },
                        ),
                      ),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.image_search_outlined,
                              size: 18),
                          label: const Text('فحص كاشف الصور',
                              overflow: TextOverflow.ellipsis),
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final r = await ref
                                .read(contentSafetyProvider.notifier)
                                .selfTestNsfw();
                            if (!mounted) return;
                            final ok = r != null &&
                                r['available'] == true &&
                                ((r['sfw'] as num?) ?? 0) > 0.5;
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  r == null || r['available'] != true
                                      ? 'الكاشف غير متاح في هذا البناء'
                                      : ok
                                          ? 'الكاشف يعمل — صورة محايدة: '
                                              'sfw=${((r['sfw'] as num) * 100).toStringAsFixed(0)}% ✓'
                                          : 'نتيجة غير متوقعة: $r',
                                ),
                                backgroundColor: ok
                                    ? AppColors.success
                                    : AppColors.warning,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                _divider(),
                ListTile(
                  leading: const Icon(Icons.lock_person_outlined,
                      color: AppColors.primary),
                  title: const Text('القفل الأبوي (PIN)'),
                  subtitle: pinSet.when(
                    data: (set) => Text(
                      set
                          ? 'مضبوط — يحمي إعدادات الحماية'
                          : 'غير مضبوط — اضبطه لحماية الإعدادات',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                    loading: () => const Text('…'),
                    error: (_, _) => const Text('—'),
                  ),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: _setParentalPin,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ============ الخدمات ============
          _sectionTitle(context, 'الخدمات المطلوبة'),
          NapexCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _statusTile(
                  context,
                  icon: Icons.accessibility_new_outlined,
                  title: 'خدمة إمكانية الوصول',
                  enabled: collector.accessibilityEnabled,
                  onOpen: () async {
                    await ref
                        .read(collectorRepositoryProvider)
                        .openAccessibilitySettings();
                  },
                ),
                _divider(),
                _statusTile(
                  context,
                  icon: Icons.mark_email_read_outlined,
                  title: 'خدمة الاستماع للإشعارات',
                  enabled: collector.notificationListenerEnabled,
                  onOpen: () async {
                    await ref
                        .read(collectorRepositoryProvider)
                        .openNotificationSettings();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ============ البيانات ============
          _sectionTitle(context, 'البيانات'),
          NapexCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.sync_outlined),
                  title: const Text('إرسال البلاغات المعلقة الآن'),
                  subtitle: Text(
                    '${reports.pendingCount} بلاغ في الانتظار',
                    style: theme.textTheme.bodySmall,
                  ),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => ref.read(reportsProvider.notifier).sync(),
                ),
                _divider(),
                ListTile(
                  leading: const Icon(Icons.table_view_outlined,
                      color: AppColors.primary),
                  title: const Text('تصدير البلاغات (CSV)'),
                  subtitle: const Text('جدول يفتح في Excel — يدعم العربية'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: _exportReportsCsv,
                ),
                _divider(),
                ListTile(
                  leading: const Icon(Icons.file_download_outlined,
                      color: AppColors.primary),
                  title: const Text('تصدير بياناتي (JSON)'),
                  subtitle: const Text('كل بلاغاتك — حقك في الوصول لبياناتك'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: _exportMyData,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ============ الدعم والخصوصية ============
          _sectionTitle(context, 'الدعم والخصوصية'),
          NapexCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.psychology_outlined,
                      color: AppColors.secondary),
                  title: const Text('الدعم النفسي'),
                  subtitle: const Text('خطوط دعم + تمرين تنفس مهدئ'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => context.push('/support'),
                ),
                _divider(),
                ListTile(
                  leading: const Icon(Icons.block_outlined,
                      color: AppColors.primary),
                  title: const Text('الحظر الشخصي'),
                  subtitle: const Text('أرقام تحظرها بنفسك — تُفحص تلقائياً'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => context.push('/personal-blocklist'),
                ),
                _divider(),
                ListTile(
                  leading: const Icon(Icons.groups_outlined,
                      color: AppColors.primary),
                  title: const Text('جهات الاتصال الموثوقة'),
                  subtitle: const Text('تُستخدم في وضع الطوارئ'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => context.push('/trusted-contacts'),
                ),
                _divider(),
                ListTile(
                  leading: const Icon(Icons.history_outlined,
                      color: AppColors.primary),
                  title: const Text('سجل النشاط'),
                  subtitle: const Text('كل ما حدث في التطبيق موثق'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => context.push('/activity'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ============ الحساب ============
          _sectionTitle(context, 'الحساب'),
          NapexCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading:
                  const Icon(Icons.logout, color: AppColors.danger),
              title: const Text('تسجيل الخروج'),
              onTap: _confirmLogout,
            ),
          ),
          const SizedBox(height: 24),

          // ============ حول التطبيق ============
          NapexCard(
            color: AppColors.primary.withValues(alpha: 0.04),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.shield_outlined,
                        color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      AppConstants.appName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${AppConstants.appNameAr} • الإصدار ${AppConstants.appVersion}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  'كل البيانات مشفرة على جهازك — لا يُرسل إلا ما توافق عليه',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============ الحظر الشخصي (حوار) ============

  Future<void> _editMonitoredApps() async {
    final settings = ref.read(settingsProvider);
    final selected = {...settings.monitoredPackages};
    final messenger = ScaffoldMessenger.of(context);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('التطبيقات المُراقَبة'),
          content: SizedBox(
            width: 320,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Text(
                    'اتركها فارغة لمراقبة كل التطبيقات المدعومة',
                    style: Theme.of(dialogContext).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  for (final source in AppSource.values)
                    if (source != AppSource.unknown)
                      CheckboxListTile(
                        dense: true,
                        title: Text(source.displayName),
                        subtitle: Text(
                          source.nativePackage,
                          style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary),
                        ),
                        value: selected.contains(source.nativePackage),
                        onChanged: (checked) {
                          setDialogState(() {
                            if (checked == true) {
                              selected.add(source.nativePackage);
                            } else {
                              selected.remove(source.nativePackage);
                            }
                          });
                        },
                      ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                ref
                    .read(settingsProvider.notifier)
                    .setMonitoredPackages(selected);
                Navigator.pop(dialogContext);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    messenger.showSnackBar(
      SnackBar(content: Text('حُفظت القائمة: ${selected.length} تطبيق')),
    );
  }

  // ============ التصدير ============

  Future<void> _exportReportsCsv() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final reports = ref.read(reportsProvider).reports;
      if (reports.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('لا توجد بلاغات للتصدير')),
        );
        return;
      }

      final buffer = StringBuffer('\uFEFF')
        ..writeln(
            'report_number,sender,source_app,category,risk_level,status,created_at,content');
      for (final report in reports) {
        buffer.writeln([
          report.reportNumber ?? '',
          report.sender.displayName,
          report.source.app.nativePackage,
          report.analysis.category.value,
          report.riskLevel.value,
          report.status.value,
          report.createdAt.toIso8601String(),
          '"${report.content.replaceAll('"', '""')}"',
        ].join(','));
      }

      final docs = await getApplicationDocumentsDirectory();
      final file = File('${docs.path}/napex_reports.csv');
      await file.writeAsString(buffer.toString(), flush: true);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        text: 'بلاغاتي من تطبيق NAP-EX',
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('تعذر التصدير')),
      );
    }
  }

  Future<void> _exportMyData() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final json = await ref.read(victimApiProvider).exportMyData();
      final docs = await getApplicationDocumentsDirectory();
      final file = File('${docs.path}/napex_my_data.json');
      await file.writeAsString(json, flush: true);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        text: 'نسخة بياناتي من تطبيق NAP-EX',
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
            content: Text('تعذر التصدير — تحقق من الاتصال بالخادم')),
      );
    }
  }

  // ============ تأكيدات ============

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تسجيل الخروج؟'),
        content: const Text(
            'ستحتاج لتسجيل الدخول مرة أخرى. الحماية س تتوقف حتى العودة.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('خروج'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(collectorProvider.notifier).stop();
      await ref.read(authProvider.notifier).logout();
    }
  }

  // ============ Widgets المساعدة ============

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
      ),
    );
  }

  Widget _divider() => const Divider(height: 1, indent: 16, endIndent: 16);

  Widget _statusTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required bool enabled,
    required Future<void> Function() onOpen,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        enabled ? 'مفعّلة ✓' : 'غير مفعّلة — اضغط للتفعيل',
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
        ),
      ),
      trailing: const Icon(Icons.chevron_left),
      onTap: onOpen,
    );
  }
}
