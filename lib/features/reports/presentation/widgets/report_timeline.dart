import 'package:campus_core/campus_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/format/formatters.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/report.dart';

/// Lịch sử xử lý và trao đổi theo thứ tự thời gian.
class ReportTimeline extends StatelessWidget {
  const ReportTimeline({
    super.key,
    required this.events,
    required this.currentUid,
    this.viewerIsAnonymousReporter = false,
  });

  final List<ReportEventItem> events;
  final String? currentUid;

  /// Người xem là người báo của báo cáo ẩn danh: sự kiện ẩn danh của người báo là của chính họ.
  final bool viewerIsAnonymousReporter;

  bool _isMine(ReportEventItem e) =>
      (e.actorUid != null && e.actorUid == currentUid) ||
      (viewerIsAnonymousReporter && e.actorUid == null && e.actorRole == UserRole.reporter);

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Text(
        'Chưa có hoạt động nào.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < events.length; i++)
          _TimelineEntry(event: events[i], isLast: i == events.length - 1, isMine: _isMine(events[i])),
      ],
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({required this.event, required this.isLast, required this.isMine});

  final ReportEventItem event;
  final bool isLast;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final actor = isMine ? 'Bạn' : event.actorName;
    final roleLabel = event.actorRole == UserRole.reporter ? '' : ' (${event.actorRole.label})';

    final (IconData icon, String title) = switch (event.type) {
      ReportEventType.created => (Icons.outbox_rounded, '$actor$roleLabel đã gửi báo cáo'),
      ReportEventType.status => (
          statusIcon(event.toStatus ?? ReportStatus.submitted),
          '$actor$roleLabel chuyển sang "${event.toStatus?.label ?? ''}"',
        ),
      ReportEventType.assigned => (Icons.assignment_ind_rounded, '$actor$roleLabel: ${event.note ?? 'phân công'}'),
      ReportEventType.comment => (Icons.chat_bubble_outline_rounded, '$actor$roleLabel'),
    };
    final body = switch (event.type) {
      ReportEventType.assigned => event.toStatus == null ? null : 'Trạng thái: ${event.toStatus!.label}',
      _ => event.note,
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: scheme.surfaceContainerHighest, shape: BoxShape.circle),
                  child: Icon(icon, size: 18, color: scheme.onSurfaceVariant),
                ),
                if (!isLast) Expanded(child: Container(width: 2, color: scheme.outlineVariant)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20, top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(formatDateTime(event.createdAt), style: muted),
                  if (body != null && body.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: event.type == ReportEventType.comment
                            ? (isMine ? scheme.primaryContainer : scheme.surfaceContainerHigh)
                            : scheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        body,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: event.type == ReportEventType.comment && isMine ? scheme.onPrimaryContainer : null,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
