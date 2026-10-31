import 'package:campus_core/campus_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/auth/application/session.dart';

/// Một mục trên thanh điều hướng dưới.
class AppDestination {
  const AppDestination(this.path, this.label, this.icon, this.selectedIcon);

  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

abstract final class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const registerOtp = '/register/otp';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/forgot-password/reset';
  static const profileSetup = '/setup-profile';
  static const blocked = '/blocked';

  static const home = '/home';
  static const myReports = '/my-reports';
  static const queue = '/queue';
  static const assigned = '/assigned';
  static const dashboard = '/dashboard';
  static const manage = '/manage';
  static const settings = '/settings';
  static const map = '/map';
  static const walk = '/walk';

  static const newReport = '/report/new';
  static String report(String id) => '/report/$id';

  static const users = '/manage/users';
  static const campusConfig = '/manage/config';
  static const zaloTest = '/manage/zalo-test';
  static const sendLogs = '/manage/logs';
  static const broadcasts = '/manage/broadcasts';
}

const _settings = AppDestination(
  AppRoutes.settings,
  'Cài đặt',
  Icons.settings_outlined,
  Icons.settings_rounded,
);

const _queue = AppDestination(
  AppRoutes.queue,
  'Sự cố',
  Icons.notification_important_outlined,
  Icons.notification_important_rounded,
);

const _map = AppDestination(AppRoutes.map, 'Bản đồ', Icons.map_outlined, Icons.map_rounded);

/// Thanh điều hướng theo vai trò (DESIGN.md mục 9).
List<AppDestination> destinationsFor(UserRole role) => switch (role) {
      UserRole.reporter => const [
          AppDestination(AppRoutes.home, 'Trang chủ', Icons.home_outlined, Icons.home_rounded),
          AppDestination(AppRoutes.myReports, 'Báo cáo của tôi', Icons.receipt_long_outlined, Icons.receipt_long_rounded),
          _settings,
        ],
      UserRole.guard => const [
          _queue,
          _map,
          AppDestination(AppRoutes.assigned, 'Việc của tôi', Icons.assignment_ind_outlined, Icons.assignment_ind_rounded),
          _settings,
        ],
      UserRole.admin => const [
          AppDestination(AppRoutes.dashboard, 'Tổng quan', Icons.insights_outlined, Icons.insights_rounded),
          _queue,
          _map,
          AppDestination(AppRoutes.manage, 'Quản lý', Icons.admin_panel_settings_outlined, Icons.admin_panel_settings_rounded),
          _settings,
        ],
    };

String homePathFor(UserRole role) => destinationsFor(role).first.path;

/// Vai trò có được vào [location] không.
bool canAccess(UserRole role, String location) {
  final path = Uri.parse(location).path;
  if (path == AppRoutes.settings || path == AppRoutes.walk || path.startsWith('/report/')) return true;
  if (path == AppRoutes.map) return role.isStaff;
  if (path == AppRoutes.home || path == AppRoutes.myReports) return role == UserRole.reporter;
  if (path == AppRoutes.queue) return role.isStaff;
  if (path == AppRoutes.assigned) return role == UserRole.guard;
  if (path == AppRoutes.dashboard || path.startsWith(AppRoutes.manage)) return role == UserRole.admin;
  return false;
}

const _publicPaths = {
  AppRoutes.login,
  AppRoutes.register,
  AppRoutes.registerOtp,
  AppRoutes.forgotPassword,
  AppRoutes.resetPassword,
};
const _transitionalPaths = {AppRoutes.splash, AppRoutes.profileSetup, AppRoutes.blocked};

/// Quyết định chuyển hướng (thuần, có unit test). `null` nghĩa là giữ nguyên.
String? resolveRedirect(Session session, String location) {
  final path = Uri.parse(location).path;
  switch (session) {
    case SessionLoading():
      return path == AppRoutes.splash ? null : AppRoutes.splash;
    case SessionSignedOut():
      return _publicPaths.contains(path) ? null : AppRoutes.login;
    case SessionBlocked():
      return path == AppRoutes.blocked ? null : AppRoutes.blocked;
    case SessionReady(:final user):
      if (!user.profileComplete) {
        return path == AppRoutes.profileSetup ? null : AppRoutes.profileSetup;
      }
      if (_publicPaths.contains(path) || _transitionalPaths.contains(path)) {
        return homePathFor(user.role);
      }
      return canAccess(user.role, path) ? null : homePathFor(user.role);
  }
}
