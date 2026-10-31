import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/format/formatters.dart';
import '../domain/admin_models.dart';

/// Chi tiết một lần gửi: dùng ở "Gửi thử" và "Nhật ký gửi tin".
class SendLogDetails extends StatelessWidget {
  const SendLogDetails({super.key, required this.item});

  final SendLogItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rows = <(String, String)>[
      ('Thời gian', item.createdAt == null ? '' : formatDateTime(item.createdAt!)),
      ('Mục đích', purposeLabel(item.purpose)),
      ('Template', templateTitle(item.template)),
      if (item.templateId != null) ('Template ID', item.templateId!),
      ('Số nhận', item.recipient),
      ('Chế độ', item.mode),
      ('tracking_id', item.trackingId),
      if (item.messageId != null) ('msg_id', item.messageId!),
      if (item.errorCode != null) ('Mã lỗi Zalo', '${item.errorCode}'),
      if (item.providerMessage != null) ('Phản hồi Zalo', item.providerMessage!),
      if (item.remainingQuota != null) ('Hạn mức còn lại', '${item.remainingQuota}/${item.dailyQuota ?? '?'} tin hôm nay'),
      if (item.durationMs != null) ('Thời gian xử lý', '${item.durationMs} ms'),
      if ((item.attempts ?? 1) > 1) ('Số lần thử', '${item.attempts} (đã tự làm mới token)'),
      if (item.reportId != null && item.reportId!.isNotEmpty) ('Báo cáo', item.reportId!),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  item.success ? Icons.check_circle_rounded : Icons.error_rounded,
                  color: item.success ? scheme.primary : scheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(item.success ? 'Gửi thành công' : 'Gửi thất bại', style: theme.textTheme.titleMedium),
                ),
                IconButton(
                  tooltip: 'Sao chép tracking_id',
                  onPressed: () => Clipboard.setData(ClipboardData(text: item.trackingId)),
                  icon: const Icon(Icons.copy_rounded, size: 20),
                ),
              ],
            ),
            if (!item.success && item.message != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(12)),
                child: Text(item.message!, style: TextStyle(color: scheme.onErrorContainer)),
              ),
            ],
            const SizedBox(height: 12),
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 128,
                      child: Text(label, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                    ),
                    Expanded(child: SelectableText(value, style: theme.textTheme.bodyMedium)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
