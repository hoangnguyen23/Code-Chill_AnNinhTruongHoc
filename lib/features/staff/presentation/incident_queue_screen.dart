import 'package:campus_core/campus_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/network/api_error.dart';
import '../../../core/router/role_navigation.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/application/session.dart';
import '../../campus/campus_info.dart';
import '../../reports/application/report_providers.dart';
import '../../reports/domain/report.dart';
import '../../reports/domain/report_filter.dart';
import '../../reports/presentation/widgets/report_tile.dart';
import '../../safety/broadcasts.dart';

enum QueueMode { open, all }

/// Bộ lọc của màn Sự cố, giữ trong phiên.
class QueueFilterController extends Notifier<ReportFilter> {
  @override
  ReportFilter build() => const ReportFilter();

  void update(ReportFilter f) => state = f;
}

final queueFilterProvider = NotifierProvider<QueueFilterController, ReportFilter>(QueueFilterController.new);

class QueueModeController extends Notifier<QueueMode> {
  @override
  QueueMode build() => QueueMode.open;

  void set(QueueMode m) => state = m;
}

final queueModeProvider = NotifierProvider<QueueModeController, QueueMode>(QueueModeController.new);

/// Hàng đợi sự cố cho bảo vệ và quản trị.
class IncidentQueueScreen extends ConsumerWidget {
  const IncidentQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(queueModeProvider);
    final filter = ref.watch(queueFilterProvider);
    final user = ref.watch(signedInUserProvider);
    final source = mode == QueueMode.open ? ref.watch(openReportsProvider) : ref.watch(reportsSinceProvider(filter.range));

