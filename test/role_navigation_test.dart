import 'package:campus_core/campus_core.dart';
import 'package:campus_safety/core/router/role_navigation.dart';
import 'package:campus_safety/features/auth/application/session.dart';
import 'package:campus_safety/features/auth/domain/app_user.dart';
import 'package:flutter_test/flutter_test.dart';

AppUser user(UserRole role, {String name = 'Ngô Thanh Vân', bool active = true}) => AppUser(
      uid: 'u-${role.wire}',
      email: 'van@gmail.com',
      phone: '0912345678',
      displayName: name,
      role: role,
      memberType: MemberType.student,
      active: active,
      onDuty: false,
    );

void main() {
  group('thanh điều hướng theo vai trò', () {
    test('người báo', () {
      expect(destinationsFor(UserRole.reporter).map((d) => d.path),
          [AppRoutes.home, AppRoutes.myReports, AppRoutes.settings]);
    });
    test('bảo vệ', () {
      expect(destinationsFor(UserRole.guard).map((d) => d.path),
          [AppRoutes.queue, AppRoutes.map, AppRoutes.assigned, AppRoutes.settings]);
    });
    test('quản trị', () {
      expect(destinationsFor(UserRole.admin).map((d) => d.path),
          [AppRoutes.dashboard, AppRoutes.queue, AppRoutes.map, AppRoutes.manage, AppRoutes.settings]);
    });
  });

  group('quyền vào màn hình', () {
    test('người báo không vào được màn bảo vệ/quản trị', () {
      for (final path in [
        AppRoutes.queue,
        AppRoutes.assigned,
        AppRoutes.dashboard,
        AppRoutes.map,
        AppRoutes.broadcasts,
      ]) {
        expect(canAccess(UserRole.reporter, path), isFalse, reason: path);
      }
      expect(canAccess(UserRole.reporter, AppRoutes.report('abc')), isTrue);
      expect(canAccess(UserRole.reporter, AppRoutes.newReport), isTrue);
      expect(canAccess(UserRole.reporter, AppRoutes.walk), isTrue);
    });
    test('bảo vệ không vào màn quản trị', () {
      expect(canAccess(UserRole.guard, AppRoutes.queue), isTrue);
      expect(canAccess(UserRole.guard, AppRoutes.users), isFalse);
      expect(canAccess(UserRole.guard, AppRoutes.campusConfig), isFalse);
      expect(canAccess(UserRole.guard, AppRoutes.home), isFalse);
      expect(canAccess(UserRole.guard, AppRoutes.map), isTrue);
      expect(canAccess(UserRole.guard, AppRoutes.broadcasts), isFalse);
    });
    test('chỉ quản trị vào màn quản lý', () {
      expect(canAccess(UserRole.admin, AppRoutes.campusConfig), isTrue);
      expect(canAccess(UserRole.admin, AppRoutes.broadcasts), isTrue);
      expect(canAccess(UserRole.admin, AppRoutes.assigned), isFalse);
    });
  });

  group('resolveRedirect', () {
    test('đang tải thì ở màn chờ', () {
      expect(resolveRedirect(const SessionLoading(), AppRoutes.home), AppRoutes.splash);
      expect(resolveRedirect(const SessionLoading(), AppRoutes.splash), isNull);
    });
    test('chưa đăng nhập thì về màn đăng nhập', () {
      expect(resolveRedirect(const SessionSignedOut(), AppRoutes.queue), AppRoutes.login);
      expect(resolveRedirect(const SessionSignedOut(), AppRoutes.register), isNull);
      expect(resolveRedirect(const SessionSignedOut(), AppRoutes.registerOtp), isNull);
    });
    test('thiếu tên thì hoàn tất hồ sơ trước', () {
      expect(resolveRedirect(SessionReady(user(UserRole.reporter, name: '')), AppRoutes.home), AppRoutes.profileSetup);
    });
    test('đăng nhập xong rời màn đăng nhập về trang chủ theo vai trò', () {
      expect(resolveRedirect(SessionReady(user(UserRole.reporter)), AppRoutes.login), AppRoutes.home);
      expect(resolveRedirect(SessionReady(user(UserRole.guard)), AppRoutes.splash), AppRoutes.queue);
      expect(resolveRedirect(SessionReady(user(UserRole.admin)), AppRoutes.profileSetup), AppRoutes.dashboard);
    });
    test('vào màn không đúng quyền thì bị đưa về trang chủ', () {
      expect(resolveRedirect(SessionReady(user(UserRole.reporter)), AppRoutes.campusConfig), AppRoutes.home);
      expect(resolveRedirect(SessionReady(user(UserRole.guard)), AppRoutes.dashboard), AppRoutes.queue);
      expect(resolveRedirect(SessionReady(user(UserRole.admin)), AppRoutes.campusConfig), isNull);
    });
    test('tài khoản bị khoá', () {
      expect(resolveRedirect(const SessionBlocked('Tài khoản đã bị khoá.'), AppRoutes.home), AppRoutes.blocked);
    });
  });
}
