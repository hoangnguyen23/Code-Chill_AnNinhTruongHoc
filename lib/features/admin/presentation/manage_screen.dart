import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/format/formatters.dart';
import '../../../core/network/api_error.dart';
import '../../../core/router/role_navigation.dart';
import '../../../core/widgets/state_views.dart';
import '../../campus/campus_info.dart';
import '../data/admin_repository.dart';

/// Menu quản trị: cảnh báo toàn trường, tài khoản, cấu hình, trạng thái Zalo.
class ManageScreen extends ConsumerWidget {
  const ManageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(zaloStatusProvider);
    final zaloOn = ref.watch(campusInfoProvider).value?.isZaloEnabled ?? false;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(zaloStatusProvider.future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const SectionTitle('An ninh'),
            _MenuTile(
              icon: Icons.campaign_outlined,
              title: 'Cảnh báo toàn trường',
              subtitle: 'Gửi thông báo đẩy và banner tới mọi người: cháy, mưa bão, khu vực cần tránh.',
              onTap: () => context.push(AppRoutes.broadcasts),
            ),
            const SizedBox(height: 12),
            const SectionTitle('Công cụ'),
            _MenuTile(
              icon: Icons.group_outlined,
              title: 'Tài khoản',
              subtitle: 'Bảo vệ, quản trị, người báo. Phân quyền, khoá, trạng thái trực.',
              onTap: () => context.push(AppRoutes.users),
            ),
            _MenuTile(
              icon: Icons.apartment_outlined,
              title: 'Cấu hình trường',
              subtitle: 'Tên trường, số trực an ninh, danh sách khu vực.',
              onTap: () => context.push(AppRoutes.campusConfig),
            ),
            if (zaloOn) ...[
              _MenuTile(
                icon: Icons.send_to_mobile_outlined,
                title: 'Gửi thử Zalo',
                subtitle: 'Gửi tin thật theo template tới một số điện thoại và xem kết quả.',
                onTap: () => context.push(AppRoutes.zaloTest),
              ),
              _MenuTile(
                icon: Icons.receipt_long_outlined,
                title: 'Nhật ký gửi tin',
                subtitle: 'Thời gian, số nhận đã che, template, tracking_id, kết quả, mã lỗi.',
                onTap: () => context.push(AppRoutes.sendLogs),
              ),
            ],
            const SizedBox(height: 12),
            const SectionTitle('Kết nối Zalo'),
            status.when(
              loading: () => const Card(child: ListTile(title: Text('Đang kiểm tra kết nối Zalo…'))),
              error: (e, _) => InlineError(errorMessage(e)),
              data: (s) {
                if (s.mode == 'off') {
                  return const InfoNote(
                    'Zalo đang tắt: mã xác nhận gửi qua email, thông báo sự cố gửi qua thông báo đẩy trong app. '
                    'Điền các biến ZALO_* trong backend/.env để bật.',
                    icon: Icons.cloud_off_rounded,
                  );
                }
                final configured = s.templates.where((t) => t.configured).length;
                final token = s.token;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              token.valid ? Icons.check_circle_rounded : Icons.error_rounded,
                              color: token.valid ? theme.colorScheme.primary : theme.colorScheme.error,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                token.valid ? 'Access token còn hiệu lực' : 'Access token chưa sẵn sàng',
                                style: theme.textTheme.titleSmall,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Chế độ gửi: ${s.isDevelopment ? 'development (chỉ gửi tới quản trị viên OA/ứng dụng)' : 'production'}'),
                        Text('Template đã cấu hình: $configured/${s.templates.length}'),
                        if (token.expiresAt != null) Text('Token hết hạn lúc ${formatDateTime(token.expiresAt!)}'),
                        if (token.lastError != null) ...[
                          const SizedBox(height: 8),
                          InlineError('Lỗi làm mới token gần nhất: ${token.lastError}'),
                        ],
                        for (final w in s.warnings) ...[const SizedBox(height: 8), InlineError(w)],
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
      ),
    );
  }
}
