import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/format/formatters.dart';
import '../../../core/widgets/state_views.dart';
import '../data/admin_repository.dart';
import '../domain/admin_models.dart';
import 'send_log_details.dart';

/// Nhật ký gửi tin Zalo (collection `zalo_logs`, chỉ quản trị đọc được).
class SendLogsScreen extends ConsumerStatefulWidget {
  const SendLogsScreen({super.key});

  @override
  ConsumerState<SendLogsScreen> createState() => _SendLogsScreenState();
}

class _SendLogsScreenState extends ConsumerState<SendLogsScreen> {
  bool _failuresOnly = false;
  String? _template;

  @override
  Widget build(BuildContext context) {
    final logs = ref.watch(sendLogsProvider(_failuresOnly));
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Nhật ký gửi tin')),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Chỉ lỗi'),
                  selected: _failuresOnly,
                  onSelected: (v) => setState(() => _failuresOnly = v),
                ),
                const SizedBox(width: 8),
                for (final key in ['otp', 'report_received', 'status_update', 'guard_alert']) ...[
                  ChoiceChip(
                    label: Text(templateTitle(key)),
                    selected: _template == key,
                    onSelected: (v) => setState(() => _template = v ? key : null),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          Expanded(
            child: logs.when(
              loading: () => const SkeletonList(),
              error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(sendLogsProvider(_failuresOnly))),
              data: (all) {
                final items = _template == null ? all : all.where((l) => l.template == _template).toList();
                if (items.isEmpty) {
                  return EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: all.isEmpty ? 'Chưa có tin nào được gửi' : 'Không có tin phù hợp',
                    message: all.isEmpty
                        ? 'Mỗi lần gửi OTP, xác nhận báo cáo, cảnh báo bảo vệ hay gửi thử đều được ghi tại đây.'
                        : 'Thử bỏ bộ lọc.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final l = items[i];
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          l.success ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
                          color: l.success ? theme.colorScheme.primary : theme.colorScheme.error,
                        ),
                        title: Text('${templateTitle(l.template)}, ${l.recipient}'),
                        subtitle: Text([
                          [
                            if (l.createdAt != null) formatDateTime(l.createdAt!),
                            l.success ? 'Thành công' : 'Lỗi ${l.errorCode ?? ''}'.trim(),
                            if (l.mode == 'development') 'chế độ thử',
                          ].join(', '),
                          if (!l.success && l.message != null) l.message!,
                        ].join('\n')),
                        isThreeLine: !l.success && l.message != null,
                        onTap: () => showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => SafeArea(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: SendLogDetails(item: l),
                            ),
                          ),
                        ),
                      ),
                    );
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
