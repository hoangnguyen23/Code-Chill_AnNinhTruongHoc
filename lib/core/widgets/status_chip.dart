import 'package:campus_core/campus_core.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

IconData statusIcon(ReportStatus s) => switch (s) {
      ReportStatus.submitted => Icons.outbox_rounded,
      ReportStatus.received => Icons.assignment_turned_in_rounded,
      ReportStatus.inProgress => Icons.pending_actions_rounded,
      ReportStatus.resolved => Icons.task_alt_rounded,
      ReportStatus.rejected => Icons.block_rounded,
    };

IconData incidentIcon(IncidentType t) => switch (t) {
      IncidentType.theft => Icons.backpack_rounded,
      IncidentType.fight => Icons.sports_kabaddi_rounded,
      IncidentType.fire => Icons.local_fire_department_rounded,
      IncidentType.suspicious => Icons.person_search_rounded,
      IncidentType.damage => Icons.build_rounded,
      IncidentType.other => Icons.report_rounded,
    };

/// Chip trạng thái: màu tonal + icon + chữ (màu không là tín hiệu duy nhất).
class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key, this.large = false});

  final ReportStatus status;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final fg = palette.statusForeground[status]!;
    final style = (large ? Theme.of(context).textTheme.labelLarge : Theme.of(context).textTheme.labelMedium)
        ?.copyWith(color: fg);
    return Semantics(
      label: 'Trạng thái: ${status.label}',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: large ? 12 : 8, vertical: large ? 6 : 4),
        decoration: BoxDecoration(
          color: palette.statusBackground[status],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(statusIcon(status), size: large ? 18 : 14, color: fg),
            SizedBox(width: large ? 6 : 4),
            Text(status.label, style: style),
          ],
        ),
      ),
    );
  }
}

/// Nhãn mức độ. "Khẩn cấp" dùng nền đỏ đặc.
class SeverityBadge extends StatelessWidget {
  const SeverityBadge(this.severity, {super.key, this.large = false});

  final Severity severity;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final fg = palette.severityForeground[severity]!;
    return Semantics(
      label: 'Mức độ: ${severity.label}',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: large ? 12 : 8, vertical: large ? 6 : 4),
        decoration: BoxDecoration(
          color: palette.severityBackground[severity],
          borderRadius: BorderRadius.circular(8),
          border: severity == Severity.low ? Border.all(color: Theme.of(context).colorScheme.outline) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (severity.rank >= Severity.high.rank) ...[
              Icon(Icons.priority_high_rounded, size: large ? 18 : 14, color: fg),
              const SizedBox(width: 2),
            ],
            Text(
              'Mức độ: ${severity.label}',
              style: (large ? Theme.of(context).textTheme.labelLarge : Theme.of(context).textTheme.labelMedium)
                  ?.copyWith(color: fg),
            ),
          ],
        ),
      ),
    );
  }
}
