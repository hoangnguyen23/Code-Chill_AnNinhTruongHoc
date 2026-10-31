import 'package:campus_core/campus_core.dart';

/// Hồ sơ người dùng (`users/{uid}`).
class UserRecord {
  const UserRecord({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.memberType,
    required this.active,
    required this.onDuty,
    this.phone,
    this.username,
    this.fcmTokens = const [],
    this.createdAt,
    this.updatedAt,
    this.lastLoginAt,
  });

  final String uid;

  /// Email đăng nhập (nhận OTP), mỗi email một tài khoản.
  final EmailAddress email;

  /// Số điện thoại liên hệ (tuỳ chọn), dùng để nhận tin Zalo khi backend bật Zalo.
  final VietnamPhone? phone;

  /// Tên đăng nhập (đã chuẩn hoá). `null` với tài khoản quản trị tạo trước mà chưa đăng ký.
  final String? username;
  final String displayName;
  final UserRole role;
  final MemberType memberType;
  final bool active;

  /// Bảo vệ đang trực: nhận cảnh báo Zalo khi có sự cố mới.
  final bool onDuty;
  final List<String> fcmTokens;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastLoginAt;

  Actor get actor => Actor(uid: uid, role: role, active: active);

  bool get profileComplete => displayName.trim().isNotEmpty;

  /// Tên dùng trong tin nhắn khi người dùng chưa nhập tên.
  String get greetingName => profileComplete ? displayName : 'bạn';

  UserRecord copyWith({
    String? displayName,
    VietnamPhone? phone,
    bool clearPhone = false,
    String? username,
    UserRole? role,
    MemberType? memberType,
    bool? active,
    bool? onDuty,
    List<String>? fcmTokens,
    DateTime? updatedAt,
    DateTime? lastLoginAt,
  }) =>
      UserRecord(
        uid: uid,
        email: email,
        phone: clearPhone ? null : (phone ?? this.phone),
        username: username ?? this.username,
        displayName: displayName ?? this.displayName,
        role: role ?? this.role,
        memberType: memberType ?? this.memberType,
        active: active ?? this.active,
        onDuty: onDuty ?? this.onDuty,
        fcmTokens: fcmTokens ?? this.fcmTokens,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      );

  Map<String, Object?> toApiJson() => {
        'uid': uid,
        'email': email.value,
        'username': username,
        'phone': phone?.local,
        'displayName': displayName,
        'role': role.wire,
        'memberType': memberType.wire,
        'active': active,
        'onDuty': onDuty,
        'profileComplete': profileComplete,
      };
}

/// Báo cáo sự cố (`reports/{id}`). Với báo cáo ẩn danh, các trường người báo để trống;
/// thông tin thật nằm ở `reports/{id}/private/reporter`.
class ReportRecord {
  const ReportRecord({
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

  String get locationText => formatLocation(building: building, floor: floor, room: room);

  ReportRecord copyWith({
    ReportStatus? status,
    DateTime? updatedAt,
    String? assigneeUid,
    String? assigneeName,
    String? lastNote,
    DateTime? closedAt,
    bool clearClosedAt = false,
    bool clearLastNote = false,
  }) =>
      ReportRecord(
        id: id,
        code: code,
        type: type,
        severity: severity,
        status: status ?? this.status,
        description: description,
        occurredAt: occurredAt,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        emergency: emergency,
        anonymous: anonymous,
        building: building,
        floor: floor,
        room: room,
        latitude: latitude,
        longitude: longitude,
        accuracyMeters: accuracyMeters,
        reporterUid: reporterUid,
        reporterName: reporterName,
        reporterPhone: reporterPhone,
        reporterMemberType: reporterMemberType,
        imagePaths: imagePaths,
        assigneeUid: assigneeUid ?? this.assigneeUid,
        assigneeName: assigneeName ?? this.assigneeName,
        lastNote: clearLastNote ? null : (lastNote ?? this.lastNote),
        closedAt: clearClosedAt ? null : (closedAt ?? this.closedAt),
      );

  Map<String, Object?> toApiJson() => {
        'id': id,
        'code': code,
        'status': status.wire,
        'severity': severity.wire,
        'type': type.wire,
        'emergency': emergency,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };
}

/// Thông tin thật của người báo (`reports/{id}/private/reporter`), chỉ quản trị và chính
/// người báo đọc được.
class ReporterPrivate {
  const ReporterPrivate({required this.uid, required this.displayName, this.email, this.phone});

  final String uid;
  final String displayName;
  final EmailAddress? email;

  /// Không có thì không gửi được tin Zalo cho người báo (vẫn có push FCM).
  final VietnamPhone? phone;
}

/// Một dòng lịch sử (`reports/{id}/events/{eventId}`).
class ReportEvent {
  const ReportEvent({
    required this.type,
    required this.createdAt,
    required this.actorName,
    required this.actorRole,
    this.actorUid,
    this.fromStatus,
    this.toStatus,
    this.note,
  });

  final ReportEventType type;
  final DateTime createdAt;
  final String actorName;
  final UserRole actorRole;

  /// Bỏ trống khi người báo ẩn danh.
  final String? actorUid;
  final ReportStatus? fromStatus;
  final ReportStatus? toStatus;
  final String? note;
}

/// Cấu hình trường (`config/app`).
class CampusConfig {
  const CampusConfig({
    required this.campusName,
    required this.hotline,
    required this.buildings,
    this.updatedAt,
  });

  final String campusName;
  final String? hotline;
  final List<String> buildings;
  final DateTime? updatedAt;

  Map<String, Object?> toJson() => {
        'campusName': campusName,
        'hotline': hotline,
        'buildings': buildings,
        'updatedAt': updatedAt?.toUtc().toIso8601String(),
      };
}

/// Phiên OTP của một email (`otp_challenges/{khoá băm}`), client không truy cập được.
class OtpChallenge {
  const OtpChallenge({
    this.codeHash,
    this.salt,
    this.expiresAt,
    this.attempts = 0,
    this.sendTimes = const [],
    this.pending = const {},
  });

  final String? codeHash;
  final String? salt;
  final DateTime? expiresAt;
  final int attempts;

  /// Thời điểm các lần gửi trong 24 giờ gần nhất (để giới hạn tần suất).
  final List<DateTime> sendTimes;

  /// Thông tin đăng ký đang chờ xác nhận (tên đăng nhập, họ tên, mật khẩu đã băm).
  final Map<String, String> pending;

  bool get hasActiveCode => codeHash != null && salt != null && expiresAt != null;

  DateTime? get lastSentAt => sendTimes.isEmpty ? null : sendTimes.reduce((a, b) => a.isAfter(b) ? a : b);

  OtpChallenge copyWith({
    String? codeHash,
    String? salt,
    DateTime? expiresAt,
    int? attempts,
    List<DateTime>? sendTimes,
    Map<String, String>? pending,
    bool clearCode = false,
  }) =>
      OtpChallenge(
        codeHash: clearCode ? null : (codeHash ?? this.codeHash),
        salt: clearCode ? null : (salt ?? this.salt),
        expiresAt: clearCode ? null : (expiresAt ?? this.expiresAt),
        attempts: attempts ?? this.attempts,
        sendTimes: sendTimes ?? this.sendTimes,
        pending: clearCode ? const {} : (pending ?? this.pending),
      );
}
