import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/admin/presentation/campus_config_screen.dart';
import '../../features/admin/presentation/dashboard_screen.dart';
import '../../features/admin/presentation/manage_screen.dart';
import '../../features/admin/presentation/send_logs_screen.dart';
import '../../features/admin/presentation/users_screen.dart';
import '../../features/admin/presentation/zalo_test_screen.dart';
import '../../features/auth/application/session.dart';
import '../../features/auth/domain/auth_repository.dart';
import '../../features/auth/presentation/blocked_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/otp_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/profile_setup_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/reports/presentation/home_screen.dart';
import '../../features/reports/presentation/my_reports_screen.dart';
import '../../features/reports/presentation/new_report_screen.dart';
import '../../features/reports/presentation/report_detail_screen.dart';
import '../../features/safety/broadcast_compose_screen.dart';
import '../../features/safety/incident_map_screen.dart';
import '../../features/safety/walk_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/staff/presentation/assigned_screen.dart';
import '../../features/staff/presentation/incident_queue_screen.dart';
import 'home_shell.dart';
import 'role_navigation.dart';

/// Báo cho go_router chạy lại `redirect` mỗi khi phiên đăng nhập thay đổi.
class _SessionListenable extends ChangeNotifier {
  void notify() => notifyListeners();
}

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _SessionListenable();
  ref.listen(sessionProvider, (_, _) => refresh.notify());
  ref.onDispose(refresh.dispose);

  NoTransitionPage<void> tab(Widget child) => NoTransitionPage(child: child);

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    redirect: (context, state) => resolveRedirect(ref.read(sessionProvider), state.uri.toString()),
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: AppRoutes.blocked, builder: (_, _) => const BlockedScreen()),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, _) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (_, _) => const ForgotPasswordScreen(),
        routes: [
          GoRoute(
            path: 'reset',
            redirect: (_, state) => state.extra is OtpChallengeInfo ? null : AppRoutes.forgotPassword,
            builder: (_, state) => ResetPasswordScreen(challenge: state.extra! as OtpChallengeInfo),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (_, _) => const RegisterScreen(),
        routes: [
          GoRoute(
            path: 'otp',
            redirect: (_, state) => state.extra is OtpChallengeInfo ? null : AppRoutes.register,
            builder: (_, state) => OtpScreen(challenge: state.extra! as OtpChallengeInfo),
          ),
        ],
      ),
      GoRoute(path: AppRoutes.profileSetup, builder: (_, _) => const ProfileSetupScreen()),
      ShellRoute(
        builder: (context, state, child) => HomeShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: AppRoutes.home, pageBuilder: (_, _) => tab(const HomeScreen())),
          GoRoute(path: AppRoutes.myReports, pageBuilder: (_, _) => tab(const MyReportsScreen())),
          GoRoute(path: AppRoutes.queue, pageBuilder: (_, _) => tab(const IncidentQueueScreen())),
          GoRoute(path: AppRoutes.assigned, pageBuilder: (_, _) => tab(const AssignedScreen())),
          GoRoute(path: AppRoutes.map, pageBuilder: (_, _) => tab(const IncidentMapScreen())),
          GoRoute(path: AppRoutes.dashboard, pageBuilder: (_, _) => tab(const DashboardScreen())),
          GoRoute(path: AppRoutes.manage, pageBuilder: (_, _) => tab(const ManageScreen())),
          GoRoute(path: AppRoutes.settings, pageBuilder: (_, _) => tab(const SettingsScreen())),
        ],
      ),
      GoRoute(
        path: AppRoutes.newReport,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const NewReportScreen(),
      ),
      GoRoute(
        path: '/report/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => ReportDetailScreen(reportId: state.pathParameters['id']!),
      ),
      GoRoute(path: AppRoutes.users, builder: (_, _) => const UsersScreen()),
      GoRoute(path: AppRoutes.campusConfig, builder: (_, _) => const CampusConfigScreen()),
      GoRoute(path: AppRoutes.zaloTest, builder: (_, _) => const ZaloTestScreen()),
      GoRoute(path: AppRoutes.sendLogs, builder: (_, _) => const SendLogsScreen()),
      GoRoute(path: AppRoutes.broadcasts, builder: (_, _) => const BroadcastComposeScreen()),
      GoRoute(
        path: AppRoutes.walk,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const WalkScreen(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
