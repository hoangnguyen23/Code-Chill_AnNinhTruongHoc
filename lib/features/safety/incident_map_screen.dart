import 'dart:async';

import 'package:campus_core/campus_core.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format/formatters.dart';
import '../../core/network/api_error.dart';
import '../../core/router/role_navigation.dart';
import '../../core/services/location_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/status_chip.dart';
import '../reports/application/report_providers.dart';
import '../reports/domain/report.dart';
import 'walks.dart';

/// Tâm bản đồ khi chưa có điểm nào và chưa lấy được GPS (TP. Hồ Chí Minh).
const _fallbackCenter = LatLng(10.7769, 106.7009);

class _MapLayers extends Notifier<({bool reports, bool walks})> {
  @override
  ({bool reports, bool walks}) build() => (reports: true, walks: true);

  void toggleReports() => state = (reports: !state.reports, walks: state.walks);

  void toggleWalks() => state = (reports: state.reports, walks: !state.walks);
}

final _mapLayersProvider = NotifierProvider<_MapLayers, ({bool reports, bool walks})>(_MapLayers.new);

/// Bản đồ cho bảo vệ/quản trị: sự cố đang mở (màu theo mức độ) và người đang "Đi cùng tôi".
class IncidentMapScreen extends ConsumerStatefulWidget {
  const IncidentMapScreen({super.key});

  @override
  ConsumerState<IncidentMapScreen> createState() => _IncidentMapScreenState();
}

class _IncidentMapScreenState extends ConsumerState<IncidentMapScreen> {
  final _map = MapController();
  bool _fitted = false;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Cập nhật đếm ngược của người đang đi.
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _map.dispose();
    super.dispose();
  }

  void _fitTo(List<LatLng> points) {
    if (points.isEmpty) return;
    if (points.length == 1) {
      _map.move(points.single, 17);
    } else {
      _map.fitCamera(CameraFit.coordinates(coordinates: points, padding: const EdgeInsets.all(56), maxZoom: 18));
    }
  }

  Future<void> _goToMe() async {
    try {
      final at = await ref.read(locationServiceProvider).current();
      _map.move(LatLng(at.latitude, at.longitude), 17);
    } on LocationException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final layers = ref.watch(_mapLayersProvider);
    final reportsAsync = ref.watch(openReportsProvider);
    final walksAsync = ref.watch(activeWalksProvider);
    final reports = (reportsAsync.value ?? const <Report>[]).where((r) => r.hasCoordinates).toList();
    final walks = walksAsync.value ?? const <Walk>[];
    final located = walks.where((w) => w.hasLocation).toList();
    final noCoords = (reportsAsync.value ?? const <Report>[]).length - reports.length;

    final points = [
      if (layers.reports) for (final r in reports) LatLng(r.latitude!, r.longitude!),
      if (layers.walks) for (final w in located) LatLng(w.latitude!, w.longitude!),
    ];
    if (!_fitted && points.isNotEmpty && reportsAsync.hasValue && walksAsync.hasValue) {
      _fitted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitTo(points));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bản đồ'),
        actions: [
          IconButton(
            tooltip: 'Xem tất cả điểm',
            onPressed: points.isEmpty ? null : () => _fitTo(points),
            icon: const Icon(Icons.zoom_out_map_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                FilterChip(
                  avatar: const Icon(Icons.report_rounded, size: 18),
                  label: Text('Sự cố đang mở (${reports.length})'),
                  selected: layers.reports,
                  onSelected: (_) => ref.read(_mapLayersProvider.notifier).toggleReports(),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  avatar: const Icon(Icons.directions_walk_rounded, size: 18),
                  label: Text('Đang đi (${walks.length})'),
                  selected: layers.walks,
                  onSelected: (_) => ref.read(_mapLayersProvider.notifier).toggleWalks(),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _map,
                  options: const MapOptions(
                    initialCenter: _fallbackCenter,
                    initialZoom: 15,
                    interactionOptions: InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'vn.edu.antoan.campus_safety',
                      maxZoom: 19,
                    ),
                    MarkerLayer(
                      markers: [
                        if (layers.walks)
                          for (final w in located)
                            Marker(
                              point: LatLng(w.latitude!, w.longitude!),
                              width: 48,
                              height: 48,
                              child: _WalkPin(walk: w, onTap: () => _showWalk(w)),
                            ),
                        if (layers.reports)
                          for (final r in reports)
                            Marker(
                              point: LatLng(r.latitude!, r.longitude!),
                              width: 48,
                              height: 48,
                              child: _ReportPin(report: r, onTap: () => _showReport(r)),
                            ),
                      ],
                    ),
                    RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution(
                          'OpenStreetMap contributors',
                          onTap: () => launchUrl(Uri.parse('https://openstreetmap.org/copyright')),
                        ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  right: 16,
                  bottom: 48,
                  child: FloatingActionButton.small(
                    heroTag: 'map-me',
                    tooltip: 'Vị trí của tôi',
                    onPressed: _goToMe,
                    child: const Icon(Icons.my_location_rounded),
                  ),
                ),
                if (reportsAsync.isLoading || walksAsync.isLoading)
                  const Positioned(top: 0, left: 0, right: 0, child: LinearProgressIndicator()),
              ],
            ),
          ),
          if (reportsAsync.hasError || walksAsync.hasError)
            Padding(
              padding: const EdgeInsets.all(16),
              child: InlineError(errorMessage(reportsAsync.error ?? walksAsync.error!)),
            )
          else if (layers.walks && walks.isNotEmpty)
            _WalkList(walks: walks, onTap: _showWalk)
          else if (noCoords > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Text(
                '$noCoords sự cố đang mở không có GPS, xem ở tab Sự cố.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }

  void _showReport(Report r) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(incidentIcon(r.type)),
                    const SizedBox(width: 8),
                    Expanded(child: Text('${r.type.label} · ${r.code}', style: theme.textTheme.titleMedium)),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [SeverityBadge(r.severity), StatusChip(r.status)]),
                const SizedBox(height: 8),
                Text('${r.locationText} · ${formatRelative(r.createdAt)}', style: theme.textTheme.bodyMedium),
                if (r.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(r.description, maxLines: 3, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    this.context.push(AppRoutes.report(r.id));
                  },
                  child: const Text('Xem chi tiết và xử lý'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showWalk(Walk w) {
    if (w.hasLocation) _map.move(LatLng(w.latitude!, w.longitude!), 17);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(child: _WalkDetails(walk: w)),
    );
  }
}

class _ReportPin extends StatelessWidget {
  const _ReportPin({required this.report, required this.onTap});

  final Report report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final critical = report.severity == Severity.critical;
    final bg = critical ? palette.emergency : palette.severityBackground[report.severity]!;
    final fg = critical ? palette.onEmergency : palette.severityForeground[report.severity]!;
    return Semantics(
      button: true,
      label: '${report.type.label}, mức ${report.severity.label}, ${report.locationText}',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: Border.all(color: fg, width: 2),
            boxShadow: const [BoxShadow(blurRadius: 4, color: Color(0x33000000))],
          ),
          child: Icon(incidentIcon(report.type), color: fg, size: 24),
        ),
      ),
    );
  }
}

