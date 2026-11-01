// Chụp ảnh các màn chính bằng dữ liệu mẫu để rà soát giao diện (không nằm trong bộ test mặc định).
//
//   flutter test tool/screenshots/capture_test.dart --update-goldens
//
// Ảnh nằm ở tool/screenshots/out/. Dữ liệu dưới đây chỉ dùng để chụp ảnh, không dùng khi chạy app.
import 'dart:io';

import 'package:campus_core/campus_core.dart';
import 'package:campus_safety/core/router/home_shell.dart';
import 'package:campus_safety/core/router/role_navigation.dart';
import 'package:campus_safety/core/services/location_service.dart';
import 'package:campus_safety/core/theme/app_theme.dart';
import 'package:campus_safety/core/widgets/offline_banner.dart';
import 'package:campus_safety/features/admin/data/admin_repository.dart';
import 'package:campus_safety/features/admin/presentation/dashboard_screen.dart';
import 'package:campus_safety/features/admin/presentation/manage_screen.dart';
import 'package:campus_safety/features/auth/application/session.dart';
import 'package:campus_safety/features/auth/domain/app_user.dart';
import 'package:campus_safety/features/auth/domain/auth_repository.dart';
import 'package:campus_safety/features/auth/presentation/otp_screen.dart';
import 'package:campus_safety/features/auth/presentation/login_screen.dart';
import 'package:campus_safety/features/auth/presentation/register_screen.dart';
import 'package:campus_safety/features/campus/campus_info.dart';
import 'package:campus_safety/features/reports/application/report_providers.dart';
import 'package:campus_safety/features/reports/domain/report.dart';
import 'package:campus_safety/features/reports/presentation/home_screen.dart';
import 'package:campus_safety/features/reports/presentation/my_reports_screen.dart';
import 'package:campus_safety/features/reports/presentation/new_report_screen.dart';
import 'package:campus_safety/features/reports/presentation/report_detail_screen.dart';
import 'package:campus_safety/features/settings/presentation/settings_screen.dart';
import 'package:campus_safety/features/staff/presentation/incident_queue_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

final now = DateTime.now();

AppUser person(UserRole role, String name, {bool onDuty = false}) => AppUser(
      uid: 'uid-${role.wire}',
      email: 'khoa@gmail.com',
      phone: '0912345678',
      displayName: name,
      role: role,
      memberType: role == UserRole.reporter ? MemberType.student : MemberType.staff,
      active: true,
      onDuty: onDuty,
    );

Report sample(
  String id,
  IncidentType type,
  Severity severity,
  ReportStatus status, {
  Duration age = const Duration(minutes: 12),
  bool emergency = false,
  bool anonymous = false,
  String building = 'Toà A2',
  String? assignee,
}) {
  final created = now.subtract(age);
  return Report(
    id: id,
    code: 'SC-261019-$id',
    type: type,
    severity: severity,
    status: status,
    description: 'Hai nhóm sinh viên xô xát ở hành lang tầng 3, một bạn bị chảy máu mũi. Cần bảo vệ tới ngay.',
    occurredAt: created,
    createdAt: created,
    updatedAt: created,
    emergency: emergency,
    anonymous: anonymous,
    building: building,
    floor: '3',
    room: '305',
    locationText: formatLocation(building: building, floor: '3', room: '305'),
    latitude: 21.0285,
    longitude: 105.8542,
    accuracyMeters: 9,
    reporterName: anonymous ? null : 'Trần Minh Khoa',
    reporterPhone: anonymous ? null : '0912345678',
    reporterMemberType: anonymous ? null : MemberType.student,
    assigneeUid: assignee == null ? null : 'uid-guard',
    assigneeName: assignee,
  );
}

final reports = [
  sample('K7Q4', IncidentType.fight, Severity.critical, ReportStatus.submitted, emergency: true, anonymous: true),
  sample('M2PX', IncidentType.theft, Severity.high, ReportStatus.inProgress,
      age: const Duration(hours: 2), building: 'Bãi xe', assignee: 'Lê Văn Hùng'),
  sample('B8RT', IncidentType.suspicious, Severity.medium, ReportStatus.received,
      age: const Duration(hours: 5), building: 'Thư viện', assignee: 'Phạm Quốc Bảo'),
  sample('C3HN', IncidentType.damage, Severity.low, ReportStatus.resolved,
      age: const Duration(days: 1, hours: 3), building: 'Ký túc xá'),
];

const campus = CampusInfo(
  campusName: 'Trường Đại học Bách khoa',
  hotline: '0243 868 1234',
  buildings: ['Toà A1', 'Toà A2', 'Thư viện', 'Bãi xe', 'Ký túc xá'],
);

class _FixedLocation implements LocationService {
  @override
  Future<LocationFix> current() async => const LocationFix(latitude: 21.0285, longitude: 105.8542, accuracyMeters: 9);

  @override
  Future<void> openSettings() async {}
}

