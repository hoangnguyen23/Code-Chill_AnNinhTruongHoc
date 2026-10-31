import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format/formatters.dart';
import '../../core/network/api_error.dart';
import '../../core/widgets/state_views.dart';
import 'broadcasts.dart';

/// Quản trị gửi cảnh báo toàn trường và gỡ cảnh báo đang hiển thị.
class BroadcastComposeScreen extends ConsumerStatefulWidget {
  const BroadcastComposeScreen({super.key});

  @override
  ConsumerState<BroadcastComposeScreen> createState() => _BroadcastComposeScreenState();
}

class _BroadcastComposeScreenState extends ConsumerState<BroadcastComposeScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  BroadcastLevel _level = BroadcastLevel.warning;
  int _hours = 6;
  bool _sending = false;
  String? _error;

  static const _hourChoices = [1, 3, 6, 12, 24, 48];

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gửi tới toàn trường?'),
        content: Text(
          'Mọi tài khoản sẽ nhận thông báo đẩy và thấy banner "${_level.label}" trong $_hours giờ.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Xem lại')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Gửi ngay')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final delivered = await ref
          .read(broadcastRepositoryProvider)
          .send(title: _title.text, body: _body.text, level: _level, hours: _hours);
      _title.clear();
      _body.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã gửi cảnh báo. $delivered thiết bị nhận thông báo đẩy.')),
        );
      }
    } on ApiError catch (e) {
      setState(() => _error = e.fieldErrors.values.firstOrNull ?? e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _end(Broadcast b) async {
    try {
      await ref.read(broadcastRepositoryProvider).end(b.id);
    } on ApiError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recent = ref.watch(recentBroadcastsProvider);
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('Cảnh báo toàn trường')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Mức độ', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                SegmentedButton<BroadcastLevel>(
                  segments: [
                    for (final l in BroadcastLevel.values)
                      ButtonSegment(value: l, label: Text(l.label), icon: Icon(l.icon)),
                  ],
                  selected: {_level},
                  onSelectionChanged: (v) => setState(() => _level = v.first),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _title,
                  maxLength: 80,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Tiêu đề', hintText: 'Ví dụ: Cháy ở toà B'),
                  validator: (v) => (v?.trim().length ?? 0) < 3 ? 'Nhập tiêu đề (ít nhất 3 ký tự).' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _body,
                  maxLength: 500,
                  minLines: 3,
                  maxLines: 6,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Nội dung',
                    hintText: 'Việc mọi người cần làm, khu vực cần tránh…',
                    alignLabelWithHint: true,
                  ),
                  validator: (v) => (v?.trim().length ?? 0) < 3 ? 'Nhập nội dung (ít nhất 3 ký tự).' : null,
                ),
                const SizedBox(height: 8),
                Text('Hiển thị trong', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final h in _hourChoices)
                      ChoiceChip(
                        label: Text('$h giờ'),
                        selected: _hours == h,
                        onSelected: (_) => setState(() => _hours = h),
                      ),
                  ],
                ),
                if (_error != null) ...[const SizedBox(height: 16), InlineError(_error!)],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.send_rounded),
                  label: Text(_sending ? 'Đang gửi…' : 'Gửi cảnh báo'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const SectionTitle('Đã gửi gần đây'),
          recent.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => InlineError(errorMessage(e)),
            data: (items) => items.isEmpty
                ? Text(
                    'Chưa có cảnh báo nào.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  )
                : Column(
                    children: [
                      for (final b in items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: b.isLive(now)
                              ? BroadcastCard(
                                  broadcast: b,
                                  trailing: IconButton(
                                    tooltip: 'Gỡ cảnh báo',
                                    onPressed: () => _end(b),
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                                )
                              : ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(b.level.icon),
                                  title: Text(b.title),
                                  subtitle: Text(
                                    '${formatDateTime(b.createdAt)} · ${b.active ? 'Hết hạn' : 'Đã gỡ'}',
                                  ),
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
