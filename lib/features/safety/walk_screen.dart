import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format/formatters.dart';
import '../../core/network/api_error.dart';
import '../../core/router/role_navigation.dart';
import '../../core/services/location_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/state_views.dart';
import '../campus/campus_info.dart';
import '../campus/hotline_button.dart';
import 'walks.dart';

/// "Đi cùng tôi": hẹn giờ tới nơi, app gửi vị trí định kỳ; quá giờ chưa xác nhận thì bảo vệ được báo.
class WalkScreen extends ConsumerWidget {
  const WalkScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walk = ref.watch(myActiveWalkProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Đi cùng tôi')),
      body: SafeArea(
        child: walk.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(myActiveWalkProvider)),
          data: (w) => AnimatedSwitcher(
            duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 200),
            child: w == null ? const _StartWalkForm(key: ValueKey('start')) : _ActiveWalkView(key: ValueKey(w.id), walk: w),
          ),
        ),
      ),
    );
  }
}

class _StartWalkForm extends ConsumerStatefulWidget {
  const _StartWalkForm({super.key});

  @override
  ConsumerState<_StartWalkForm> createState() => _StartWalkFormState();
}

class _StartWalkFormState extends ConsumerState<_StartWalkForm> {
  final _destination = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  int _minutes = 15;
  bool _starting = false;
  String? _error;

  static const _choices = [5, 10, 15, 20, 30, 45, 60];

  @override
  void dispose() {
    _destination.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _starting = true;
      _error = null;
    });
    LocationFix? at;
    try {
      at = await ref.read(locationServiceProvider).current();
    } on LocationException {
      // Không có GPS vẫn cho đi; nơi đến được dùng làm khu vực khi báo bảo vệ.
    }
    try {
      await ref.read(walkRepositoryProvider).start(destination: _destination.text, minutes: _minutes, at: at);
      unawaited(HapticFeedback.mediumImpact());
    } on ApiError catch (e) {
      setState(() => _error = e.fieldErrors.values.firstOrNull ?? e.message);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buildings = ref.watch(campusInfoProvider).value?.buildings ?? const <String>[];
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const _HowItWorks(),
          const SizedBox(height: 24),
          TextFormField(
            controller: _destination,
            textCapitalization: TextCapitalization.sentences,
            maxLength: 80,
            decoration: const InputDecoration(
              labelText: 'Bạn đang đi tới đâu?',
              hintText: 'Ví dụ: Ký túc xá khu B',
              prefixIcon: Icon(Icons.place_outlined),
            ),
            validator: (v) => (v?.trim().length ?? 0) < 2 ? 'Nhập nơi bạn đang đi tới.' : null,
          ),
          if (buildings.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final b in buildings.take(8))
                  ActionChip(label: Text(b), onPressed: () => setState(() => _destination.text = b)),
              ],
            ),
            const SizedBox(height: 16),
          ],
          Text('Dự kiến tới nơi sau', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in _choices)
                ChoiceChip(label: Text('$m phút'), selected: _minutes == m, onSelected: (_) => setState(() => _minutes = m)),
            ],
          ),
          if (_error != null) ...[const SizedBox(height: 16), InlineError(_error!)],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _starting ? null : _start,
            icon: const Icon(Icons.directions_walk_rounded),
            label: Text(_starting ? 'Đang bắt đầu…' : 'Bắt đầu đi'),
          ),
        ],
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    Widget step(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: scheme.onPrimaryContainer),
              const SizedBox(width: 12),
              Expanded(child: Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onPrimaryContainer))),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Đi về an toàn', style: theme.textTheme.titleMedium?.copyWith(color: scheme.onPrimaryContainer)),
          step(Icons.timer_outlined, 'Chọn nơi đến và thời gian dự kiến.'),
          step(Icons.my_location_rounded, 'Bảo vệ trực thấy vị trí của bạn trên bản đồ trong lúc đi.'),
          step(Icons.notifications_active_outlined, 'Quá giờ mà chưa bấm "Đã tới nơi", bảo vệ được báo ngay kèm vị trí cuối.'),
        ],
      ),
    );
  }
}

class _ActiveWalkView extends ConsumerStatefulWidget {
  const _ActiveWalkView({super.key, required this.walk});

  final Walk walk;

  @override
  ConsumerState<_ActiveWalkView> createState() => _ActiveWalkViewState();
}

class _ActiveWalkViewState extends ConsumerState<_ActiveWalkView> {
  Timer? _ticker;
  Timer? _locationTimer;
  DateTime? _lastSent;
  String? _locationIssue;
  bool _busy = false;

