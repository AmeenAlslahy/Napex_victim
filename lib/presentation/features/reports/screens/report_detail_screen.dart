import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:napex_victim_app/core/theme/app_colors.dart';
import 'package:napex_victim_app/core/utils/extensions.dart';
import 'package:napex_victim_app/domain/entities/evidence.dart';
import 'package:napex_victim_app/domain/entities/report.dart';
import 'package:napex_victim_app/domain/usecases/report/submit_report_usecase.dart';
import 'package:napex_victim_app/presentation/providers/core_providers.dart';
import 'package:uuid/uuid.dart';
import 'package:napex_victim_app/presentation/providers/reports_providers.dart';
import 'package:napex_victim_app/presentation/features/support/screens/trusted_contacts_screen.dart';
import 'package:napex_victim_app/presentation/shared/widgets/case_timeline.dart';
import 'package:napex_victim_app/presentation/shared/widgets/feedback_panel.dart';
import 'package:napex_victim_app/presentation/shared/widgets/napex_card.dart';
import 'package:napex_victim_app/presentation/shared/widgets/primary_button.dart';
import 'package:napex_victim_app/presentation/shared/widgets/risk_badge.dart';
import 'package:napex_victim_app/presentation/shared/widgets/status_chip.dart';

/// شاشة تفاصيل البلاغ — المحتوى + التحليل + الأدلة + الإجراءات
class ReportDetailScreen extends ConsumerStatefulWidget {
  const ReportDetailScreen({required this.reportId, super.key});

  final String reportId;

  @override
  ConsumerState<ReportDetailScreen> createState() =>
      _ReportDetailScreenState();
}

class _ReportDetailScreenState extends ConsumerState<ReportDetailScreen> {
  Report? _report;
  List<Evidence> _evidences = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final report = await ref.read(reportsProvider.notifier).loadById(
          widget.reportId,
        );

    if (report == null) {
      setState(() {
        _error = 'البلاغ غير موجود';
        _loading = false;
      });
      return;
    }

    final (evidences, _) = await ref
        .read(evidenceRepositoryProvider)
        .getEvidencesByReport(report.localId);

