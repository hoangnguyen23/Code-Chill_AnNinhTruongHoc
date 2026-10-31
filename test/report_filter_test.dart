import 'package:campus_core/campus_core.dart';
import 'package:campus_safety/features/reports/domain/report.dart';
import 'package:campus_safety/features/reports/domain/report_filter.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 10, 19, 15);

Report report(
  String id, {
  ReportStatus status = ReportStatus.submitted,
  Severity severity = Severity.medium,
  IncidentType type = IncidentType.theft,
  String? building = 'Toà A1',
  bool emergency = false,
  Duration age = const Duration(hours: 1),
  Duration? closedAfter,
  String? assignee,
}) {
  final created = _now.subtract(age);
  return Report(
    id: id,
    code: 'SC-261019-$id',
    type: type,
    severity: severity,
    status: status,
    description: 'Mô tả sự cố $id',
    occurredAt: created,
    createdAt: created,
    updatedAt: created,
    emergency: emergency,
    anonymous: false,
    locationText: building ?? 'Chưa rõ vị trí',
    building: building,
    assigneeUid: assignee,
    closedAt: closedAfter == null ? null : created.add(closedAfter),
  );
}

void main() {
  group('ReportFilter', () {
    final items = [
      report('A001', status: ReportStatus.submitted, severity: Severity.high),
      report('A002', status: ReportStatus.resolved, building: 'Thư viện'),
      report('A003', status: ReportStatus.inProgress, emergency: true, severity: Severity.critical),
      report('A004', age: const Duration(days: 10)),
    ];

    test('mặc định 7 ngày, mọi trạng thái', () {
      expect(const ReportFilter().apply(items, now: _now).map((r) => r.id), ['A001', 'A002', 'A003']);
    });

    test('lọc theo trạng thái, mức độ, khu vực, khẩn cấp', () {
      expect(
        const ReportFilter(statuses: {ReportStatus.resolved}).apply(items, now: _now).single.id,
        'A002',
      );
      expect(
        const ReportFilter(severities: {Severity.high, Severity.critical}).apply(items, now: _now).map((r) => r.id),
        ['A001', 'A003'],
      );
      expect(const ReportFilter(building: 'Thư viện').apply(items, now: _now).single.id, 'A002');
      expect(const ReportFilter(emergencyOnly: true).apply(items, now: _now).single.id, 'A003');
    });

    test('khoảng 30 ngày gồm cả báo cáo 10 ngày trước', () {
      expect(const ReportFilter(range: TimeRange.month).apply(items, now: _now), hasLength(4));
    });

    test('bỏ qua khoảng thời gian cho hàng đợi "Đang mở"', () {
      expect(const ReportFilter().apply(items, now: _now, applyRange: false), hasLength(4));
    });

    test('đếm số điều kiện đang lọc', () {
      expect(const ReportFilter().activeCount, 0);
      expect(
        const ReportFilter(statuses: {ReportStatus.received}, building: 'Toà C', emergencyOnly: true).activeCount,
        3,
      );
      expect(const ReportFilter(building: 'Toà C').copyWith(clearBuilding: true).building, isNull);
    });
  });

  test('sortForTriage: khẩn cấp, rồi mức độ, rồi mới nhất', () {
    final sorted = sortForTriage([
      report('L1', severity: Severity.low, age: const Duration(minutes: 1)),
      report('H1', severity: Severity.high, age: const Duration(hours: 3)),
      report('E1', severity: Severity.critical, emergency: true, age: const Duration(hours: 5)),
      report('H2', severity: Severity.high, age: const Duration(hours: 1)),
    ]);
    expect(sorted.map((r) => r.id), ['E1', 'H2', 'H1', 'L1']);
  });

  test('ReportStats từ dữ liệu thật', () {
    final stats = ReportStats.compute([
      report('S1', status: ReportStatus.resolved, closedAfter: const Duration(hours: 2)),
      report('S2', status: ReportStatus.resolved, closedAfter: const Duration(hours: 4), building: 'Bãi xe'),
      report('S3', status: ReportStatus.submitted, emergency: true, type: IncidentType.fight),
      report('S4', status: ReportStatus.inProgress, assignee: 'g1', building: 'Bãi xe'),
      report('S5', status: ReportStatus.rejected, building: null),
    ]);
    expect(stats.total, 5);
    expect(stats.openCount, 2);
    expect(stats.resolvedCount, 2);
    expect(stats.emergencyCount, 1);
    expect(stats.openEmergencyCount, 1, reason: 'S3 khẩn cấp và còn mở');
    expect(stats.unassignedOpen, 1);
    expect(stats.averageTimeToClose, const Duration(hours: 3));
    expect(stats.byType[IncidentType.fight], 1);
    expect(stats.byBuilding.keys.first, anyOf('Toà A1', 'Bãi xe'));
    expect(stats.byBuilding['Chưa rõ khu vực'], 1);
  });

  test('SubmitReportResult đọc phản hồi backend', () {
    final r = SubmitReportResult.fromJson({
      'report': {'id': 'r1', 'code': 'SC-261019-K7Q4'},
      'notifications': {
        'reporterConfirmation': {'success': false, 'message': 'Số này chưa có tài khoản Zalo', 'errorCode': -118},
        'guardsTotal': 3,
        'guardsAlerted': 2,
        'guardFailures': [
          {'recipient': '84933***555', 'message': 'Template chưa được Zalo duyệt'},
        ],
        'pending': false,
      },
    });
    expect(r.code, 'SC-261019-K7Q4');
    expect(r.reporterConfirmation!.success, isFalse);
    expect(r.reporterConfirmation!.errorCode, -118);
    expect(r.guardsAlerted, 2);
    expect(r.guardFailureMessages.single, contains('84933***555'));
  });
}
