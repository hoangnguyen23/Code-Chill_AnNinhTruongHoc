import 'package:campus_core/campus_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/format/formatters.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/report.dart';

/// Thẻ báo cáo trong danh sách.
///
/// Báo cáo khẩn cấp: viền đầy đủ màu đỏ, icon SOS và tiêu đề "KHẨN CẤP: ..." (không lặp lại
/// nhãn mức độ vì khẩn cấp luôn ở mức cao nhất).
class ReportTile extends StatelessWidget {
  const ReportTile({
    super.key,
    required this.code,
    required this.type,
    required this.severity,
    required this.status,
    required this.emergency,
    required this.locationText,
    required this.createdAt,
    required this.onTap,
    this.assigneeName,
    this.showAssignee = false,
    this.showSeverity = true,
  });

  factory ReportTile.fromReport(Report r, {required VoidCallback onTap, bool showAssignee = true}) => ReportTile(
        code: r.code,
        type: r.type,
        severity: r.severity,
        status: r.status,
        emergency: r.emergency,
        locationText: r.locationText,
        createdAt: r.createdAt,
        assigneeName: r.assigneeName,
        showAssignee: showAssignee && (r.assigneeName != null || r.status.isOpen),
        onTap: onTap,
      );

  factory ReportTile.fromSummary(ReportSummary s, {required VoidCallback onTap}) => ReportTile(
        code: s.code,
        type: s.type,
        severity: s.severity,
        status: s.status,
        emergency: s.emergency,
        locationText: s.locationText,
        createdAt: s.createdAt,
        onTap: onTap,
        showSeverity: false,
      );

  final String code;
  final IncidentType type;
  final Severity severity;
  final ReportStatus status;
  final bool emergency;
  final String locationText;
  final DateTime createdAt;
  final String? assigneeName;
  final bool showAssignee;
  final bool showSeverity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = context.palette;
    final muted = theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);
    final title = emergency ? 'KHẨN CẤP: ${type.label}' : type.label;

    return Card(
      shape: emergency
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: palette.emergencyText, width: 1.5),
            )
          : null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    emergency ? Icons.sos_rounded : incidentIcon(type),
                    size: 24,
                    color: emergency ? palette.emergencyText : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: emergency ? palette.emergencyText : null,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          code,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusChip(status),
                ],
              ),
              const SizedBox(height: 12),
              _MetaRow(icon: Icons.place_outlined, text: locationText, style: muted, maxLines: 2),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _MetaRow(icon: Icons.schedule_rounded, text: formatRelative(createdAt), style: muted),
                  ),
                  if (showSeverity && !emergency) ...[const SizedBox(width: 8), SeverityBadge(severity)],
                ],
              ),
              if (showAssignee) ...[
                const SizedBox(height: 6),
                _MetaRow(
                  icon: assigneeName == null ? Icons.person_off_outlined : Icons.assignment_ind_outlined,
                  text: assigneeName == null ? 'Chưa phân công' : 'Xử lý: $assigneeName',
                  style: assigneeName == null && status.isOpen
                      ? theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurface, fontWeight: FontWeight.w600)
                      : muted,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text, required this.style, this.maxLines = 1});

  final IconData icon;
  final String text;
  final TextStyle? style;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: style, maxLines: maxLines, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}