    if (mounted) {
      setState(() {
        _report = report;
        _evidences = evidences;
        _loading = false;
      });
    }
  }

  Future<void> _attachEvidence() async {
    final report = _report;
    if (report == null) return;
    setState(() => _busy = true);

    final ok = await ref.read(reportsProvider.notifier).attachEvidence(report);

    setState(() => _busy = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'تم إنشاء دليل مشفر وربطه بالبلاغ' : 'فشل إنشاء الدليل'),
          backgroundColor: ok ? AppColors.success : AppColors.danger,
        ),
      );
      await _load();
    }
  }

  Future<void> _verifyIntegrity() async {
    if (_evidences.isEmpty) return;
    setState(() => _busy = true);

    var allIntact = true;
    for (final evidence in _evidences) {
      final (intact, _) = await ref
          .read(evidenceRepositoryProvider)
          .verifyEvidenceIntegrity(evidence.id);
      if (!intact) allIntact = false;
    }

    setState(() => _busy = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            allIntact
                ? '✓ جميع الأدلة سليمة ومطابقة للهاش'
                : '⚠ تحذير: بعض الأدلة لم تعد مطابقة — لم يُعدَّل شيء',
          ),
          backgroundColor: allIntact ? AppColors.success : AppColors.danger,
        ),
      );
    }
  }

  Future<void> _resubmit() async {
    final report = _report;
    if (report == null) return;
    setState(() => _busy = true);

    final result = await ref
        .read(submitReportUseCaseProvider)
        .call(SubmitReportParams(report: report));

    setState(() => _busy = false);

    if (mounted) {
      result.fold(
        (failure) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل الإرسال: ${failure.message}'),
            backgroundColor: AppColors.danger,
          ),
        ),
        (reportNumber) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تم الإرسال — رقم البلاغ: $reportNumber')),
          );
        },
      );
      await ref.read(reportsProvider.notifier).refreshReport(report.id);
      await _load();
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف البلاغ؟'),
        content: const Text(
          'سيُحذف البلاغ وأدلته نهائياً من هذا الجهاز. لا يمكن التراجع.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref.read(reportsProvider.notifier).delete(widget.reportId);
    if (mounted) context.pop();
  }

  /// مشاركة ملخص البلاغ (مع جهة موثوقة أو أي جهة دعم)
  Future<void> _shareReport(Report report) async {
    final buffer = StringBuffer()
      ..writeln('📋 ملخص بلاغ من تطبيق NAP-EX')
      ..writeln('--------------------------------')
      ..writeln('رقم البلاغ: ${report.reportNumber ?? report.localId}')
      ..writeln('المرسل: ${report.sender.displayName} (${report.sender.raw})')
      ..writeln('المصدر: ${report.source.app.displayName}')
      ..writeln('التصنيف: ${report.analysis.category.labelAr} — '
          'الخطورة: ${report.riskLevel.labelAr} — '
          'الثقة: ${report.analysis.confidence.asPercent}')
      ..writeln('التاريخ: ${report.messageTimestamp.formattedDateTime}')
      ..writeln('--------------------------------')
      ..writeln(report.content)
      ..writeln('--------------------------------')
      ..writeln('أحتاج دعمك — تواصل معي.');
    await shareText(buffer.toString());
  }

  /// حظر شخصي لمرسل هذا البلاغ — يُخزَّن على الجهاز فقط ولا يُرسل للخادم
  Future<void> _blockSenderPersonally(Report report) async {
    final messenger = ScaffoldMessenger.of(context);
    final dao = ref.read(personalBlocklistDaoProvider);
    try {
      final existing = await dao.findByHashOrPhone(
        senderHash: report.sender.senderHash ?? '',
        phone: report.sender.phoneNumber,
      );
      if (existing != null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('المرسل محظور شخصياً بالفعل'),
            backgroundColor: AppColors.warning,
          ),
        );
        return;
      }
      await dao.insert({
        'id': const Uuid().v4(),
        'sender_hash': report.sender.senderHash ?? '',
        'phone_number': report.sender.phoneNumber,
        'display_name': report.sender.displayName,
        'reason': 'user_blocked',
        'added_at': DateTime.now().millisecondsSinceEpoch,
      });
      messenger.showSnackBar(
        const SnackBar(
          content: Text('تم حظر المرسل شخصياً — أي رسالة قادمة منه ستُعامل كابتزاز مؤكد'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('تعذر الحظر — حاول مجدداً'),
          backgroundColor: AppColors.warning,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final report = _report;

    return Scaffold(
      appBar: AppBar(
        title: Text(report?.reportNumber ?? 'تفاصيل البلاغ'),
        actions: [
          IconButton(
            tooltip: 'حذف',
            icon: const Icon(Icons.delete_outline),
            onPressed: _delete,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _busy
                  ? const Center(child: CircularProgressIndicator())
                  : _buildBody(theme, report!),
    );
  }

  Widget _buildBody(ThemeData theme, Report report) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ============ الترويسة ============
        NapexCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      report.sender.displayName,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  StatusChip(status: report.status),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${report.source.app.displayName} • ${report.sender.raw.masked}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'وقت الرسالة: ${report.messageTimestamp.formattedDateTime}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  RiskBadge(riskLevel: report.riskLevel),
                  const Spacer(),
                  Text(
                    'الثقة ${report.analysis.confidence.asPercent}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ============ مسار القضية ============
        NapexCard(child: CaseTimeline(report: report)),
        const SizedBox(height: 14),

        // ============ محتوى الرسالة ============
        NapexCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'محتوى الرسالة',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SelectableText(
                report.content,
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.7),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ============ التحليل ============
        NapexCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'نتيجة التحليل',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip(theme, report.analysis.category.labelAr,
                      AppColors.primary),
                  _chip(theme, 'المحرك: ${report.analysis.analysisEngine}',
                      AppColors.info),
                  if (report.analysis.processingTimeMs > 0)
                    _chip(theme, '${report.analysis.processingTimeMs} ms',
                        AppColors.textSecondary),
                ],
              ),
              if (report.analysis.threatPhrases.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'العبارات المرصودة:',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: report.analysis.threatPhrases
                      .map(
                        (phrase) => Chip(
                          label: Text(
                            phrase,
                            style: const TextStyle(fontSize: 12),
                          ),
                          backgroundColor: AppColors.danger
                              .withValues(alpha: 0.08),
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                      .toList(),
                ),
              ],
              if (report.analysis.recommendations.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.tips_and_updates_outlined,
                              size: 18, color: AppColors.warning),
                          SizedBox(width: 6),
                          Text(
                            'إرشادات',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...report.analysis.recommendations.map(
                        (rec) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• '),
                              Expanded(
                                child: Text(
                                  rec,
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(height: 1.5),
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
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ============ تغذية راجعة + إجراءات الضحية ============
        FeedbackPanel(reportId: report.id),
        const SizedBox(height: 14),

        NapexCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'إجراءات سريعة',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _blockSenderPersonally(report),
                    icon: const Icon(Icons.block_outlined, size: 18),
                    label: const Text('حظر المرسل شخصياً'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/support'),
                    icon: const Icon(Icons.psychology_outlined, size: 18),
                    label: const Text('دعم نفسي'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _shareReport(report),
                    icon: const Icon(Icons.share_outlined, size: 18),
                    label: const Text('مشاركة البلاغ'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/trusted-contacts'),
                    icon: const Icon(Icons.groups_outlined, size: 18),
                    label: const Text('جهاتي الموثوقة'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ============ الأدلة ============
        NapexCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'الأدلة الرقمية (${_evidences.length})',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _attachEvidence,
                    icon: const Icon(Icons.add_link, size: 18),
                    label: const Text('إرفاق دليل'),
                  ),
                ],
              ),
              if (_evidences.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'لا توجد أدلة مرفقة — أرفق دليلاً مشفراً لحفظ نسخة موثقة بالهاش.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                )
              else
                ..._evidences.map(
                  (evidence) => Material(
                    type: MaterialType.transparency,
                    child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Icon(
                      _statusIcon(evidence.status),
                      color: _statusColor(evidence.status),
                    ),
                    title: Text(
                      evidence.status.labelAr,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${evidence.fileHash.substring(0, 20)}… • ${evidence.collectedAt.formattedDateTime}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  ),
                ),
              if (_evidences.isNotEmpty)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: _verifyIntegrity,
                    icon: const Icon(Icons.verified_outlined, size: 18),
                    label: const Text('التحقق من السلامة (الهاش)'),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ============ إجراءات ============
        if (report.status.needsSubmission)
          PrimaryButton(
            label: 'إعادة الإرسال للمنصة',
            icon: Icons.cloud_upload_outlined,
            onPressed: _resubmit,
          ),
        if (report.status.needsSubmission) const SizedBox(height: 8),
        if (report.reportNumber != null)
          NapexCard(
            color: AppColors.success.withValues(alpha: 0.06),
            borderColor: AppColors.success.withValues(alpha: 0.3),
            child: Row(
              children: [
                const Icon(Icons.tag, color: AppColors.success),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'رقم البلاغ الرسمي: ${report.reportNumber}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _chip(ThemeData theme, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  IconData _statusIcon(EvidenceStatus status) => switch (status) {
        EvidenceStatus.collected => Icons.description_outlined,
        EvidenceStatus.hashed => Icons.tag,
        EvidenceStatus.encrypted => Icons.lock,
        EvidenceStatus.uploaded => Icons.cloud_done_outlined,
        EvidenceStatus.verified => Icons.verified,
      };

  Color _statusColor(EvidenceStatus status) => switch (status) {
        EvidenceStatus.collected => AppColors.textSecondary,
        EvidenceStatus.hashed => AppColors.info,
        EvidenceStatus.encrypted => AppColors.primary,
        EvidenceStatus.uploaded => AppColors.success,
        EvidenceStatus.verified => AppColors.success,
      };
}
