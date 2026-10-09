import 'package:flutter/material.dart';

import 'package:napex_victim_app/domain/entities/report.dart';

/// شارة حالة البلاغ
class StatusChip extends StatelessWidget {
  const StatusChip({required this.status, super.key});

  final ReportStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (status) {
      ReportStatus.draft => (Colors.grey, Icons.edit_note),
      ReportStatus.pending => (Colors.amber.shade700, Icons.schedule),
      ReportStatus.failed => (Colors.red.shade700, Icons.error_outline),
      ReportStatus.submitted ||
      ReportStatus.received =>
        (Colors.blue.shade700, Icons.send),
      ReportStatus.underReview ||
      ReportStatus.investigating =>
        (Colors.deepPurple.shade400, Icons.search),
      ReportStatus.resolved => (Colors.green.shade700, Icons.check_circle),
      ReportStatus.closed => (Colors.grey.shade600, Icons.lock),
      ReportStatus.rejected => (Colors.red.shade400, Icons.cancel),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            status.labelAr,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
