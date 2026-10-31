import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/config/app_config.dart';
import '../../../core/router/role_navigation.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/application/session.dart';
import '../../campus/campus_info.dart';
import '../../campus/hotline_button.dart';
import '../application/report_providers.dart';
import '../../safety/broadcasts.dart';
import '../../safety/walk_screen.dart';
import 'emergency_sheet.dart';
import 'widgets/report_tile.dart';

/// Trang chủ người báo: cảnh báo toàn trường, khối KHẨN CẤP, hai hành động chính, báo cáo gần đây.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(signedInUserProvider);
    final campus = ref.watch(campusInfoProvider).value;
    final recent = ref.watch(myReportsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppConfig.appName)),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(campusInfoProvider.future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (user != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Xin chào ${user.displayName}', style: theme.textTheme.titleLarge),
                    Text(
                      (campus != null && campus.campusName.isNotEmpty)
                          ? campus.campusName
                          : _greetingLine(DateTime.now()),
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            const BroadcastBanner(padding: EdgeInsets.only(bottom: 16)),
            const ActiveWalkBanner(),
            const EmergencyButton(),
            const SizedBox(height: 12),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _ActionTile(
                      icon: Icons.edit_note_rounded,
                      title: 'Gửi báo cáo',
                      subtitle: 'Mô tả, ảnh, vị trí. Khi không nguy hiểm tức thì.',
                      onTap: () => context.push(AppRoutes.newReport),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionTile(
                      icon: Icons.directions_walk_rounded,
                      title: 'Đi cùng tôi',
                      subtitle: 'Hẹn giờ về tới nơi. Quá giờ, bảo vệ được báo.',
                      onTap: () => context.push(AppRoutes.walk),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const HotlineButton(),
            const SizedBox(height: 24),
            SectionTitle(
              'Báo cáo gần đây',
              trailing: TextButton(onPressed: () => context.go(AppRoutes.myReports), child: const Text('Xem tất cả')),
            ),
            recent.when(
              loading: () => const SizedBox(height: 280, child: SkeletonList(count: 2, padding: EdgeInsets.zero)),
              error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(myReportsProvider)),
              data: (items) => items.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Bạn chưa gửi báo cáo nào. Báo cáo bạn gửi sẽ hiện ở đây kèm trạng thái xử lý.',
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    )
                  : Column(
                      children: [
                        for (final s in items.take(3))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: ReportTile.fromSummary(s, onTap: () => context.push(AppRoutes.report(s.id))),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static String _greetingLine(DateTime now) => switch (now.hour) {
        < 11 => 'Chúc bạn buổi sáng an toàn',
        < 14 => 'Chúc bạn buổi trưa an toàn',
        < 18 => 'Chúc bạn buổi chiều an toàn',
        _ => 'Về muộn thì dùng Đi cùng tôi',
      };
}

/// Ô hành động trên trang chủ: icon trong khối màu, tiêu đề, mô tả ngắn.
class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: theme.colorScheme.onPrimaryContainer),
              ),
              const SizedBox(height: 12),
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Khối KHẨN CẤP: vật thể lớn nhất màn hình, nền đỏ, chữ trắng, cao tối thiểu 120dp.
class EmergencyButton extends StatelessWidget {
  const EmergencyButton({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: 'Khẩn cấp. Chạm để báo ngay cho bảo vệ trực.',
      excludeSemantics: true,
      child: Material(
        color: palette.emergency,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          key: const Key('emergency-button'),
          borderRadius: BorderRadius.circular(24),
          onTap: () => showEmergencySheet(context),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 120),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: palette.onEmergency.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.sos_rounded, color: palette.onEmergency, size: 36),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'KHẨN CẤP',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: palette.onEmergency,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Chạm để báo ngay cho bảo vệ trực, kèm vị trí GPS.',
                          style: theme.textTheme.bodyLarge?.copyWith(color: palette.onEmergency),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
