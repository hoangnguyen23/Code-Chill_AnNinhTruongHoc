import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/services/image_service.dart';
import '../../../../core/theme/app_theme.dart';

/// Lưới ảnh sự cố (lưu trong Firestore qua backend). Chạm để xem lớn.
class ReportImages extends ConsumerWidget {
  const ReportImages({super.key, required this.paths});

  final List<String> paths;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < paths.length; i++) _Thumb(path: paths[i], index: i),
      ],
    );
  }
}

class _Thumb extends ConsumerWidget {
  const _Thumb({required this.path, required this.index});

  final String path;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final url = ref.watch(imageUrlProvider(path));
    Widget box(Widget child) => ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(width: 104, height: 104, color: scheme.surfaceContainerHighest, child: child),
        );
    return url.when(
      loading: () => box(const SizedBox.shrink()),
      error: (_, _) => Tooltip(
        message: 'Không tải được ảnh',
        child: box(Icon(Icons.broken_image_outlined, color: scheme.onSurfaceVariant)),
      ),
      data: (u) => Semantics(
        button: true,
        label: 'Xem ảnh ${index + 1}',
        child: GestureDetector(
          onTap: () => showDialog<void>(
            context: context,
            builder: (context) => Dialog.fullscreen(
              backgroundColor: context.palette.viewerBackground,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: InteractiveViewer(child: Center(child: Image.network(u, fit: BoxFit.contain))),
                  ),
                  SafeArea(
                    child: IconButton(
                      tooltip: 'Đóng',
                      color: context.palette.onEmergency,
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ),
          child: box(Image.network(
            u,
            fit: BoxFit.cover,
            // Ảnh gốc đến 1600px; thumbnail chỉ cần cỡ hiển thị để tiết kiệm bộ nhớ.
            cacheWidth: (104 * MediaQuery.devicePixelRatioOf(context)).round(),
            errorBuilder: (_, _, _) => Icon(Icons.broken_image_outlined, color: scheme.onSurfaceVariant),
          )),
        ),
      ),
    );
  }
}
