import 'package:campus_core/campus_core.dart';

import 'report.dart';

/// Khoảng thời gian lọc.
enum TimeRange {
  today('Hôm nay'),
  week('7 ngày'),
  month('30 ngày'),
  quarter('90 ngày');

  const TimeRange(this.label);

  final String label;

  DateTime start(DateTime now) {
    final local = now.toLocal();
    return switch (this) {
      TimeRange.today => DateTime(local.year, local.month, local.day),
      TimeRange.week => DateTime(local.year, local.month, local.day).subtract(const Duration(days: 6)),
      TimeRange.month => DateTime(local.year, local.month, local.day).subtract(const Duration(days: 29)),
      TimeRange.quarter => DateTime(local.year, local.month, local.day).subtract(const Duration(days: 89)),
    };
  }
}

/// Bộ lọc màn bảo vệ/quản trị: trạng thái, mức độ, khu vực, thời gian.
class ReportFilter {
  const ReportFilter({
    this.statuses = const {},
    this.severities = const {},
    this.building,
    this.range = TimeRange.week,
    this.emergencyOnly = false,
  });

  /// Rỗng nghĩa là mọi trạng thái.
  final Set<ReportStatus> statuses;
  final Set<Severity> severities;
  final String? building;
  final TimeRange range;
  final bool emergencyOnly;

  int get activeCount =>
      (statuses.isEmpty ? 0 : 1) + (severities.isEmpty ? 0 : 1) + (building == null ? 0 : 1) + (emergencyOnly ? 1 : 0);

  ReportFilter copyWith({
    Set<ReportStatus>? statuses,
    Set<Severity>? severities,
    String? building,
    bool clearBuilding = false,
    TimeRange? range,
    bool? emergencyOnly,
  }) =>
      ReportFilter(
        statuses: statuses ?? this.statuses,
        severities: severities ?? this.severities,
        building: clearBuilding ? null : (building ?? this.building),
        range: range ?? this.range,
        emergencyOnly: emergencyOnly ?? this.emergencyOnly,
      );

  bool matches(Report r, {DateTime? now, bool applyRange = true}) {
    if (statuses.isNotEmpty && !statuses.contains(r.status)) return false;
    if (severities.isNotEmpty && !severities.contains(r.severity)) return false;
    if (building != null && r.building != building) return false;
    if (emergencyOnly && !r.emergency) return false;
    if (applyRange && r.createdAt.isBefore(range.start(now ?? DateTime.now()))) return false;
    return true;
  }

  List<Report> apply(List<Report> reports, {DateTime? now, bool applyRange = true}) =>
      reports.where((r) => matches(r, now: now, applyRange: applyRange)).toList();
}

/// Sắp xếp hàng đợi: khẩn cấp và mức độ cao lên trước, rồi mới nhất trước.
List<Report> sortForTriage(Iterable<Report> reports) {
  final list = reports.toList()
    ..sort((a, b) {
      if (a.emergency != b.emergency) return a.emergency ? -1 : 1;
      final bySeverity = b.severity.rank.compareTo(a.severity.rank);
      if (bySeverity != 0) return bySeverity;
      return b.createdAt.compareTo(a.createdAt);
    });
  return list;
}

/// Thống kê cho màn quản trị, tính từ danh sách báo cáo thật.
class ReportStats {
  const ReportStats({
    required this.total,
    required this.byStatus,
    required this.byType,
    required this.bySeverity,
    required this.byBuilding,
    required this.emergencyCount,
    required this.averageTimeToClose,
    required this.unassignedOpen,
    required this.openEmergencyCount,
  });

  factory ReportStats.compute(List<Report> reports) {
    final byStatus = {for (final s in ReportStatus.values) s: 0};
    final byType = {for (final t in IncidentType.values) t: 0};
    final bySeverity = {for (final s in Severity.values) s: 0};
    final byBuilding = <String, int>{};
    var emergency = 0, unassignedOpen = 0, openEmergency = 0;
    var closedCount = 0;
    var closedTotal = Duration.zero;
    for (final r in reports) {
      byStatus[r.status] = byStatus[r.status]! + 1;
      byType[r.type] = byType[r.type]! + 1;
      bySeverity[r.severity] = bySeverity[r.severity]! + 1;
      final b = r.building ?? 'Chưa rõ khu vực';
      byBuilding[b] = (byBuilding[b] ?? 0) + 1;
      if (r.emergency) emergency++;
      if (r.emergency && r.status.isOpen) openEmergency++;
      if (r.status.isOpen && r.assigneeUid == null) unassignedOpen++;
      final t = r.timeToClose;
      if (r.status == ReportStatus.resolved && t != null && !t.isNegative) {
        closedCount++;
        closedTotal += t;
      }
    }
    final sortedBuildings = byBuilding.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return ReportStats(
      total: reports.length,
      byStatus: byStatus,
      byType: byType,
      bySeverity: bySeverity,
      byBuilding: Map.fromEntries(sortedBuildings),
      emergencyCount: emergency,
      averageTimeToClose: closedCount == 0 ? null : Duration(seconds: closedTotal.inSeconds ~/ closedCount),
      unassignedOpen: unassignedOpen,
      openEmergencyCount: openEmergency,
    );
  }

  final int total;
  final Map<ReportStatus, int> byStatus;
  final Map<IncidentType, int> byType;
  final Map<Severity, int> bySeverity;

  /// Đã sắp xếp giảm dần.
  final Map<String, int> byBuilding;
  final int emergencyCount;

  /// Trung bình thời gian từ lúc gửi đến khi "Đã giải quyết".
  final Duration? averageTimeToClose;
  final int unassignedOpen;

  /// Báo cáo khẩn cấp chưa đóng: cần chú ý ngay.
  final int openEmergencyCount;

  int get openCount =>
      byStatus[ReportStatus.submitted]! + byStatus[ReportStatus.received]! + byStatus[ReportStatus.inProgress]!;

  int get resolvedCount => byStatus[ReportStatus.resolved]!;
}