    return Scaffold(
      appBar: AppBar(title: const Text('Sự cố')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.newReport),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Báo cáo'),
      ),
      body: Column(
        children: [
          const BroadcastBanner(padding: EdgeInsets.fromLTRB(16, 8, 16, 0)),
          if (user?.role == UserRole.guard && !user!.onDuty) const _OffDutyBanner(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<QueueMode>(
                segments: const [
                  ButtonSegment(value: QueueMode.open, label: Text('Đang mở'), icon: Icon(Icons.pending_actions_rounded)),
                  ButtonSegment(value: QueueMode.all, label: Text('Tất cả'), icon: Icon(Icons.history_rounded)),
                ],
                selected: {mode},
                onSelectionChanged: (v) => ref.read(queueModeProvider.notifier).set(v.first),
              ),
            ),
          ),
          _FilterBar(mode: mode),
          Expanded(
            child: source.when(
              loading: () => const SkeletonList(),
              error: (e, _) => ErrorState(
                error: e,
                onRetry: () => mode == QueueMode.open
                    ? ref.invalidate(openReportsProvider)
                    : ref.invalidate(reportsSinceProvider(filter.range)),
              ),
              data: (all) {
                final filtered = filter.apply(all, applyRange: mode == QueueMode.all);
                final items = mode == QueueMode.open ? sortForTriage(filtered) : filtered;
                if (items.isEmpty) {
                  return EmptyState(
                    icon: mode == QueueMode.open ? Icons.verified_user_outlined : Icons.filter_alt_off_outlined,
                    title: all.isEmpty && mode == QueueMode.open ? 'Không có sự cố đang mở' : 'Không có sự cố phù hợp',
                    message: all.isEmpty && mode == QueueMode.open
                        ? 'Sự cố mới sẽ hiện ở đây ngay khi được gửi.'
                        : 'Thử bỏ bớt điều kiện lọc.',
                    action: filter.activeCount > 0
                        ? OutlinedButton(
                            onPressed: () =>
                                ref.read(queueFilterProvider.notifier).update(ReportFilter(range: filter.range)),
                            child: const Text('Bỏ lọc'),
                          )
                        : null,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  itemCount: items.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Text(
                        '${items.length} sự cố',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      );
                    }
                    final r = items[i - 1];
                    return ReportTile.fromReport(r, onTap: () => context.push(AppRoutes.report(r.id)));
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.mode});

  final QueueMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(queueFilterProvider);
    final ctrl = ref.read(queueFilterProvider.notifier);
    final buildings = ref.watch(campusInfoProvider).value?.buildings ?? const <String>[];

    String statusLabel() => f.statuses.isEmpty
        ? 'Trạng thái'
        : f.statuses.length == 1
            ? f.statuses.first.label
            : '${f.statuses.length} trạng thái';
    String severityLabel() => f.severities.isEmpty
        ? 'Mức độ'
        : f.severities.length == 1
            ? f.severities.first.label
            : '${f.severities.length} mức độ';

    final statusOptions = mode == QueueMode.open
        ? [ReportStatus.submitted, ReportStatus.received, ReportStatus.inProgress]
        : ReportStatus.values;

    // Cuộn ngang, chiều cao theo nội dung để không cắt chip khi tăng cỡ chữ hệ thống.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          FilterChip(
            label: const Text('Khẩn cấp'),
            avatar: const Icon(Icons.sos_rounded, size: 18),
            selected: f.emergencyOnly,
            onSelected: (v) => ctrl.update(f.copyWith(emergencyOnly: v)),
          ),
          const SizedBox(width: 8),
          _MenuChip<ReportStatus>(
            label: statusLabel(),
            active: f.statuses.isNotEmpty,
            options: statusOptions,
            optionLabel: (s) => s.label,
            selected: f.statuses,
            onChanged: (set) => ctrl.update(f.copyWith(statuses: set)),
          ),
          const SizedBox(width: 8),
          _MenuChip<Severity>(
            label: severityLabel(),
            active: f.severities.isNotEmpty,
            options: Severity.values.reversed.toList(),
            optionLabel: (s) => s.label,
            selected: f.severities,
            onChanged: (set) => ctrl.update(f.copyWith(severities: set)),
          ),
          const SizedBox(width: 8),
          _SingleMenuChip(
            label: f.building ?? 'Khu vực',
            active: f.building != null,
            options: buildings,
            onSelected: (b) => b == null ? ctrl.update(f.copyWith(clearBuilding: true)) : ctrl.update(f.copyWith(building: b)),
          ),
          if (mode == QueueMode.all) ...[
            const SizedBox(width: 8),
            _SingleMenuChip(
              label: f.range.label,
              active: true,
              allowClear: false,
              options: [for (final r in TimeRange.values) r.label],
              onSelected: (label) {
                final r = TimeRange.values.firstWhere((e) => e.label == label, orElse: () => f.range);
                ctrl.update(f.copyWith(range: r));
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// Chip mở sheet chọn nhiều giá trị.
class _MenuChip<T> extends StatelessWidget {
  const _MenuChip({
    required this.label,
    required this.active,
    required this.options,
    required this.optionLabel,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final bool active;
  final List<T> options;
  final String Function(T) optionLabel;
  final Set<T> selected;
  final ValueChanged<Set<T>> onChanged;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: active,
      showCheckmark: false,
      avatar: const Icon(Icons.arrow_drop_down_rounded, size: 18),
      onSelected: (_) async {
        final result = await showModalBottomSheet<Set<T>>(
          context: context,
          builder: (context) => _MultiSelectSheet<T>(
            title: label,
            options: options,
            optionLabel: optionLabel,
            initial: selected,
          ),
        );
        if (result != null) onChanged(result);
      },
    );
  }
}

class _MultiSelectSheet<T> extends StatefulWidget {
  const _MultiSelectSheet({
    required this.title,
    required this.options,
    required this.optionLabel,
    required this.initial,
  });

  final String title;
  final List<T> options;
  final String Function(T) optionLabel;
  final Set<T> initial;

  @override
  State<_MultiSelectSheet<T>> createState() => _MultiSelectSheetState<T>();
}

class _MultiSelectSheetState<T> extends State<_MultiSelectSheet<T>> {
  late final Set<T> _selected = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final o in widget.options)
            CheckboxListTile(
              value: _selected.contains(o),
              title: Text(widget.optionLabel(o)),
              onChanged: (v) => setState(() => v == true ? _selected.add(o) : _selected.remove(o)),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, <T>{}),
                    child: const Text('Bỏ chọn'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, _selected),
                    child: const Text('Áp dụng'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip mở sheet chọn một giá trị.
class _SingleMenuChip extends StatelessWidget {
  const _SingleMenuChip({
    required this.label,
    required this.active,
    required this.options,
    required this.onSelected,
    this.allowClear = true,
  });

  final String label;
  final bool active;
  final List<String> options;
  final ValueChanged<String?> onSelected;
  final bool allowClear;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: active,
      showCheckmark: false,
      avatar: const Icon(Icons.arrow_drop_down_rounded, size: 18),
      onSelected: (_) async {
        const clear = '\u0000';
        final picked = await showModalBottomSheet<String>(
          context: context,
          isScrollControlled: true,
          builder: (context) => SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.6),
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (allowClear)
                    ListTile(
                      leading: const Icon(Icons.clear_all_rounded),
                      title: const Text('Tất cả'),
                      onTap: () => Navigator.pop(context, clear),
                    ),
                  for (final o in options)
                    ListTile(
                      title: Text(o),
                      trailing: o == label ? const Icon(Icons.check_rounded) : null,
                      onTap: () => Navigator.pop(context, o),
                    ),
                ],
              ),
            ),
          ),
        );
        if (picked == null) return;
        onSelected(picked == clear ? null : picked);
      },
    );
  }
}

/// Bảo vệ đang nghỉ ca: nhắc bật "Đang trực" để nhận cảnh báo.
class _OffDutyBanner extends ConsumerStatefulWidget {
  const _OffDutyBanner();

  @override
  ConsumerState<_OffDutyBanner> createState() => _OffDutyBannerState();
}

class _OffDutyBannerState extends ConsumerState<_OffDutyBanner> {
  bool _saving = false;

  Future<void> _goOnDuty() async {
    setState(() => _saving = true);
    try {
      await ref.read(authRepositoryProvider).updateProfile(onDuty: true);
    } on ApiError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSecondaryContainer);
    return Material(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.notifications_off_outlined, color: scheme.onSecondaryContainer, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Bạn đang nghỉ ca nên chỉ nhận thông báo sự cố khẩn cấp. Bật "Đang trực" để nhận mọi sự cố mới.',
                    style: textStyle,
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _saving ? null : _goOnDuty,
                child: Text(_saving ? 'Đang bật…' : 'Bật đang trực'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dùng lại cho màn "Việc của tôi".
List<Report> openFirst(List<Report> reports) {
  final open = sortForTriage(reports.where((r) => r.status.isOpen));
  final closed = reports.where((r) => r.status.isClosed).toList()
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  return [...open, ...closed];
}