  static const _locationEvery = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _locationTimer = Timer.periodic(_locationEvery, (_) => _sendLocation());
    unawaited(_sendLocation());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _sendLocation() async {
    try {
      final at = await ref.read(locationServiceProvider).current();
      await ref.read(walkRepositoryProvider).sendLocation(widget.walk.id, at);
      if (mounted) {
        setState(() {
          _lastSent = DateTime.now();
          _locationIssue = null;
        });
      }
    } on LocationException catch (e) {
      if (mounted) setState(() => _locationIssue = e.message);
    } on ApiError catch (e) {
      if (mounted) setState(() => _locationIssue = e.message);
    }
  }

  Future<void> _run(Future<void> Function(WalkRepository repo) action, {String? done}) async {
    setState(() => _busy = true);
    try {
      await action(ref.read(walkRepositoryProvider));
      if (done != null && mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
    } on ApiError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sos() async {
    unawaited(HapticFeedback.heavyImpact());
    LocationFix? at;
    try {
      at = await ref.read(locationServiceProvider).current();
    } on LocationException {
      // Gửi ngay với vị trí cuối đã có.
    }
    setState(() => _busy = true);
    try {
      final reportId = await ref.read(walkRepositoryProvider).sos(widget.walk.id, at);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã báo bảo vệ trực. Giữ máy bên người.')),
      );
      if (reportId != null) unawaited(context.push(AppRoutes.report(reportId)));
    } on ApiError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final w = widget.walk;
    final left = w.remaining(DateTime.now());
    final late = left.isNegative;
    final total = w.dueAt.difference(w.startedAt).inSeconds;
    final progress = total <= 0 ? 1.0 : (1 - left.inSeconds / total).clamp(0.0, 1.0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: late ? palette.emergencyContainer : theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.directions_walk_rounded,
                    color: late ? palette.onEmergencyContainer : theme.colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Đang đi tới ${w.destination}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: late ? palette.onEmergencyContainer : theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Semantics(
                liveRegion: late,
                label: late ? 'Đã quá giờ hẹn, đang báo bảo vệ' : 'Còn ${formatDuration(left)}',
                excludeSemantics: true,
                child: Text(
                  late ? 'Quá giờ' : formatCountdown(left),
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: late ? palette.emergencyText : theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              Text(
                late
                    ? 'Bảo vệ trực đang được báo. Nếu bạn an toàn, bấm "Tôi đã tới nơi".'
                    : 'Hẹn tới nơi lúc ${formatTime(w.dueAt)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: late ? palette.onEmergencyContainer : theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(value: progress, minHeight: 8),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(
              _locationIssue == null ? Icons.my_location_rounded : Icons.location_disabled_rounded,
              size: 18,
              color: _locationIssue == null ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.error,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _locationIssue ??
                    (_lastSent == null ? 'Đang lấy vị trí…' : 'Đã gửi vị trí lúc ${formatTime(_lastSent!)}'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _locationIssue == null ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.error,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const InfoNote('Giữ màn hình này mở để vị trí được cập nhật mỗi 30 giây.', icon: Icons.phone_android_rounded),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _busy ? null : () => _run((r) => r.arrive(w.id), done: 'Đã ghi nhận bạn tới nơi an toàn.'),
          icon: const Icon(Icons.verified_user_rounded),
          label: const Text('Tôi đã tới nơi an toàn'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _busy ? null : () => _run((r) => r.extend(w.id, 5), done: 'Đã thêm 5 phút.'),
                child: const Text('Thêm 5 phút'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: _busy ? null : () => _run((r) => r.extend(w.id, 15), done: 'Đã thêm 15 phút.'),
                child: const Text('Thêm 15 phút'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 64,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: palette.emergency, foregroundColor: palette.onEmergency),
            onPressed: _busy ? null : _sos,
            icon: const Icon(Icons.sos_rounded, size: 28),
            label: const Text('KHẨN CẤP, báo bảo vệ ngay'),
          ),
        ),
        const SizedBox(height: 12),
        const HotlineButton(),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _busy ? null : () => _run((r) => r.cancel(w.id), done: 'Đã huỷ lượt đi.'),
          child: const Text('Huỷ lượt đi'),
        ),
      ],
    );
  }
}

/// Khối nhỏ ở trang chủ khi đang có lượt đi: bấm để mở màn đếm ngược.
class ActiveWalkBanner extends ConsumerStatefulWidget {
  const ActiveWalkBanner({super.key});

  @override
  ConsumerState<ActiveWalkBanner> createState() => _ActiveWalkBannerState();
}

class _ActiveWalkBannerState extends ConsumerState<ActiveWalkBanner> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final walk = ref.watch(myActiveWalkProvider).value;
    if (walk == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final left = walk.remaining(DateTime.now());
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push(AppRoutes.walk),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.directions_walk_rounded, color: theme.colorScheme.onPrimaryContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    left.isNegative
                        ? 'Quá giờ hẹn tới ${walk.destination}. Bấm để xác nhận.'
                        : 'Đang đi tới ${walk.destination}, còn ${formatDuration(left)}',
                    style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onPrimaryContainer),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onPrimaryContainer),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
