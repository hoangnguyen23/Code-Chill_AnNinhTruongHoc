import 'dart:async';

import 'package:campus_core/campus_core.dart';
import 'package:campus_safety/core/services/image_service.dart';
import 'package:campus_safety/core/services/location_service.dart';
import 'package:campus_safety/core/theme/app_theme.dart';
import 'package:campus_safety/features/auth/application/session.dart';
import 'package:campus_safety/features/auth/domain/app_user.dart';
import 'package:campus_safety/features/campus/campus_info.dart';
import 'package:campus_safety/features/reports/application/report_providers.dart';
import 'package:campus_safety/features/reports/domain/report.dart';
import 'package:campus_safety/features/reports/presentation/emergency_sheet.dart';
import 'package:campus_safety/features/reports/presentation/widgets/report_timeline.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'new_report_screen_test.dart' show FakeImageService, FakeReportRepository;

/// GPS trả kết quả khi test gọi [complete] / [fail].
class ControlledLocation implements LocationService {
  // Tạo Completer khi app gọi current() (cùng zone với app) để lỗi tới được catch của app cả khi
  // chạy trên máy thật, nơi frame không chạy trong zone của test.
  Completer<LocationFix>? _completer;
  Completer<LocationFix> get _fix => _completer ??= Completer<LocationFix>();

  void complete() => _fix.complete(const LocationFix(latitude: 21.0285, longitude: 105.8542, accuracyMeters: 12));

  void fail() => _fix.completeError(const LocationException('GPS đang tắt. Bật Vị trí trong cài đặt máy.'));

  @override
  Future<LocationFix> current() => _fix.future;

  @override
  Future<void> openSettings() async {}
}

const _student = AppUser(
  uid: 'u1',
  email: 'khoa@gmail.com',
  phone: '0912345678',
  displayName: 'Trần Minh Khoa',
  role: UserRole.reporter,
  memberType: MemberType.student,
  active: true,
  onDuty: false,
);

void main() {
  Future<void> pumpSheet(WidgetTester tester, FakeReportRepository repo, ControlledLocation location) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        signedInUserProvider.overrideWithValue(_student),
        campusInfoProvider.overrideWith(
          (ref) async => const CampusInfo(
            campusName: 'Trường thử nghiệm',
            hotline: '0243 868 1234',
            buildings: ['Toà A1', 'Bãi xe'],
          ),
        ),
        reportRepositoryProvider.overrideWithValue(repo),
        imageServiceProvider.overrideWithValue(FakeImageService()),
        locationServiceProvider.overrideWithValue(location),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('vi')],
        locale: const Locale('vi'),
        home: const Scaffold(body: EmergencySheet()),
      ),
    ));
    await tester.pump();
  }

  testWidgets('bấm gửi khi GPS chưa xong: chờ GPS rồi gửi, không báo lỗi', (tester) async {
    final repo = FakeReportRepository();
    final location = ControlledLocation();
    await pumpSheet(tester, repo, location);

    expect(find.text('Đang lấy vị trí GPS…'), findsOneWidget);
    await tester.tap(find.byKey(const Key('send-emergency')));
    await tester.pump();
    expect(find.text('Đang lấy vị trí rồi gửi…'), findsOneWidget);
    expect(repo.submitted, isNull);

    location.complete();
    await tester.pumpAndSettle();

    final sent = repo.submitted!;
    expect(sent.emergency, isTrue);
    expect(sent.latitude, 21.0285);
    expect(sent.effectiveSeverity, Severity.critical);
    expect(find.text('Đã gửi cảnh báo khẩn cấp'), findsOneWidget);
    expect(find.text('SC-261019-K7Q4'), findsOneWidget);
  });

  testWidgets('GPS lỗi và chưa chọn khu vực: báo cách xử lý, không gửi', (tester) async {
    final repo = FakeReportRepository();
    final location = ControlledLocation();
    await pumpSheet(tester, repo, location);

    location.fail();
    await tester.pumpAndSettle();
    expect(find.text('GPS đang tắt. Bật Vị trí trong cài đặt máy.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('send-emergency')));
    await tester.pumpAndSettle();
    expect(repo.submitted, isNull);
    expect(find.textContaining('Chọn khu vực rồi gửi lại'), findsOneWidget);
    // Nút gọi trực luôn hiện trong sheet.
    expect(find.textContaining('Gọi trực an ninh'), findsOneWidget);
  });

  group('ReportTimeline', () {
    final events = [
      ReportEventItem(
        id: 'e1',
        type: ReportEventType.comment,
        createdAt: DateTime(2026, 10, 19, 9),
        actorName: 'Người báo (ẩn danh)',
        actorRole: UserRole.reporter,
        note: 'Họ đi về phía cổng sau.',
      ),
    ];

    Future<void> pumpTimeline(WidgetTester tester, {required bool anonymousOwner}) => tester.pumpWidget(MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ReportTimeline(events: events, currentUid: 'u1', viewerIsAnonymousReporter: anonymousOwner),
          ),
        ));

    testWidgets('người báo ẩn danh thấy bình luận của mình là "Bạn"', (tester) async {
      await pumpTimeline(tester, anonymousOwner: true);
      expect(find.text('Bạn'), findsOneWidget);
    });

    testWidgets('bảo vệ thấy "Người báo (ẩn danh)"', (tester) async {
      await pumpTimeline(tester, anonymousOwner: false);
      expect(find.text('Người báo (ẩn danh)'), findsOneWidget);
      expect(find.text('Bạn'), findsNothing);
    });
  });
}
