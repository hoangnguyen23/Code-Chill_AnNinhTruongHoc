import 'dart:async';

import 'package:campus_core/campus_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/format/formatters.dart';
import '../../../core/network/api_error.dart';
import '../../../core/router/role_navigation.dart';
import '../../../core/services/image_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_chip.dart';
import '../../auth/application/session.dart';
import '../../campus/campus_info.dart';
import '../application/report_submitter.dart';
import 'widgets/submit_result_view.dart';

const _otherBuilding = '__other__';

String severityHint(Severity s) => switch (s) {
      Severity.low => 'Không gấp, xử lý trong ngày. Ví dụ: hỏng khoá tủ.',
      Severity.medium => 'Cần xử lý sớm nhưng chưa nguy hiểm.',
      Severity.high => 'Ảnh hưởng an toàn, cần bảo vệ tới ngay.',
      Severity.critical => 'Nguy hiểm tính mạng hoặc tài sản lớn. Nên dùng nút KHẨN CẤP.',
    };

/// Màn gửi báo cáo chi tiết.
class NewReportScreen extends ConsumerStatefulWidget {
  const NewReportScreen({super.key});

  @override
  ConsumerState<NewReportScreen> createState() => _NewReportScreenState();
}

class _NewReportScreenState extends ConsumerState<NewReportScreen> {
  final _description = TextEditingController();
  final _customBuilding = TextEditingController();
  final _floor = TextEditingController();
  final _room = TextEditingController();
  final _scroll = ScrollController();

  IncidentType? _type;
  Severity _severity = Severity.medium;
  String? _building;
  DateTime _occurredAt = DateTime.now();
  bool _anonymous = false;
  final List<PickedImage> _images = [];

  LocationFix? _location;
  bool _locating = false;
  LocationException? _locationError;

  Map<String, String> _errors = {};
  String? _submitError;
  String? _progress;
  bool _submitting = false;

