import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../campus/campus_info.dart';
import '../../domain/report.dart';

/// Tóm tắt kết quả sau khi gửi: mã sự cố cỡ lớn và tình trạng thông báo (đẩy trong app, kèm Zalo nếu
/// trường có bật Zalo).
class SubmitResultView extends ConsumerWidget {
  const SubmitResultView({super.key, required this.result});

  final SubmitReportResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final zaloOn = ref.watch(campusInfoProvider).value?.isZaloEnabled ?? false;
    final confirm = result.reporterConfirmation;
    final lines = zaloOn ? _zaloLines(confirm) : _appLines();

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
        for (final (icon, text, ok) in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 20, color: ok ? theme.colorScheme.primary : theme.colorScheme.error),
                const SizedBox(width: 10),
                Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
              ],
            ),
          ),
      ],
    );
  }

  /// Trường không dùng Zalo: báo theo thông báo đẩy trong ứng dụng.
  List<(IconData, String, bool)> _appLines() => [
    if (result.pushDelivered > 0)
      (
        Icons.notifications_active_rounded,
        'Đã báo cho bảo vệ và quản trị trên ứng dụng (${result.pushDelivered} thiết bị).',
        true,
      )
    else
      (Icons.shield_rounded, 'Báo cáo đã vào hàng đợi, bảo vệ thấy ngay trong tab Sự cố.', true),
    (Icons.track_changes_rounded, 'Bạn sẽ nhận thông báo mỗi khi trạng thái xử lý thay đổi.', true),
  ];

  List<(IconData, String, bool)> _zaloLines(ZaloDelivery? confirm) => [
    if (result.pending)
      (Icons.schedule_rounded, 'Tin Zalo đang được gửi. Bạn sẽ nhận tin xác nhận trong ít phút.', true)
    else if (confirm == null)
      (Icons.info_outline_rounded, 'Không có thông tin gửi tin Zalo xác nhận.', true)
    else if (confirm.success)
      (Icons.mark_chat_read_rounded, 'Đã gửi tin Zalo xác nhận tới số của bạn.', true)
    else
      (Icons.sms_failed_rounded, 'Chưa gửi được tin Zalo xác nhận: ${confirm.message ?? 'lỗi không rõ'}', false),
    if (!result.pending)
      if (result.guardsTotal == 0)
        (
          Icons.shield_outlined,
          'Chưa có bảo vệ nào đăng ký nhận tin Zalo lúc này. Bảo vệ vẫn thấy báo cáo trong ứng dụng.',
          false,
        )
      else
        (
          Icons.shield_rounded,
          'Đã báo Zalo cho ${result.guardsAlerted}/${result.guardsTotal} bảo vệ trực.',
          result.guardsAlerted > 0,
        ),
    for (final f in result.guardFailureMessages) (Icons.error_outline_rounded, f, false),
  ];
}
