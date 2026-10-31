import 'dart:async';

import 'package:campus_core/campus_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/network/api_error.dart';
import '../../../core/router/role_navigation.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_chip.dart';
import '../../auth/application/session.dart';
import '../../campus/campus_info.dart';
import '../../campus/hotline_button.dart';
import '../application/report_submitter.dart';
import '../domain/report.dart';
import 'widgets/submit_result_view.dart';

/// Mở sheet khẩn cấp (chạm 1). Gửi bằng nút "Gửi cảnh báo ngay" (chạm 2).
Future<void> showEmergencySheet(BuildContext context) async {
  unawaited(HapticFeedback.heavyImpact());
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const EmergencySheet(),
  );
}

class EmergencySheet extends ConsumerStatefulWidget {
  const EmergencySheet({super.key});

  @override
  ConsumerState<EmergencySheet> createState() => _EmergencySheetState();
}

class _EmergencySheetState extends ConsumerState<EmergencySheet> {
  static const _quickTypes = [
    IncidentType.fight,
    IncidentType.fire,
    IncidentType.theft,
    IncidentType.suspicious,
    IncidentType.other,
  ];

  final _note = TextEditingController();
  IncidentType _type = IncidentType.other;
  String? _building;
  bool _anonymous = false;

  LocationFix? _location;
  String? _locationError;
  bool _locating = true;
  Future<void>? _locationRequest;

  bool _sending = false;
  String? _error;
  SubmitReportResult? _result;

  @override
  void initState() {
    super.initState();
    // Lấy GPS ngay khi mở để tiết kiệm thời gian.
    _locationRequest = _locate();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _locationError = null;
    });
    try {
      final fix = await ref.read(locationServiceProvider).current();
      if (mounted) setState(() => _location = fix);
    } on LocationException catch (e) {
      if (mounted) setState(() => _locationError = e.message);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _send() async {
    final user = ref.read(signedInUserProvider);
    if (user == null) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    // Bấm gửi khi GPS còn đang lấy: chờ thêm, không bắt người dùng bấm lại.
    final pending = _locationRequest;
    if (_locating && pending != null) {
      await pending.timeout(const Duration(seconds: 15), onTimeout: () {});
    }
    if (!mounted) return;
    if (_location == null && _building == null) {
      setState(() {
        _sending = false;
        _error = 'Chưa có vị trí GPS. Chọn khu vực rồi gửi lại, hoặc gọi trực an ninh.';
      });
      return;
    }
    try {
      final result = await ref.read(reportSubmitterProvider).submit(
            ReportDraft(
              type: _type,
              severity: Severity.critical,
              description: _note.text,
              occurredAt: DateTime.now(),
              building: _building,
              latitude: _location?.latitude,
              longitude: _location?.longitude,
              accuracyMeters: _location?.accuracyMeters,
              anonymous: _anonymous,
              emergency: true,
            ),
            images: const [],
            uploaderUid: user.uid,
          );
      unawaited(HapticFeedback.heavyImpact());
      if (mounted) setState(() => _result = result);
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final buildings = ref.watch(campusInfoProvider).value?.buildings ?? const <String>[];
    final result = _result;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.9;

    // Nội dung cuộn ở trên, nút hành động ghim ở chân sheet để luôn thấy "Gửi cảnh báo ngay"
    // mà không cần cuộn, kể cả trên máy màn nhỏ hoặc cỡ chữ lớn.
    final Widget body;
    final Widget footer;
    if (result != null) {
      body = Column(
        key: const ValueKey('done'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Text('Đã gửi cảnh báo khẩn cấp', style: theme.textTheme.titleLarge),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SubmitResultView(result: result),
        ],
      );
      footer = Column(
        key: const ValueKey('footer-done'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HotlineButton(filled: true),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () {
              Navigator.pop(context);
              context.push(AppRoutes.report(result.id));
            },
            child: const Text('Xem báo cáo và trao đổi'),
          ),
        ],
      );
    } else {
      body = Column(
        key: const ValueKey('form'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.sos_rounded, color: palette.emergencyText, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text('Báo khẩn cấp', style: theme.textTheme.titleLarge),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Cảnh báo gửi ngay tới bảo vệ trực trên ứng dụng. Các mục dưới đây không bắt buộc.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          _LocationStatus(
            locating: _locating,
            location: _location,
            error: _locationError,
            onRetry: () => _locationRequest = _locate(),
          ),
          const SizedBox(height: 16),
          Text('Loại sự cố', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in _quickTypes)
                ChoiceChip(
                  avatar: Icon(incidentIcon(t), size: 18),
                  label: Text(t.label),
                  selected: _type == t,
                  onSelected: (_) => setState(() => _type = t),
                ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _building,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Khu vực (nếu biết)'),
            items: [for (final b in buildings) DropdownMenuItem(value: b, child: Text(b))],
            onChanged: (v) => setState(() {
              _building = v;
              _error = null;
            }),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            maxLines: 3,
            minLines: 1,
            maxLength: ReportLimits.maxEmergencyNoteLength,
            decoration: const InputDecoration(labelText: 'Ghi chú ngắn'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _anonymous,
            onChanged: (v) => setState(() => _anonymous = v),
            title: const Text('Gửi ẩn danh'),
            subtitle: const Text('Bảo vệ không thấy tên và số điện thoại của bạn.'),
          ),
        ],
      );
      footer = Column(
        key: const ValueKey('footer-form'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[InlineError(_error!), const SizedBox(height: 8)],
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: FilledButton.icon(
              key: const Key('send-emergency'),
              style: FilledButton.styleFrom(
                backgroundColor: palette.emergency,
                foregroundColor: palette.onEmergency,
                textStyle: theme.textTheme.titleMedium,
                minimumSize: const Size.fromHeight(64),
              ),
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: palette.onEmergency),
                    )
                  : const Icon(Icons.campaign_rounded),
              label: Text(
                !_sending
                    ? 'Gửi cảnh báo ngay'
                    : _locating
                        ? 'Đang lấy vị trí rồi gửi…'
                        : 'Đang gửi cảnh báo…',
              ),
            ),
          ),
          const SizedBox(height: 8),
          const HotlineButton(),
        ],
      );
    }

    final duration = MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 200);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: AnimatedSwitcher(duration: duration, child: body),
              ),
            ),
            Material(
              color: theme.bottomSheetTheme.backgroundColor ?? theme.colorScheme.surfaceContainerLow,
              child: SafeArea(
                top: false,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: AnimatedSwitcher(duration: duration, child: footer),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationStatus extends StatelessWidget {
  const _LocationStatus({
    required this.locating,
    required this.location,
    required this.error,
    required this.onRetry,
  });

  final bool locating;
  final LocationFix? location;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Widget leading;
    final String text;
    if (locating) {
      leading = const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.5));
      text = 'Đang lấy vị trí GPS…';
    } else if (location != null) {
      leading = Icon(Icons.my_location_rounded, color: theme.colorScheme.primary);
      text = 'Đã có vị trí GPS (sai số khoảng ${location!.accuracyMeters.round()} m)';
    } else {
      leading = Icon(Icons.location_off_rounded, color: theme.colorScheme.error);
      text = error ?? 'Chưa có vị trí GPS.';
    }
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
            if (!locating && location == null) TextButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}
