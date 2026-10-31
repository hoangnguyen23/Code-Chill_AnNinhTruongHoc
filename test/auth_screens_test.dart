import 'package:campus_core/campus_core.dart';
import 'package:campus_safety/core/network/api_error.dart';
import 'package:campus_safety/core/router/role_navigation.dart';
import 'package:campus_safety/core/theme/app_theme.dart';
import 'package:campus_safety/features/auth/application/session.dart';
import 'package:campus_safety/features/auth/domain/app_user.dart';
import 'package:campus_safety/features/auth/domain/auth_repository.dart';
import 'package:campus_safety/features/auth/presentation/forgot_password_screen.dart';
import 'package:campus_safety/features/auth/presentation/login_screen.dart';
import 'package:campus_safety/features/auth/presentation/otp_screen.dart';
import 'package:campus_safety/features/auth/presentation/register_screen.dart';
import 'package:campus_safety/features/campus/campus_info.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Repository giả: ghi lại lời gọi, không gọi mạng.
class FakeAuthRepository implements AuthRepository {
  (String, String)? loggedIn;
  RegistrationDraft? requested;
  (String, String)? verified;
  ApiError? loginError;

  static const _user = AppUser(
    uid: 'u1',
    email: 'khoa@gmail.com',
    phone: '',
    username: 'khoa.tran',
    displayName: 'Trần Minh Khoa',
    role: UserRole.reporter,
    memberType: MemberType.student,
    active: true,
    onDuty: false,
  );

  @override
  Future<AppUser> login(String username, String password) async {
    loggedIn = (username, password);
    final e = loginError;
    if (e != null) throw e;
    return _user;
  }

  @override
  Future<OtpChallengeInfo> requestRegistration(RegistrationDraft draft) async {
    requested = draft;
    return OtpChallengeInfo(
      email: draft.email.trim(),
      emailMasked: 'kh***@gmail.com',
      expiresIn: const Duration(minutes: 5),
      resendAfter: const Duration(seconds: 60),
      mode: 'email',
      draft: draft,
    );
  }

  @override
  Future<AppUser> verifyRegistration(String email, String code) async {
    verified = (email, code);
    return _user;
  }

  String? resetRequested;
  (String, String, String)? resetDone;

  @override
  Future<OtpChallengeInfo> requestPasswordReset(String email) async {
    resetRequested = email;
    return OtpChallengeInfo(
      email: email.trim(),
      emailMasked: 'kh***@gmail.com',
      expiresIn: const Duration(minutes: 5),
      resendAfter: const Duration(seconds: 60),
      mode: 'email',
    );
  }

