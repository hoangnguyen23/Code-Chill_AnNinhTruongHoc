import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router/role_navigation.dart';
import '../../../core/widgets/state_views.dart';
import '../application/report_providers.dart';
import 'widgets/report_tile.dart';

/// Danh sách báo cáo của người đang đăng nhập (kể cả báo cáo ẩn danh), cập nhật thời gian thực.
class MyReportsScreen extends ConsumerWidget {
  const MyReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(myReportsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Báo cáo của tôi')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.newReport),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Báo cáo mới'),
      ),
      body: reports.when(
        loading: () => const SkeletonList(),
        error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(myReportsProvider)),
        data: (items) => items.isEmpty
            ? EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'Chưa có báo cáo nào',
                message: 'Khi bạn gửi báo cáo, trạng thái xử lý sẽ cập nhật tại đây và qua thông báo.',
                action: FilledButton(
                  onPressed: () => context.push(AppRoutes.newReport),
                  child: const Text('Gửi báo cáo'),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) => ReportTile.fromSummary(
                  items[i],
                  onTap: () => context.push(AppRoutes.report(items[i].id)),
                ),
              ),
      ),
    );
  }
}
