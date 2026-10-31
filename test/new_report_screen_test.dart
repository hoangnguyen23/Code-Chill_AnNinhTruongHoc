import 'package:campus_core/campus_core.dart';
import 'package:campus_safety/core/network/api_error.dart';
import 'package:campus_safety/core/services/image_service.dart';
import 'package:campus_safety/core/services/location_service.dart';
import 'package:campus_safety/core/theme/app_theme.dart';
import 'package:campus_safety/features/auth/application/session.dart';
import 'package:campus_safety/features/auth/domain/app_user.dart';
import 'package:campus_safety/features/campus/campus_info.dart';
import 'package:campus_safety/features/reports/application/report_providers.dart';
import 'package:campus_safety/features/reports/domain/report.dart';
import 'package:campus_safety/features/reports/domain/report_repository.dart';
import 'package:campus_safety/features/reports/presentation/new_report_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Repository giả cho widget test: ghi lại báo cáo được gửi, không gọi mạng.
class FakeReportRepository implements ReportRepository {
  ReportDraft? submitted;
  ApiError? failWith;

  @override
  Future<SubmitReportResult> submit(ReportDraft draft) async {
    submitted = draft;
    final error = failWith;
    if (error != null) throw error;
    return const SubmitReportResult(
      id: 'r1',
      code: 'SC-261019-K7Q4',
      reporterConfirmation: ZaloDelivery(success: true),
      guardsTotal: 2,
      guardsAlerted: 2,
      guardFailureMessages: [],
      pending: false,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(invocation.memberName.toString());
}

class FakeImageService implements ImageService {
  @override
  Future<PickedImage?> pick({required bool fromCamera}) async => null;

  @override
  Future<String> upload(PickedImage image, {required String uploaderUid}) async =>
      'report_images/AbCdEfGhIjKlMnOpQrStUvWx12345678.jpg';

  @override
  Future<String> downloadUrl(String path) async => '';
}

class FakeLocationService implements LocationService {
  @override
  Future<LocationFix> current() async => const LocationFix(latitude: 21.0285, longitude: 105.8542, accuracyMeters: 8);

  @override
  Future<void> openSettings() async {}
}

void main() {
  late FakeReportRepository repo;

  const student = AppUser(
    uid: 'u1',
    email: 'khoa@gmail.com',
    phone: '0912345678',
    displayName: 'Trần Minh Khoa',
    role: UserRole.reporter,
    memberType: MemberType.student,
    active: true,
    onDuty: false,
  );

  setUp(() => repo = FakeReportRepository());

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 3400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, _) => const NewReportScreen()),
      GoRoute(path: '/report/:id', builder: (_, s) => Scaffold(body: Text('Chi tiết ${s.pathParameters['id']}'))),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        signedInUserProvider.overrideWithValue(student),
        campusInfoProvider.overrideWith(
          (ref) async => const CampusInfo(
            campusName: 'Trường thử nghiệm',
            hotline: '0243 868 1234',
            buildings: ['Toà A1', 'Thư viện', 'Bãi xe'],
            zaloMode: 'development',
          ),
        ),
        reportRepositoryProvider.overrideWithValue(repo),
        imageServiceProvider.overrideWithValue(FakeImageService()),
        locationServiceProvider.overrideWithValue(FakeLocationService()),
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

  testWidgets('bấm gửi khi chưa nhập gì: báo lỗi từng mục, không gửi', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('submit-report')));
    await tester.pumpAndSettle();

    expect(find.text('Kiểm tra lại các mục được đánh dấu.'), findsOneWidget);
    expect(find.text('Chọn loại sự cố.'), findsOneWidget);
    expect(find.textContaining('Mô tả ít nhất'), findsOneWidget);
    expect(find.text('Chọn toà nhà hoặc khu vực xảy ra sự cố.'), findsOneWidget);
    expect(repo.submitted, isNull);
  });

  testWidgets('đổi mức độ thì hiện gợi ý tương ứng', (tester) async {
    await pumpScreen(tester);
    expect(find.text(severityHint(Severity.medium)), findsOneWidget);
    await tester.tap(find.text('Cao'));
    await tester.pumpAndSettle();
    expect(find.text(severityHint(Severity.high)), findsOneWidget);
  });

  testWidgets('điền đủ và gửi: gửi đúng dữ liệu, hiện mã sự cố và kết quả Zalo', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Trộm cắp'));
    await tester.tap(find.text('Cao'));
    await tester.enterText(find.byKey(const Key('description')), 'Mất xe đạp màu xanh ở bãi xe, khoá bị cắt');
    await tester.tap(find.byKey(const Key('building')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bãi xe').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đính kèm vị trí GPS'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Đã đính kèm vị trí GPS'), findsOneWidget);
    await tester.tap(find.text('Gửi ẩn danh'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('submit-report')));
    await tester.pumpAndSettle();

    final sent = repo.submitted!;
    expect(sent.type, IncidentType.theft);
    expect(sent.severity, Severity.high);
    expect(sent.building, 'Bãi xe');
    expect(sent.anonymous, isTrue);
    expect(sent.emergency, isFalse);
    expect(sent.latitude, 21.0285);
    expect(sent.description, 'Mất xe đạp màu xanh ở bãi xe, khoá bị cắt');

    expect(find.text('Đã gửi báo cáo'), findsOneWidget);
    expect(find.text('SC-261019-K7Q4'), findsOneWidget);
    expect(find.text('Đã gửi tin Zalo xác nhận tới số của bạn.'), findsOneWidget);
    expect(find.text('Đã báo Zalo cho 2/2 bảo vệ trực.'), findsOneWidget);

    await tester.tap(find.text('Xem báo cáo'));
    await tester.pumpAndSettle();
    expect(find.text('Chi tiết r1'), findsOneWidget);
  });

  testWidgets('backend báo lỗi: hiện thông báo tiếng Việt, giữ nguyên form', (tester) async {
    repo.failWith = const ApiError(
      code: 'validation_failed',
      statusCode: 422,
      message: 'Thời gian xảy ra không được ở tương lai.',
      fieldErrors: {'occurredAt': 'Thời gian xảy ra không được ở tương lai.'},
    );
    await pumpScreen(tester);
    await tester.tap(find.text('Đánh nhau'));
    await tester.enterText(find.byKey(const Key('description')), 'Hai nhóm sinh viên xô xát trước căng tin');
    await tester.tap(find.byKey(const Key('building')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Toà A1').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('submit-report')));
    await tester.pumpAndSettle();

    expect(find.text('Thời gian xảy ra không được ở tương lai.'), findsNWidgets(2));
    expect(find.text('Đã gửi báo cáo'), findsNothing);
    expect(find.text('Hai nhóm sinh viên xô xát trước căng tin'), findsOneWidget);
  });
}
