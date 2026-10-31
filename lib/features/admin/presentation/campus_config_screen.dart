import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/network/api_error.dart';
import '../../../core/widgets/state_views.dart';
import '../../campus/campus_info.dart';
import '../data/admin_repository.dart';

/// Tên trường, số trực an ninh (nút "Gọi trực") và danh sách khu vực cho form báo cáo.
class CampusConfigScreen extends ConsumerStatefulWidget {
  const CampusConfigScreen({super.key});

  @override
  ConsumerState<CampusConfigScreen> createState() => _CampusConfigScreenState();
}

class _CampusConfigScreenState extends ConsumerState<CampusConfigScreen> {
  final _name = TextEditingController();
  final _hotline = TextEditingController();
  final _buildings = TextEditingController();
  bool _loaded = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _hotline.dispose();
    _buildings.dispose();
    super.dispose();
  }

  void _fill(CampusInfo info) {
    if (_loaded) return;
    _loaded = true;
    _name.text = info.campusName;
    _hotline.text = info.hotline ?? '';
    _buildings.text = info.buildings.join('\n');
  }

  Future<void> _save() async {
    final buildings = _buildings.text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Nhập tên trường.');
      return;
    }
    if (buildings.isEmpty) {
      setState(() => _error = 'Cần ít nhất một khu vực.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(adminRepositoryProvider).updateCampus(
            campusName: _name.text.trim(),
            hotline: _hotline.text.trim().isEmpty ? null : _hotline.text.trim(),
            buildings: buildings,
          );
      refreshCampus(ref);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu cấu hình trường.')));
        Navigator.pop(context);
      }
    } on ApiError catch (e) {
      setState(() => _error = e.fieldErrors.values.firstOrNull ?? e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = ref.watch(campusInfoProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Cấu hình trường')),
      body: info.when(
        loading: () => const SkeletonList(count: 3),
        error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(campusInfoProvider)),
        data: (data) {
          _fill(data);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Tên trường')),
              const SizedBox(height: 16),
              TextField(
                controller: _hotline,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Số trực an ninh',
                  helperText: 'Hiện ở nút "Gọi trực an ninh" trên màn đăng nhập, trang chủ và màn khẩn cấp.',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _buildings,
                minLines: 6,
                maxLines: 16,
                decoration: const InputDecoration(
                  labelText: 'Khu vực (mỗi dòng một khu vực)',
                  alignLabelWithHint: true,
                  helperText: 'Dùng cho ô "Toà nhà / khu vực" khi báo cáo và bộ lọc của bảo vệ.',
                ),
              ),
              if (_error != null) ...[const SizedBox(height: 12), InlineError(_error!)],
              const SizedBox(height: 16),
              FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Đang lưu…' : 'Lưu')),
            ],
          );
        },
      ),
    );
  }
}
