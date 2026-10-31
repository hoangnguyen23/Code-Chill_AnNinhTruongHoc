import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'campus_info.dart';

/// Nút "Gọi trực an ninh". Ẩn khi chưa cấu hình số trực.
class HotlineButton extends ConsumerWidget {
  const HotlineButton({super.key, this.filled = false, this.expand = true});

  final bool filled;
  final bool expand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hotline = ref.watch(campusInfoProvider).value?.hotline;
    if (hotline == null || hotline.trim().isEmpty) return const SizedBox.shrink();
    Future<void> call() async {
      final ok = await callHotline(hotline);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không mở được trình gọi điện. Hãy gọi $hotline.')),
        );
      }
    }

    final label = Text('Gọi trực an ninh $hotline');
    const icon = Icon(Icons.call_rounded);
    final button = filled
        ? FilledButton.tonalIcon(onPressed: call, icon: icon, label: label)
        : OutlinedButton.icon(onPressed: call, icon: icon, label: label);
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
