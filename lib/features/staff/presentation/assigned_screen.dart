import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router/role_navigation.dart';
import '../../../core/widgets/state_views.dart';
import '../../reports/application/report_providers.dart';
import '../../reports/presentation/widgets/report_tile.dart';
import 'incident_queue_screen.dart';

/// Báo cáo đang giao cho bảo vệ đăng nhập: việc đang mở lên trước.
class AssignedScreen extends ConsumerWidget {
  const AssignedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assigned = ref.watch(assignedToMeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Việc của tôi')),
      body: assigned.when(
        loading: () => const SkeletonList(),
        error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(assignedToMeProvider)),
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.assignment_turned_in_outlined,
              title: 'Chưa có việc nào giao cho bạn',
              message: 'Nhận xử lý một sự cố trong hàng đợi, hoặc chờ quản trị phân công.',
              action: OutlinedButton(onPressed: () => context.go(AppRoutes.queue), child: const Text('Mở hàng đợi')),
            );
          }
          final sorted = openFirst(items);
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: sorted.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) => ReportTile.fromReport(
              sorted[i],
              showAssignee: false,
              onTap: () => context.push(AppRoutes.report(sorted[i].id)),
            ),
          );
        },
      ),
    );
  }
}