List<Override> overrides(AppUser user) => [
      signedInUserProvider.overrideWithValue(user),
      sessionProvider.overrideWithValue(SessionReady(user)),
      campusInfoProvider.overrideWith((ref) async => campus),
      offlineProvider.overrideWith((ref) => Stream.value(false)),
      locationServiceProvider.overrideWithValue(_FixedLocation()),
      myReportsProvider.overrideWith((ref) => Stream.value(reports.map(ReportSummary.fromReport).toList())),
      openReportsProvider.overrideWith((ref) => Stream.value(reports.where((r) => r.status.isOpen).toList())),
      reportsSinceProvider.overrideWith((ref, _) => Stream.value(reports)),
      assignedToMeProvider.overrideWith((ref) => Stream.value(reports.sublist(1, 3))),
      reportDetailProvider.overrideWith(
        (ref, id) => Stream.value(ReportDetail(report: reports.firstWhere((r) => r.id == id), events: [
          ReportEventItem(
            id: 'e1',
            type: ReportEventType.created,
            createdAt: now.subtract(const Duration(minutes: 12)),
            actorName: 'Người báo (ẩn danh)',
            actorRole: UserRole.reporter,
            toStatus: ReportStatus.submitted,
            note: 'Báo cáo khẩn cấp',
          ),
          ReportEventItem(
            id: 'e2',
            type: ReportEventType.comment,
            createdAt: now.subtract(const Duration(minutes: 9)),
            actorName: 'Người báo (ẩn danh)',
            actorRole: UserRole.reporter,
            note: 'Nhóm đó đang đi về phía cầu thang bộ phía tây.',
          ),
        ])),
      ),
      staffProvider.overrideWith((ref) => Stream.value([person(UserRole.guard, 'Lê Văn Hùng', onDuty: true)])),
    ];

Future<void> loadFonts() async {
  final viet = FontLoader('BeVietnamPro');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    viet.addFont(rootBundle.load('assets/fonts/BeVietnamPro-$w.ttf'));
  }
  await viet.load();
  final sdk = Platform.environment['FLUTTER_ROOT'] ?? r'D:\flutter\flutter';
  final iconFile = File('$sdk/bin/cache/artifacts/material_fonts/materialicons-regular.otf');
  final icons = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(Uint8List.fromList(iconFile.readAsBytesSync()))));
  await icons.load();
}

Future<void> shoot(
  WidgetTester tester,
  String name,
  Widget screen, {
  required AppUser user,
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
  Future<void> Function(WidgetTester)? interact,
}) async {
  tester.view.physicalSize = const Size(412 * 2, 915 * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    retry: (_, _) => null,
    overrides: overrides(user),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
      locale: const Locale('vi'),
      supportedLocales: const [Locale('vi')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: screen,
    ),
  ));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
  if (interact != null) await interact(tester);
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('out/$name.png'));
}

void main() {
  setUpAll(loadFonts);

  final student = person(UserRole.reporter, 'Trần Minh Khoa');
  final guard = person(UserRole.guard, 'Lê Văn Hùng');
  final admin = person(UserRole.admin, 'Đỗ Thu Hà');
  Widget shell(String path, Widget child) => HomeShell(location: path, child: child);

  for (final b in Brightness.values) {
    final s = b.name;
    testWidgets('login $s', (t) => shoot(t, 'login_$s', const LoginScreen(), user: student, brightness: b));
    testWidgets('register $s', (t) => shoot(t, 'register_$s', const RegisterScreen(), user: student, brightness: b));
    testWidgets('home $s', (t) => shoot(t, 'home_$s', shell(AppRoutes.home, const HomeScreen()), user: student, brightness: b));
    testWidgets('emergency $s', (t) => shoot(
          t,
          'emergency_$s',
          shell(AppRoutes.home, const HomeScreen()),
          user: student,
          brightness: b,
          interact: (t) async {
            await t.tap(find.byKey(const Key('emergency-button')));
            await t.pump(const Duration(milliseconds: 400));
            await t.pump(const Duration(milliseconds: 400));
          },
        ));
    testWidgets('detail $s', (t) => shoot(t, 'detail_guard_$s', const ReportDetailScreen(reportId: 'K7Q4'), user: guard, brightness: b));
    testWidgets('queue $s', (t) => shoot(t, 'queue_guard_$s', shell(AppRoutes.queue, const IncidentQueueScreen()), user: guard, brightness: b));
    testWidgets('dashboard $s', (t) => shoot(t, 'dashboard_$s', shell(AppRoutes.dashboard, const DashboardScreen()), user: admin, brightness: b));
  }
  testWidgets('otp', (t) => shoot(
        t,
        'otp_light',
        const OtpScreen(
          challenge: OtpChallengeInfo(
            email: 'nguoi.dung@gmail.com',
            emailMasked: 'ng***@gmail.com',
            expiresIn: Duration(minutes: 5),
            resendAfter: Duration(seconds: 60),
            mode: 'email',
            draft: RegistrationDraft(
              email: 'nguoi.dung@gmail.com',
              username: 'nguoidung',
              password: 'matkhau123',
              displayName: 'Người dùng',
            ),
          ),
        ),
        user: student,
      ));
  testWidgets('new report', (t) => shoot(t, 'new_report_light', const NewReportScreen(), user: student));
  testWidgets('new report errors', (t) => shoot(
        t,
        'new_report_errors_light',
        const NewReportScreen(),
        user: student,
        interact: (t) async {
          await t.tap(find.byKey(const Key('submit-report')));
          await t.pump(const Duration(milliseconds: 400));
          await t.pump(const Duration(seconds: 1));
        },
      ));
  testWidgets('my reports', (t) => shoot(t, 'my_reports_light', shell(AppRoutes.myReports, const MyReportsScreen()), user: student));
  testWidgets('manage', (t) => shoot(t, 'manage_light', shell(AppRoutes.manage, const ManageScreen()), user: admin));
  testWidgets('settings guard', (t) => shoot(t, 'settings_guard_light', shell(AppRoutes.settings, const SettingsScreen()), user: guard));
  testWidgets('home text 200%', (t) => shoot(t, 'home_text200', shell(AppRoutes.home, const HomeScreen()), user: student, textScale: 2));
  testWidgets('queue text 200%', (t) => shoot(t, 'queue_text200', shell(AppRoutes.queue, const IncidentQueueScreen()), user: guard, textScale: 2));
}
