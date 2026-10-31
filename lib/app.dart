import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/config/app_config.dart';
import 'core/notifications/push_notifications.dart';
import 'core/router/app_router.dart';
import 'core/router/role_navigation.dart';
import 'core/settings/theme_mode_controller.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/application/session.dart';

class CampusSafetyApp extends ConsumerStatefulWidget {
  const CampusSafetyApp({super.key});

  @override
  ConsumerState<CampusSafetyApp> createState() => _CampusSafetyAppState();
}

class _CampusSafetyAppState extends ConsumerState<CampusSafetyApp> {
  StreamSubscription<String>? _taps;
  String? _registeredUid;

  @override
  void initState() {
    super.initState();
    final push = ref.read(pushNotificationsProvider);
    _taps = push.reportTaps.listen(_openReport);
  }

  @override
  void dispose() {
    _taps?.cancel();
    super.dispose();
  }

  void _openReport(String reportId) {
    if (ref.read(sessionProvider) is! SessionReady) return;
    unawaited(ref.read(appRouterProvider).push(AppRoutes.report(reportId)));
  }

  @override
  Widget build(BuildContext context) {
    // Đăng ký push khi đăng nhập xong; mở báo cáo nếu app được mở từ thông báo.
    ref.listen(sessionProvider, (previous, next) {
      if (next is SessionReady && next.user.uid != _registeredUid) {
        _registeredUid = next.user.uid;
        final push = ref.read(pushNotificationsProvider);
        unawaited(push.registerForCurrentUser());
        final pending = push.takePendingReportId();
        if (pending != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _openReport(pending));
        }
      } else if (next is SessionSignedOut) {
        _registeredUid = null;
      }
    });

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      locale: const Locale('vi'),
      supportedLocales: const [Locale('vi'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