  @override
  void dispose() {
    _description.dispose();
    _customBuilding.dispose();
    _floor.dispose();
    _room.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String? get _buildingValue {
    if (_building == _otherBuilding) {
      final t = _customBuilding.text.trim();
      return t.isEmpty ? null : t;
    }
    return _building;
  }

  ReportDraft _draft() => ReportDraft(
        type: _type ?? IncidentType.other,
        severity: _severity,
        description: _description.text,
        occurredAt: _occurredAt,
        building: _buildingValue,
        floor: _floor.text.trim().isEmpty ? null : _floor.text.trim(),
        room: _room.text.trim().isEmpty ? null : _room.text.trim(),
        latitude: _location?.latitude,
        longitude: _location?.longitude,
        accuracyMeters: _location?.accuracyMeters,
        anonymous: _anonymous,
      );

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _locationError = null;
    });
    try {
      final fix = await ref.read(locationServiceProvider).current();
      if (mounted) setState(() => _location = fix);
    } on LocationException catch (e) {
      if (mounted) setState(() => _locationError = e);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _addImage() async {
    final fromCamera = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Chụp ảnh'),
              onTap: () => Navigator.pop(context, true),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Chọn từ thư viện'),
              onTap: () => Navigator.pop(context, false),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (fromCamera == null) return;
    try {
      final image = await ref.read(imageServiceProvider).pick(fromCamera: fromCamera);
      if (image != null && mounted) setState(() => _images.add(image));
    } on ImageException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _pickTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now,
      helpText: 'Ngày xảy ra',
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_occurredAt),
      helpText: 'Giờ xảy ra',
    );
    if (time == null) return;
    setState(() => _occurredAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final draft = _draft();
    final errors = <String, String>{
      if (_type == null) 'type': 'Chọn loại sự cố.',
      ...validateReportDraft(draft),
      if (_building == _otherBuilding && _buildingValue == null) 'building': 'Nhập tên khu vực.',
    };
    if (_images.length > ReportLimits.maxImages) errors['images'] = 'Tối đa ${ReportLimits.maxImages} ảnh.';
    setState(() {
      _errors = errors;
      _submitError = errors.isEmpty ? null : 'Kiểm tra lại các mục được đánh dấu.';
    });
    if (errors.isNotEmpty) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _scroll.jumpTo(0);
      } else {
        await _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOutQuart);
      }
      return;
    }

    final user = ref.read(signedInUserProvider);
    if (user == null) return;
    setState(() {
      _submitting = true;
      _progress = _images.isEmpty ? 'Đang gửi báo cáo…' : 'Đang tải ảnh 0/${_images.length}…';
    });
    try {
      final result = await ref.read(reportSubmitterProvider).submit(
            draft,
            images: _images,
            uploaderUid: user.uid,
            onUploadProgress: (done, total) {
              if (!mounted) return;
              setState(() => _progress = done < total ? 'Đang tải ảnh $done/$total…' : 'Đang gửi báo cáo…');
            },
          );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _progress = null;
      });
      unawaited(HapticFeedback.mediumImpact());
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.check_circle_rounded, size: 32),
          title: const Text('Đã gửi báo cáo'),
          content: SingleChildScrollView(child: SubmitResultView(result: result)),
          actions: [
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Xem báo cáo')),
          ],
        ),
      );
      if (mounted) context.pushReplacement(AppRoutes.report(result.id));
    } on ApiError catch (e) {
      setState(() {
        _errors = Map.of(e.fieldErrors);
        _submitError = e.message;
      });
    } on ImageException catch (e) {
      setState(() => _submitError = e.message);
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
          _progress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final campus = ref.watch(campusInfoProvider);
    final buildings = campus.value?.buildings ?? const <String>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Gửi báo cáo sự cố')),
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: _submitting,
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              if (_submitError != null) ...[InlineError(_submitError!), const SizedBox(height: 16)],
              const SectionTitle('Loại sự cố'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in IncidentType.values)
                    ChoiceChip(
                      avatar: Icon(incidentIcon(t), size: 18),
                      label: Text(t.label),
                      selected: _type == t,
                      onSelected: (_) => setState(() {
                        _type = t;
                        _errors.remove('type');
                      }),
                    ),
                ],
              ),
              _FieldError(_errors['type']),
              const SizedBox(height: 24),
              const SectionTitle('Mức độ khẩn cấp'),
              SegmentedButton<Severity>(
                segments: [
                  for (final s in Severity.values) ButtonSegment(value: s, label: Text(s.label)),
                ],
                selected: {_severity},
                showSelectedIcon: false,
                onSelectionChanged: (v) => setState(() => _severity = v.first),
              ),
              const SizedBox(height: 8),
              Text(
                severityHint(_severity),
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              const SectionTitle('Mô tả'),
              TextField(
                key: const Key('description'),
                controller: _description,
                minLines: 4,
                maxLines: 10,
                maxLength: ReportLimits.maxDescriptionLength,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Chuyện gì đang xảy ra?',
                  alignLabelWithHint: true,
                  hintText: 'Ai, làm gì, có người bị thương không, đặc điểm nhận dạng…',
                  errorText: _errors['description'],
                ),
              ),
              const SizedBox(height: 16),
              const SectionTitle('Vị trí'),
              DropdownButtonFormField<String>(
                key: const Key('building'),
                initialValue: _building,
                isExpanded: true,
                decoration: InputDecoration(labelText: 'Toà nhà / khu vực', errorText: _errors['building']),
                items: [
                  for (final b in buildings) DropdownMenuItem(value: b, child: Text(b)),
                  const DropdownMenuItem(value: _otherBuilding, child: Text('Khác (nhập tên)')),
                ],
                onChanged: (v) => setState(() {
                  _building = v;
                  _errors.remove('building');
                }),
              ),
              if (_building == _otherBuilding) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _customBuilding,
                  maxLength: ReportLimits.maxBuildingLength,
                  decoration: const InputDecoration(labelText: 'Tên khu vực'),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _floor,
                      maxLength: ReportLimits.maxFloorLength,
                      decoration: InputDecoration(labelText: 'Tầng', counterText: '', errorText: _errors['floor']),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _room,
                      maxLength: ReportLimits.maxRoomLength,
                      decoration: InputDecoration(labelText: 'Phòng', counterText: '', errorText: _errors['room']),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _GpsTile(
                location: _location,
                locating: _locating,
                error: _locationError,
                onLocate: _locate,
                onClear: () => setState(() => _location = null),
                onOpenSettings: () => ref.read(locationServiceProvider).openSettings(),
              ),
              _FieldError(_errors['location']),
              const SizedBox(height: 24),
              const SectionTitle('Thời gian xảy ra'),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.schedule_rounded),
                  title: Text(formatDateTime(_occurredAt)),
                  subtitle: const Text('Mặc định là lúc mở màn này'),
                  trailing: TextButton(onPressed: _pickTime, child: const Text('Đổi')),
                ),
              ),
              _FieldError(_errors['occurredAt']),
              const SizedBox(height: 24),
              SectionTitle(
                'Ảnh (${_images.length}/${ReportLimits.maxImages})',
              ),
              _ImagesRow(
                images: _images,
                onAdd: _images.length >= ReportLimits.maxImages ? null : _addImage,
                onRemove: (i) => setState(() => _images.removeAt(i)),
              ),
              _FieldError(_errors['images']),
              const SizedBox(height: 16),
              Card(
                child: SwitchListTile(
                  value: _anonymous,
                  onChanged: (v) => setState(() => _anonymous = v),
                  title: const Text('Gửi ẩn danh'),
                  subtitle: const Text(
                    'Bảo vệ không thấy tên và số điện thoại của bạn. Bạn vẫn nhận thông báo và theo dõi được báo cáo.',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            key: const Key('submit-report'),
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.5)),
                      const SizedBox(width: 12),
                      Flexible(child: Text(_progress ?? 'Đang gửi…', overflow: TextOverflow.ellipsis)),
                    ],
                  )
                : const Text('Gửi báo cáo'),
          ),
        ),
      ),
    );
  }
}

