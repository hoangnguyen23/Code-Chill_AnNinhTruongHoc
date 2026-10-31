import 'package:campus_core/campus_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/format/formatters.dart';
import '../../../core/router/role_navigation.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/state_views.dart';
import '../../reports/application/report_providers.dart';
import '../../reports/domain/report_filter.dart';
import '../../safety/broadcasts.dart';
import '../../staff/presentation/incident_queue_screen.dart';
import '../data/admin_repository.dart';

class _RangeController extends Notifier<TimeRange> {
  @override
  TimeRange build() => TimeRange.month;

  void set(TimeRange r) => state = r;
}

final _dashboardRangeProvider = NotifierProvider<_RangeController, TimeRange>(_RangeController.new);

/// Thống kê cho quản trị, tính từ dữ liệu thật trong khoảng thời gian đã chọn.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(_dashboardRangeProvider);
    final reports = ref.watch(reportsSinceProvider(range));
    final staff = ref.watch(staffProvider).value;
    final onDuty = staff?.where((u) => u.active && u.role == UserRole.guard && u.onDuty).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tổng quan'),
        actions: [
          IconButton(
            tooltip: 'Gửi cảnh báo toàn trường',
            onPressed: () => context.push(AppRoutes.broadcasts),
            icon: const Icon(Icons.campaign_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const BroadcastBanner(padding: EdgeInsets.only(bottom: 16)),
          SegmentedButton<TimeRange>(
            segments: [for (final r in TimeRange.values) ButtonSegment(value: r, label: Text(r.label))],
            selected: {range},
            showSelectedIcon: false,
            onSelectionChanged: (v) => ref.read(_dashboardRangeProvider.notifier).set(v.first),
          ),
          const SizedBox(height: 16),
          reports.when(
            loading: () => const SizedBox(height: 400, child: SkeletonList(count: 3, padding: EdgeInsets.zero)),
            error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(reportsSinceProvider(range))),
            data: (items) {
              final stats = ReportStats.compute(items);
              if (stats.total == 0) {
                return EmptyState(
                  icon: Icons.insights_outlined,
                  title: 'Chưa có báo cáo trong ${range.label.toLowerCase()}',
                  message: 'Thống kê sẽ hiện khi có báo cáo.',
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SummaryPanel(
                    stats: stats,
                    onOpenTap: () {
                      ref.read(queueModeProvider.notifier).set(QueueMode.open);
                      context.go(AppRoutes.queue);
                    },
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.timer_outlined),
                      title: Text(stats.averageTimeToClose == null
                          ? 'Chưa đủ dữ liệu thời gian giải quyết'
                          : 'Giải quyết trung bình sau ${formatDuration(stats.averageTimeToClose!)}'),
                      subtitle: onDuty == null ? null : Text('Bảo vệ đang trực: $onDuty'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _Breakdown(
                    title: 'Theo trạng thái',
                    entries: [for (final s in ReportStatus.values) (s.label, stats.byStatus[s]!)],
                    total: stats.total,
                  ),
                  _Breakdown(
                    title: 'Theo loại sự cố',
                    entries: ([for (final t in IncidentType.values) (t.label, stats.byType[t]!)]
                          ..sort((a, b) => b.$2.compareTo(a.$2)))
                        .where((e) => e.$2 > 0)
                        .toList(),
                    total: stats.total,
                  ),
                  _Breakdown(
                    title: 'Theo mức độ',
                    entries: [for (final s in Severity.values.reversed) (s.label, stats.bySeverity[s]!)],
                    total: stats.total,
                  ),
                  _Breakdown(
                    title: 'Khu vực nhiều sự cố nhất',
                    entries: [for (final e in stats.byBuilding.entries.take(6)) (e.key, e.value)],
                    total: stats.total,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Bảng tóm tắt một khối (không phải lưới thẻ giống nhau). Chữ đỏ chỉ xuất hiện khi còn sự cố
/// khẩn cấp chưa đóng.
class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({required this.stats, required this.onOpenTap});

  final ReportStats stats;
  final VoidCallback onOpenTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final urgent = stats.openEmergencyCount > 0;
    final cells = [
      _Stat(label: 'Tổng báo cáo', value: '${stats.total}'),
      _Stat(
        label: 'Đang mở',
        value: '${stats.openCount}',
        note: stats.unassignedOpen > 0 ? '${stats.unassignedOpen} chưa phân công' : null,
        onTap: onOpenTap,
      ),
      _Stat(label: 'Đã giải quyết', value: '${stats.resolvedCount}'),
      _Stat(
        label: 'Khẩn cấp',
        value: '${stats.emergencyCount}',
        note: urgent ? '${stats.openEmergencyCount} chưa đóng' : null,
        valueColor: urgent ? context.palette.emergencyText : null,
      ),
    ];
    Widget row(List<Widget> items) => IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: items[0]),
              VerticalDivider(width: 1, color: scheme.outlineVariant),
              Expanded(child: items[1]),
            ],
          ),
        );
    return Card(
      child: Column(
        children: [
          row(cells.sublist(0, 2)),
          Divider(height: 1, color: scheme.outlineVariant),
          row(cells.sublist(2, 4)),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.note, this.valueColor, this.onTap});

  final String label;
  final String value;
  final String? note;
  final Color? valueColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '$label: $value${note == null ? '' : ', $note'}',
      button: onTap != null,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: valueColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (note != null)
                Text(
                  note!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: valueColor ?? theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Phân rã theo nhóm: nhãn, số lượng, thanh tỉ lệ (không có rãnh nền).
class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.title, required this.entries, required this.total});

  final String title;
  final List<(String, int)> entries;
  final int total;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final max = entries.map((e) => e.$2).fold<int>(0, (a, b) => a > b ? a : b);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title),
          for (final (label, count) in entries)
            Semantics(
              label: '$label: $count báo cáo',
              excludeSemantics: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 128,
                      child: Text(label, style: theme.textTheme.bodyMedium, overflow: TextOverflow.ellipsis),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, c) => Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            height: 10,
                            width: max == 0 ? 0 : (c.maxWidth * count / max).clamp(count > 0 ? 4.0 : 0.0, c.maxWidth),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 72,
                      child: Text(
                        '$count (${total == 0 ? 0 : (count * 100 / total).round()}%)',
                        textAlign: TextAlign.right,
                        style: theme.textTheme.bodySmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
