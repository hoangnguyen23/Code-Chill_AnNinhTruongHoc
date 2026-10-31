import 'package:campus_core/campus_core.dart';

/// Đọc thời gian từ Firestore mà không phụ thuộc package Firebase ở tầng domain:
/// `Timestamp` có phương thức `toDate()`.
DateTime _date(Object? v, [DateTime? fallback]) {
  final zero = fallback ?? DateTime.fromMillisecondsSinceEpoch(0);
  if (v == null) return zero;
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v) ?? zero;
  try {
    final converted = (v as dynamic).toDate();
    if (converted is DateTime) return converted;
  } on NoSuchMethodError {
    // Không phải Timestamp.
  }
  return zero;
}

DateTime? _dateOrNull(Object? v) => v == null ? null : _date(v);

String? _str(Object? v) => v is String && v.isNotEmpty ? v : null;

double? _num(Object? v) => v is num ? v.toDouble() : null;

/// Báo cáo sự cố (`reports/{id}`), dạng bảo vệ/quản trị/người báo đọc từ Firestore.
class Report {
  const Report({
    required this.id,
    required this.code,
    required this.type,
    required this.severity,
    required this.status,
    required this.description,
    required this.occurredAt,
    required this.createdAt,
    required this.updatedAt,
    required this.emergency,
    required this.anonymous,
    required this.locationText,
    this.building,
    this.floor,
    this.room,
    this.latitude,
    this.longitude,
    this.accuracyMeters,
    this.reporterUid,
    this.reporterName,
    this.reporterPhone,
    this.reporterMemberType,
    this.imagePaths = const [],
    this.assigneeUid,
    this.assigneeName,
    this.lastNote,
    this.closedAt,
  });

  factory Report.fromMap(String id, Map<String, dynamic> d) => Report(
        id: id,
        code: (d['code'] as String?) ?? id,
        type: IncidentType.fromWire(d['type'] as String?),
        severity: Severity.fromWire(d['severity'] as String?),
        status: ReportStatus.fromWire(d['status'] as String?),
        description: (d['description'] as String?) ?? '',
        occurredAt: _date(d['occurredAt']),
        createdAt: _date(d['createdAt']),
        updatedAt: _date(d['updatedAt'], _date(d['createdAt'])),
        emergency: d['emergency'] == true,
        anonymous: d['anonymous'] == true,
        locationText: (d['locationText'] as String?) ??
            formatLocation(building: d['building'] as String?, floor: d['floor'] as String?, room: d['room'] as String?),
        building: _str(d['building']),
        floor: _str(d['floor']),
        room: _str(d['room']),
        latitude: _num(d['latitude']),
        longitude: _num(d['longitude']),
        accuracyMeters: _num(d['accuracyMeters']),
        reporterUid: _str(d['reporterUid']),
        reporterName: _str(d['reporterName']),
        reporterPhone: _str(d['reporterPhone']),
        reporterMemberType: MemberType.tryFromWire(d['reporterMemberType'] as String?),
        imagePaths: (d['imagePaths'] as List?)?.whereType<String>().toList() ?? const [],
        assigneeUid: _str(d['assigneeUid']),
        assigneeName: _str(d['assigneeName']),
        lastNote: _str(d['lastNote']),
        closedAt: _dateOrNull(d['closedAt']),
      );

  final String id;
  final String code;
  final IncidentType type;
  final Severity severity;
  final ReportStatus status;
  final String description;
  final DateTime occurredAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool emergency;
  final bool anonymous;
  final String locationText;
  final String? building;
  final String? floor;
  final String? room;
  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;
  final String? reporterUid;
  final String? reporterName;
  final String? reporterPhone;
  final MemberType? reporterMemberType;
  final List<String> imagePaths;
  final String? assigneeUid;
  final String? assigneeName;
  final String? lastNote;
  final DateTime? closedAt;

  bool get hasCoordinates => latitude != null && longitude != null;

  /// Thời gian từ lúc gửi đến lúc đóng (đã giải quyết / từ chối).
  Duration? get timeToClose => closedAt?.difference(createdAt);
}

