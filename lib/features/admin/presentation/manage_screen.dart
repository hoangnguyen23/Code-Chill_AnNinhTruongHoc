import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router/role_navigation.dart';
import '../../../core/widgets/state_views.dart';

/// Menu quản trị: cảnh báo toàn trường, tài khoản, cấu hình trường.
class ManageScreen extends StatelessWidget {
  const ManageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý')),
      body: ListView(
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
            subtitle: 'Bảo vệ, quản trị, người báo. Phân quyền, khoá, xoá, trạng thái trực.',
            onTap: () => context.push(AppRoutes.users),
          ),
          _MenuTile(
            icon: Icons.apartment_outlined,
            title: 'Cấu hình trường',
            subtitle: 'Tên trường, số trực an ninh, danh sách khu vực.',
            onTap: () => context.push(AppRoutes.campusConfig),
          ),
        ],
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
