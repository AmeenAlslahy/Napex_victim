import 'package:flutter/material.dart';

import 'package:napex_victim_app/core/theme/app_colors.dart';
import 'package:napex_victim_app/domain/entities/report.dart';

/// خط زمني مرئي لحالة القضية — من الإرسال حتى الحل
/// (يُبنى من ReportStatus المتسلسل الموجود — بلا كيانات جديدة)
class CaseTimeline extends StatelessWidget {
  const CaseTimeline({required this.report, super.key});

  final Report report;

  static const List<ReportStatus> _steps = [
    ReportStatus.pending,
    ReportStatus.received,
    ReportStatus.underReview,
    ReportStatus.investigating,
    ReportStatus.resolved,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // موضع الحالة الحالية — حالات خارج الخط (مسودة/مرفوض/فشل/مغلق) تعالج خصيصاً
    final currentIndex = _steps.indexOf(report.status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'مسار القضية',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (report.status == ReportStatus.failed)
          _statusNote(
            theme,
            icon: Icons.error_outline,
            color: AppColors.danger,
            text: report.lastError ?? 'فشل الإرسال — جارٍ إعادة المحاولة تلقائياً',
          )
        else if (report.status == ReportStatus.closed)
          _statusNote(
            theme,
            icon: Icons.lock_outline,
            color: AppColors.textSecondary,
            text: 'أُغلقت القضية',
          )
        else if (report.status == ReportStatus.rejected)
          _statusNote(
            theme,
            icon: Icons.cancel_outlined,
            color: AppColors.danger,
            text: 'لم يُقبل البلاغ',
          )
        else
          Row(
            children: [
              for (var i = 0; i < _steps.length; i++) ...[
                Expanded(
                  child: _step(context, _steps[i], _stateOf(i, currentIndex)),
                ),
                if (i < _steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 3,
                      color: i < currentIndex
                          ? AppColors.success
                          : AppColors.surfaceVariant,
                    ),
                  ),
              ],
            ],
          ),
      ],
    );
  }

  /// حالة كل محطة: منجزة / حالية / منتظرة
  _StepState _stateOf(int index, int currentIndex) {
    if (currentIndex < 0) {
      // قبل أول محطة (مسودة)
      return index == 0 ? _StepState.current : _StepState.pending;
    }
    if (index < currentIndex) return _StepState.done;
    if (index == currentIndex) return _StepState.current;
    return _StepState.pending;
  }

  Widget _step(BuildContext context, ReportStatus status, _StepState state) {
    final color = switch (state) {
      _StepState.done => AppColors.success,
      _StepState.current => AppColors.primary,
      _StepState.pending => AppColors.textDisabled,
    };

    return Column(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: state == _StepState.done
                ? AppColors.success
                : Colors.transparent,
            border: Border.all(color: color, width: 2),
          ),
          child: state == _StepState.done
              ? const Icon(Icons.check, size: 16, color: Colors.white)
              : state == _StepState.current
                  ? Container(
                      margin: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary,
                      ),
                    )
                  : null,
        ),
        const SizedBox(height: 4),
        Text(
          status.labelAr,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 10,
                fontWeight:
                    state == _StepState.current ? FontWeight.bold : null,
                color: state == _StepState.pending
                    ? AppColors.textDisabled
                    : AppColors.textPrimary,
              ),
        ),
      ],
    );
  }

  Widget _statusNote(
    ThemeData theme, {
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

enum _StepState { done, current, pending }