class _WalkPin extends StatelessWidget {
  const _WalkPin({required this.walk, required this.onTap});

  final Walk walk;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final late = walk.remaining(DateTime.now()).isNegative;
    return Semantics(
      button: true,
      label: '${walk.displayName} đang đi tới ${walk.destination}',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: late ? context.palette.emergency : scheme.primary,
            shape: BoxShape.circle,
            border: Border.all(color: scheme.surface, width: 3),
            boxShadow: const [BoxShadow(blurRadius: 4, color: Color(0x33000000))],
          ),
          child: Icon(Icons.directions_walk_rounded, color: late ? context.palette.onEmergency : scheme.onPrimary),
        ),
      ),
    );
  }
}

class _WalkList extends StatelessWidget {
  const _WalkList({required this.walks, required this.onTap});

  final List<Walk> walks;
  final void Function(Walk) onTap;

  @override
  Widget build(BuildContext context) {
    final sorted = [...walks]..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 200),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        children: [
          const SectionTitle('Đang "Đi cùng tôi"'),
          for (final w in sorted) _WalkTile(walk: w, onTap: () => onTap(w)),
        ],
      ),
    );
  }
}

class _WalkTile extends StatelessWidget {
  const _WalkTile({required this.walk, required this.onTap});

  final Walk walk;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final left = walk.remaining(DateTime.now());
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: const Icon(Icons.directions_walk_rounded),
      title: Text(walk.displayName.isEmpty ? 'Người dùng' : walk.displayName),
      subtitle: Text(
        left.isNegative
            ? 'Tới ${walk.destination} · quá giờ hẹn'
            : 'Tới ${walk.destination} · còn ${formatDuration(left)}',
        style: left.isNegative ? TextStyle(color: context.palette.emergencyText) : null,
      ),
      trailing: walk.hasLocation
          ? null
          : Text('Chưa có GPS', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
    );
  }
}

class _WalkDetails extends StatelessWidget {
  const _WalkDetails({required this.walk});

  final Walk walk;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final w = walk;
    final left = w.remaining(DateTime.now());
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(w.displayName.isEmpty ? 'Người dùng' : w.displayName, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Đang đi tới ${w.destination}', style: theme.textTheme.bodyLarge),
          Text(
            'Bắt đầu ${formatTime(w.startedAt)}, hẹn tới ${formatTime(w.dueAt)}'
            '${left.isNegative ? ' (đã quá giờ)' : ' (còn ${formatDuration(left)})'}',
            style: theme.textTheme.bodyMedium,
          ),
          Text(
            w.locationAt == null ? 'Chưa nhận được vị trí.' : 'Vị trí cập nhật ${formatRelative(w.locationAt!)}.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          if (w.phone != null && w.phone!.isNotEmpty)
            FilledButton.icon(
              onPressed: () => launchUrl(Uri(scheme: 'tel', path: w.phone)),
              icon: const Icon(Icons.call_rounded),
              label: Text('Gọi ${w.phone}'),
            )
          else
            const InfoNote('Người này chưa nhập số điện thoại trong hồ sơ.'),
        ],
      ),
    );
  }
}