class _FieldError extends StatelessWidget {
  const _FieldError(this.message);

  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    final color = Theme.of(context).colorScheme.error;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(child: Text(message!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color))),
        ],
      ),
    );
  }
}

class _GpsTile extends StatelessWidget {
  const _GpsTile({
    required this.location,
    required this.locating,
    required this.error,
    required this.onLocate,
    required this.onClear,
    required this.onOpenSettings,
  });

  final LocationFix? location;
  final bool locating;
  final LocationException? error;
  final VoidCallback onLocate;
  final VoidCallback onClear;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (locating) {
      return const Card(
        child: ListTile(
          leading: SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
          title: Text('Đang lấy vị trí GPS…'),
        ),
      );
    }
    if (location != null) {
      return Card(
        child: ListTile(
          leading: Icon(Icons.my_location_rounded, color: theme.colorScheme.primary),
          title: Text('Đã đính kèm vị trí GPS (sai số khoảng ${location!.accuracyMeters.round()} m)'),
          subtitle: Text(
            '${location!.latitude.toStringAsFixed(5)}, ${location!.longitude.toStringAsFixed(5)}',
            style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
          ),
          trailing: IconButton(
            tooltip: 'Bỏ vị trí GPS',
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: onLocate,
          icon: const Icon(Icons.my_location_rounded),
          label: const Text('Đính kèm vị trí GPS'),
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          InlineError(error!.message),
          if (error!.canOpenSettings)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(onPressed: onOpenSettings, child: const Text('Mở cài đặt')),
            ),
        ],
      ],
    );
  }
}

class _ImagesRow extends StatelessWidget {
  const _ImagesRow({required this.images, required this.onAdd, required this.onRemove});

  final List<PickedImage> images;
  final VoidCallback? onAdd;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 96,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (var i = 0; i < images.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      images[i].bytes,
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                      semanticLabel: 'Ảnh ${i + 1}',
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: IconButton.filledTonal(
                      tooltip: 'Xoá ảnh ${i + 1}',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => onRemove(i),
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          if (onAdd != null)
            Semantics(
              button: true,
              label: 'Thêm ảnh',
              child: InkWell(
                onTap: onAdd,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: scheme.outline),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_rounded, color: scheme.primary),
                      const SizedBox(height: 4),
                      Text('Thêm ảnh', style: Theme.of(context).textTheme.labelMedium),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
