import 'package:campus_core/campus_core.dart';
import 'package:campus_safety_backend/backend.dart';
import 'package:test/test.dart';

import 'support/fakes.dart';

class _FlakyUsers extends MemoryUserRepository {
  @override
  Future<List<UserRecord>> listStaff() => throw StateError('Firestore unavailable');
}

void main() {
  late TestClock clock;
  late MemoryUserRepository users;
  late MemoryReportRepository reports;
  late RecordingGateway gateway;
  late RecordingPushService push;
  late ReportService service;
  late UserRecord student, guardOnDuty, guardOff, admin;

  setUp(() {
    clock = TestClock(DateTime.utc(2026, 10, 19, 7));
    users = MemoryUserRepository();
    reports = MemoryReportRepository();
    gateway = RecordingGateway();
    push = RecordingPushService();
    student = users.seed(phone: '0912345678', name: 'Trần Minh Khoa', tokens: ['tok-student']);
    guardOnDuty = users.seed(phone: '0987654321', name: 'Lê Văn Hùng', role: UserRole.guard, onDuty: true, tokens: ['tok-g1']);
    guardOff = users.seed(phone: '0977111222', name: 'Phạm Quốc Bảo', role: UserRole.guard, tokens: ['tok-g2']);
    admin = users.seed(phone: '0901234567', name: 'Đỗ Thu Hà', role: UserRole.admin, tokens: ['tok-admin']);
    service = ReportService(
      reports: reports,
      users: users,
      clock: clock.call,
      notifications: NotificationService(
        gateway: gateway,
        push: push,
        users: users,
        extraDutyPhones: [VietnamPhone.parse('0933444555')],
      ),
    );
  });

  ReportDraft draft({bool anonymous = false, bool emergency = false}) => ReportDraft(
        type: IncidentType.theft,
        severity: Severity.high,
        description: emergency ? '' : 'Mất xe đạp ở bãi xe B, khoá bị cắt',
        occurredAt: clock.now.subtract(const Duration(minutes: 20)),
        building: 'Bãi xe',
        latitude: emergency ? 21.0285 : null,
        longitude: emergency ? 105.8542 : null,
        anonymous: anonymous,
        emergency: emergency,
      );

  test('tạo báo cáo: lưu trạng thái Đã gửi, mã sự cố, gửi Zalo xác nhận và cảnh báo bảo vệ trực', () async {
    final (report, summary) = await service.create(student, draft());
    expect(report.status, ReportStatus.submitted);
    expect(reportCodePattern.hasMatch(report.code), isTrue);

    final confirm = gateway.sent.firstWhere((m) => m.template == ZaloTemplateKey.reportReceived);
    expect(confirm.recipient, student.phone);
    expect(confirm.data['report_code'], report.code);
    expect(confirm.data['customer_name'], 'Trần Minh Khoa');

    final alerts = gateway.sent.where((m) => m.template == ZaloTemplateKey.guardAlert).toList();
    expect(alerts.map((m) => m.recipient.local).toSet(), {'0987654321', '0933444555'},
        reason: 'bảo vệ đang trực + số trực trong .env, không gửi bảo vệ nghỉ ca');
    expect(alerts.first.data['severity'], 'Cao');
    expect(summary.guardsAlerted, 2);

    final staffPush = push.sent.single;
    expect(staffPush.$1.toSet(), {'tok-g1', 'tok-g2', 'tok-admin'});
    expect(staffPush.$2.urgent, isTrue);
  });

  test('báo cáo ẩn danh: không lưu tên/số người báo trong tài liệu bảo vệ đọc được', () async {
    final (report, _) = await service.create(student, draft(anonymous: true));
    expect(report.reporterUid, isNull);
    expect(report.reporterName, isNull);
    expect(report.reporterPhone, isNull);
    expect(reports.events[report.id]!.single.actorName, 'Người báo (ẩn danh)');
    expect(reports.events[report.id]!.single.actorUid, isNull);
    // Người báo vẫn nhận xác nhận Zalo và vẫn theo dõi được báo cáo của mình.
    expect(reports.privates[report.id]!.phone, student.phone);
    expect(reports.userIndex[student.uid], contains(report.id));
  });

  test('người báo và bảo vệ chưa có số điện thoại: bỏ qua Zalo, vẫn push và vẫn lưu báo cáo', () async {
    final noPhone = users.seed(email: 'khong.so@gmail.com', name: 'Vũ An', tokens: ['tok-np']);
    users.seed(name: 'Bảo vệ chưa có số', role: UserRole.guard, onDuty: true, tokens: ['tok-g3']);
    final (report, summary) = await service.create(noPhone, draft());
    expect(report.reporterPhone, isNull);
    expect(reports.privates[report.id]!.email!.value, 'khong.so@gmail.com');
    expect(gateway.sent.where((m) => m.template == ZaloTemplateKey.reportReceived), isEmpty);
    expect(summary.reporterConfirmation, isNull);
    expect(gateway.sent.map((m) => m.recipient.local).toSet(), {'0987654321', '0933444555'});
    expect(push.sent.single.$1, contains('tok-g3'));

    final (_, sent) = await service.changeStatus(guardOnDuty, report.id, to: ReportStatus.received);
    expect(sent, isNull, reason: 'không có số thì không gửi Zalo cập nhật trạng thái');
  });

  test('Zalo tắt: không gửi Zalo, không báo lỗi Zalo, vẫn push cho bảo vệ và quản trị', () async {
    final off = ReportService(
      reports: reports,
      users: users,
      clock: clock.call,
      notifications: NotificationService(
        gateway: const DisabledNotificationGateway(),
        push: push,
        users: users,
        extraDutyPhones: [VietnamPhone.parse('0933444555')],
      ),
    );
    final (report, summary) = await off.create(student, draft());
    expect(summary.reporterConfirmation, isNull);
    expect(summary.guardsTotal, 0);
    expect(summary.guardFailures, isEmpty);
    expect(summary.pushDelivered, 3);
    final (_, sent) = await off.changeStatus(guardOnDuty, report.id, to: ReportStatus.received);
    expect(sent, isNull);
  });

  test('báo cáo khẩn cấp: mức Khẩn cấp, chấp nhận không mô tả nếu có GPS', () async {
    final (report, _) = await service.create(student, draft(emergency: true));
    expect(report.severity, Severity.critical);
    expect(report.emergency, isTrue);
    expect(report.description, isNotEmpty);
  });

  test('dữ liệu sai: trả lỗi 422 theo từng trường', () async {
    final bad = ReportDraft(
      type: IncidentType.fight,
      severity: Severity.low,
      description: 'ngắn',
      occurredAt: clock.now,
    );
    await expectLater(
      service.create(student, bad),
      throwsA(isA<ApiException>()
          .having((e) => e.statusCode, 'status', 422)
          .having((e) => (e.details!['fields'] as Map).keys, 'fields', containsAll(['description', 'building']))),
    );
  });

  test('bảo vệ tiếp nhận: tự nhận việc, người báo nhận Zalo cập nhật trạng thái', () async {
    final (report, _) = await service.create(student, draft());
    gateway.sent.clear();
    final (updated, zalo) = await service.changeStatus(guardOnDuty, report.id, to: ReportStatus.received);
    expect(updated.status, ReportStatus.received);
    expect(updated.assigneeUid, guardOnDuty.uid);
    expect(zalo!.success, isTrue);
    final msg = gateway.sent.single;
    expect(msg.template, ZaloTemplateKey.statusUpdate);
    expect(msg.recipient, student.phone);
    expect(msg.data['status'], 'Đã tiếp nhận');
    final event = reports.events[report.id]!.last;
    expect(event.fromStatus, ReportStatus.submitted);
    expect(event.toStatus, ReportStatus.received);
  });

  test('người báo không đổi được trạng thái; bảo vệ khác không giành việc', () async {
    final (report, _) = await service.create(student, draft());
    await expectLater(
      service.changeStatus(student, report.id, to: ReportStatus.received),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 403)),
    );
    await service.changeStatus(guardOnDuty, report.id, to: ReportStatus.inProgress);
    await expectLater(
      service.changeStatus(guardOff, report.id, to: ReportStatus.resolved),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('Lê Văn Hùng'))),
    );
    // Quản trị vẫn đóng được.
    final (closed, _) = await service.changeStatus(admin, report.id, to: ReportStatus.resolved, note: 'Đã tìm thấy xe');
    expect(closed.closedAt, clock.now);
    expect(closed.lastNote, 'Đã tìm thấy xe');
  });

  test('từ chối bắt buộc lý do; chuyển sai luồng bị chặn', () async {
    final (report, _) = await service.create(student, draft());
    await expectLater(
      service.changeStatus(guardOnDuty, report.id, to: ReportStatus.rejected),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'invalid_transition')),
    );
    await expectLater(
      service.changeStatus(guardOnDuty, report.id, to: ReportStatus.resolved),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 409)),
    );
  });

  test('quản trị phân công: báo cáo chuyển Đã tiếp nhận, bảo vệ được giao nhận push', () async {
    final (report, _) = await service.create(student, draft());
    push.sent.clear();
    final (assigned, zalo) = await service.assign(admin, report.id, guardOff.uid);
    expect(assigned.assigneeUid, guardOff.uid);
    expect(assigned.status, ReportStatus.received);
    expect(zalo, isNotNull);
    expect(push.sent.any((p) => p.$1.contains('tok-g2')), isTrue);
  });

  test('bảo vệ không giao việc cho người khác; không giao cho người báo', () async {
    final (report, _) = await service.create(student, draft());
    await expectLater(service.assign(guardOnDuty, report.id, guardOff.uid), throwsA(isA<ApiException>()));
    await expectLater(service.assign(admin, report.id, student.uid), throwsA(isA<ApiException>()));
  });

  test('trao đổi: người báo ẩn danh vẫn ẩn tên; người khác không bình luận được', () async {
    final (report, _) = await service.create(student, draft(anonymous: true));
    await service.comment(student, report.id, 'Xe màu xanh, biển 29B1-123.45');
    final event = reports.events[report.id]!.last;
    expect(event.type, ReportEventType.comment);
    expect(event.actorName, 'Người báo (ẩn danh)');
    expect(event.actorUid, isNull);

    final stranger = users.seed(phone: '0966000111', name: 'Hoàng Gia Linh');
    await expectLater(service.comment(stranger, report.id, 'xin chào'), throwsA(isA<ApiException>()));
  });

  test('token push hết hiệu lực được dọn khỏi hồ sơ', () async {
    push.invalid.add('tok-g2');
    await service.create(student, draft());
    expect(users.byUid[guardOff.uid]!.fcmTokens, isEmpty);
  });

  test('đọc danh sách bảo vệ lỗi: báo cáo vẫn tạo thành công, vẫn gửi xác nhận và báo số trực trong .env', () async {
    final flaky = _FlakyUsers();
    final reporterUser = flaky.seed(phone: '0912345678', name: 'Trần Minh Khoa');
    final svc = ReportService(
      reports: reports,
      users: flaky,
      clock: clock.call,
      notifications: NotificationService(
        gateway: gateway,
        push: push,
        users: flaky,
        extraDutyPhones: [VietnamPhone.parse('0933444555')],
      ),
    );
    final (report, summary) = await svc.create(reporterUser, draft());
    expect(reports.reports[report.id], isNotNull);
    expect(summary.reporterConfirmation!.success, isTrue);
    expect(gateway.sent.where((m) => m.template == ZaloTemplateKey.guardAlert).map((m) => m.recipient.local),
        ['0933444555']);
  });

  test('bảo vệ gửi ẩn danh: lịch sử không lộ vai trò bảo vệ', () async {
    final (report, _) = await service.create(guardOff, draft(anonymous: true));
    final created = reports.events[report.id]!.single;
    expect(created.actorRole, UserRole.reporter);
    expect(created.actorUid, isNull);
  });

  test('đổi trạng thái không kèm ghi chú thì xoá ghi chú cũ', () async {
    final (report, _) = await service.create(student, draft());
    await service.changeStatus(admin, report.id, to: ReportStatus.rejected, note: 'Báo cáo trùng lặp');
    expect(reports.reports[report.id]!.lastNote, 'Báo cáo trùng lặp');
    await service.changeStatus(admin, report.id, to: ReportStatus.received);
    expect(reports.reports[report.id]!.lastNote, isNull);
  });
}