  @override
  Future<AppUser> resetPassword(String email, String code, String newPassword) async {
    resetDone = (email, code, newPassword);
    return _user;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  late FakeAuthRepository repo;

  setUp(() => repo = FakeAuthRepository());

  Future<void> pump(WidgetTester tester, String initial) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final router = GoRouter(initialLocation: initial, routes: [
      GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (_, _) => const ForgotPasswordScreen(),
        routes: [
          GoRoute(path: 'reset', builder: (_, s) => ResetPasswordScreen(challenge: s.extra! as OtpChallengeInfo)),
        ],
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (_, _) => const RegisterScreen(),
        routes: [
          GoRoute(path: 'otp', builder: (_, s) => OtpScreen(challenge: s.extra! as OtpChallengeInfo)),
        ],
      ),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(repo),
        campusInfoProvider.overrideWith(
          (ref) async => const CampusInfo(campusName: 'Trường thử nghiệm', hotline: null, buildings: [], zaloMode: 'off'),
        ),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light(),
        locale: const Locale('vi'),
        supportedLocales: const [Locale('vi')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        routerConfig: router,
      ),
    ));
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  testWidgets('đăng nhập: có ô tên đăng nhập và mật khẩu, báo lỗi khi bỏ trống', (tester) async {
    await pump(tester, AppRoutes.login);
    expect(field('Tên đăng nhập hoặc email'), findsOneWidget);
    expect(field('Mật khẩu'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
    await tester.pumpAndSettle();
    expect(find.text('Nhập tên đăng nhập hoặc email.'), findsOneWidget);
    expect(find.text('Nhập mật khẩu.'), findsOneWidget);
    expect(repo.loggedIn, isNull);

    await tester.enterText(field('Tên đăng nhập hoặc email'), 'khoa.tran');
    await tester.enterText(field('Mật khẩu'), 'matkhau123');
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
    await tester.pumpAndSettle();
    expect(repo.loggedIn, ('khoa.tran', 'matkhau123'));
  });

  testWidgets('đăng nhập sai: hiện lỗi từ máy chủ, xoá mật khẩu', (tester) async {
    repo.loginError = const ApiError(code: 'invalid_credentials', message: 'Tên đăng nhập hoặc mật khẩu không đúng.');
    await pump(tester, AppRoutes.login);
    await tester.enterText(field('Tên đăng nhập hoặc email'), 'khoa.tran');
    await tester.enterText(field('Mật khẩu'), 'sai12345');
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
    await tester.pumpAndSettle();
    expect(find.text('Tên đăng nhập hoặc mật khẩu không đúng.'), findsOneWidget);
    expect(find.text('sai12345'), findsNothing);
  });

  testWidgets('đăng ký: kiểm tra dữ liệu, gửi mã, nhập đúng OTP thì xác nhận', (tester) async {
    await pump(tester, AppRoutes.register);
    await tester.enterText(field('Họ và tên'), 'Trần Minh Khoa');
    await tester.enterText(field('Email'), 'khoa@gmail.com');
    await tester.enterText(field('Tên đăng nhập'), 'khoa.tran');
    await tester.enterText(field('Mật khẩu'), 'matkhau123');
    await tester.enterText(field('Nhập lại mật khẩu'), 'matkhau999');
    await tester.tap(find.text('Gửi mã xác nhận'));
    await tester.pumpAndSettle();
    expect(find.text('Mật khẩu nhập lại không khớp.'), findsOneWidget);
    expect(repo.requested, isNull);

    // Không còn ô chọn: tài khoản mới mặc định là Sinh viên.
    expect(find.byType(ChoiceChip), findsNothing);
    await tester.enterText(field('Nhập lại mật khẩu'), 'matkhau123');
    await tester.tap(find.text('Gửi mã xác nhận'));
    await tester.pumpAndSettle();
    expect(repo.requested!.username, 'khoa.tran');
    expect(repo.requested!.memberType, MemberType.student);
    expect(find.text('Xác nhận email'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, '482915');
    await tester.pumpAndSettle();
    expect(repo.verified, ('khoa@gmail.com', '482915'));
  });

  testWidgets('quên mật khẩu: nhập email, nhận mã, nhập đúng mã và mật khẩu mới', (tester) async {
    await pump(tester, AppRoutes.login);
    await tester.tap(find.text('Quên mật khẩu?'));
    await tester.pumpAndSettle();
    expect(find.text('Quên mật khẩu'), findsOneWidget);

    await tester.enterText(field('Email của tài khoản'), 'khoa@gmail.com');
    await tester.tap(find.text('Gửi mã xác nhận'));
    await tester.pumpAndSettle();
    expect(repo.resetRequested, 'khoa@gmail.com');
    expect(find.text('Đặt mật khẩu mới'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Đổi mật khẩu'));
    await tester.pumpAndSettle();
    expect(find.text('Nhập mã gồm 6 chữ số.'), findsOneWidget);
    expect(repo.resetDone, isNull);

    await tester.enterText(field('Mã OTP'), '482915');
    await tester.enterText(field('Mật khẩu mới'), 'matkhaumoi9');
    await tester.enterText(field('Nhập lại mật khẩu mới'), 'matkhaumoi9');
    await tester.tap(find.widgetWithText(FilledButton, 'Đổi mật khẩu'));
    await tester.pumpAndSettle();
    expect(repo.resetDone, ('khoa@gmail.com', '482915', 'matkhaumoi9'));
  });
}
