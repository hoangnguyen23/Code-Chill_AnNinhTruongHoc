import 'package:material_ui/material_ui.dart';

import '../../domain/report.dart';

/// Tóm tắt kết quả sau khi gửi: mã sự cố cỡ lớn và tình trạng thông báo.
class SubmitResultView extends StatelessWidget {
  const SubmitResultView({super.key, required this.result});

  final SubmitReportResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lines = <(IconData, String)>[
      if (result.pushDelivered > 0)
        (
          Icons.notifications_active_rounded,
          'Đã báo cho bảo vệ và quản trị trên ứng dụng (${result.pushDelivered} thiết bị).',
        )
      else
        (Icons.shield_rounded, 'Báo cáo đã vào hàng đợi, bảo vệ thấy ngay trong tab Sự cố.'),
      (Icons.track_changes_rounded, 'Bạn sẽ nhận thông báo mỗi khi trạng thái xử lý thay đổi.'),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Mã sự cố', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        SelectableText(
          result.code,
          style: theme.textTheme.displaySmall,
          semanticsLabel: 'Mã sự cố ${result.code.split('').join(' ')}',
        ),
        const SizedBox(height: 16),
        for (final (icon, text) in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
              ],
            ),
          ),
      ],
    );
  }
}