/// Mục trong "Báo cáo của tôi" (`users/{uid}/reports/{id}`).
class ReportSummary {
  const ReportSummary({
    required this.id,
    required this.code,
    required this.type,
    required this.severity,
    required this.status,
    required this.emergency,
    required this.anonymous,
    required this.locationText,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ReportSummary.fromMap(String id, Map<String, dynamic> d) => ReportSummary(
        id: id,
        code: (d['code'] as String?) ?? id,
        type: IncidentType.fromWire(d['type'] as String?),
        severity: Severity.fromWire(d['severity'] as String?),
        status: ReportStatus.fromWire(d['status'] as String?),
        emergency: d['emergency'] == true,
        anonymous: d['anonymous'] == true,
        locationText: (d['locationText'] as String?) ?? '',
        createdAt: _date(d['createdAt']),
        updatedAt: _date(d['updatedAt'], _date(d['createdAt'])),
      );

  factory ReportSummary.fromReport(Report r) => ReportSummary(
        id: r.id,
        code: r.code,
        type: r.type,
        severity: r.severity,
        status: r.status,
        emergency: r.emergency,
        anonymous: r.anonymous,
        locationText: r.locationText,
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
      );

  final String id;
  final String code;
  final IncidentType type;
  final Severity severity;
  final ReportStatus status;
  final bool emergency;
  final bool anonymous;
  final String locationText;
  final DateTime createdAt;
  final DateTime updatedAt;
}

/// Một dòng lịch sử xử lý / trao đổi (`reports/{id}/events/{eventId}`).
class ReportEventItem {
  const ReportEventItem({
    required this.id,
    required this.type,
    required this.createdAt,
    required this.actorName,
    required this.actorRole,
    this.actorUid,
    this.fromStatus,
    this.toStatus,
    this.note,
  });

  factory ReportEventItem.fromMap(String id, Map<String, dynamic> d) => ReportEventItem(
        id: id,
        type: ReportEventType.fromWire(d['type'] as String?),
        createdAt: _date(d['createdAt']),
        actorName: (d['actorName'] as String?) ?? '',
        actorRole: UserRole.fromWire(d['actorRole'] as String?),
        actorUid: _str(d['actorUid']),
        fromStatus: ReportStatus.tryFromWire(d['fromStatus'] as String?),
        toStatus: ReportStatus.tryFromWire(d['toStatus'] as String?),
        note: _str(d['note']),
      );

  final String id;
  final ReportEventType type;
  final DateTime createdAt;
  final String actorName;
  final UserRole actorRole;
  final String? actorUid;
  final ReportStatus? fromStatus;
  final ReportStatus? toStatus;
  final String? note;
}

/// Thông tin thật của người báo (chỉ quản trị và chính người báo đọc được).
class ReporterContact {
  const ReporterContact({required this.uid, required this.phone, required this.displayName});

  factory ReporterContact.fromMap(Map<String, dynamic> d) => ReporterContact(
        uid: (d['uid'] as String?) ?? '',
        phone: (d['phoneLocal'] as String?) ?? VietnamPhone.tryParse(d['phone'] as String?)?.local ?? '',
        displayName: (d['displayName'] as String?) ?? '',
      );

  final String uid;
  final String phone;
  final String displayName;
}

/// Kết quả gửi Zalo mà backend trả về, rút gọn cho UI.
class ZaloDelivery {
  const ZaloDelivery({required this.success, this.message, this.errorCode});

  factory ZaloDelivery.fromJson(Map<String, Object?> j) => ZaloDelivery(
        success: j['success'] == true,
        message: j['message'] as String?,
        errorCode: j['errorCode'] as int?,
      );

  final bool success;
  final String? message;
  final int? errorCode;
}

/// Kết quả gửi báo cáo.
class SubmitReportResult {
  const SubmitReportResult({
    required this.id,
    required this.code,
    required this.reporterConfirmation,
    required this.guardsTotal,
    required this.guardsAlerted,
    required this.guardFailureMessages,
    required this.pending,
    this.pushDelivered = 0,
  });

  factory SubmitReportResult.fromJson(Map<String, Object?> j) {
    final report = (j['report'] as Map?)?.cast<String, Object?>() ?? const {};
    final n = (j['notifications'] as Map?)?.cast<String, Object?>() ?? const {};
    final confirm = n['reporterConfirmation'];
    return SubmitReportResult(
      id: (report['id'] as String?) ?? '',
      code: (report['code'] as String?) ?? '',
      reporterConfirmation: confirm is Map ? ZaloDelivery.fromJson(confirm.cast<String, Object?>()) : null,
      guardsTotal: (n['guardsTotal'] as int?) ?? 0,
      guardsAlerted: (n['guardsAlerted'] as int?) ?? 0,
      guardFailureMessages: ((n['guardFailures'] as List?) ?? const [])
          .whereType<Map>()
          .map((f) => '${f['recipient']}: ${f['message']}')
          .toList(),
      pending: n['pending'] == true,
      pushDelivered: (n['pushDelivered'] as int?) ?? 0,
    );
  }

  final String id;
  final String code;
  final ZaloDelivery? reporterConfirmation;
  final int guardsTotal;
  final int guardsAlerted;
  final List<String> guardFailureMessages;

  /// Backend chưa gửi xong tin Zalo trong thời gian chờ (vẫn đang gửi ở nền).
  final bool pending;

  /// Số thiết bị (bảo vệ, quản trị) đã nhận thông báo đẩy.
  final int pushDelivered;
}
