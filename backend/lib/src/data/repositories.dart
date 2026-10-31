import 'package:campus_core/campus_core.dart';

import 'models.dart';

abstract interface class UserRepository {
  Future<UserRecord?> byId(String uid);

  Future<UserRecord?> byEmail(EmailAddress email);

  /// Tìm theo email; nếu chưa có thì tạo mới với [role]. Trả về (người dùng, mới tạo?).
  /// Đảm bảo mỗi email chỉ có một tài khoản (dùng `email_index/{email}`).
  Future<(UserRecord, bool)> getOrCreate(EmailAddress email, {required UserRole role});

  /// Tạo trước tài khoản (quản trị). Ném [StateError] nếu email đã tồn tại.
  Future<UserRecord> create({
    required EmailAddress email,
    required String displayName,
    required UserRole role,
    required MemberType memberType,
    VietnamPhone? phone,
    bool onDuty = false,
  });

  Future<UserRecord> update(
    String uid, {
    String? displayName,
    VietnamPhone? phone,
    bool clearPhone = false,
    String? username,
    MemberType? memberType,
    UserRole? role,
    bool? active,
    bool? onDuty,
    DateTime? lastLoginAt,
  });

  Future<void> addFcmToken(String uid, String token);

  Future<void> removeFcmToken(String uid, String token);

  /// Bảo vệ và quản trị đang hoạt động.
  Future<List<UserRecord>> listStaff();

  /// Mọi tài khoản đang hoạt động (gửi cảnh báo toàn trường).
  Future<List<UserRecord>> listActive();

  /// Xoá hồ sơ, chỉ mục email và danh sách "báo cáo của tôi". Báo cáo đã gửi vẫn giữ để tra cứu.
  Future<void> delete(String uid);
}

/// Tên đăng nhập và mật khẩu đã băm (`credentials/{uid}`, client không đọc được).
class StoredCredential {
  const StoredCredential({
    required this.uid,
    required this.username,
    required this.passwordHash,
    this.failedAttempts = 0,
    this.lockedUntil,
  });

  final String uid;
  final String username;
  final String passwordHash;
  final int failedAttempts;
  final DateTime? lockedUntil;
}

abstract interface class CredentialRepository {
  Future<StoredCredential?> byUid(String uid);

  Future<StoredCredential?> byUsername(String username);

  Future<bool> usernameTaken(String username);

  /// Gắn tên đăng nhập và mật khẩu cho [uid]. Ném [StateError] `username_taken` nếu tên đã có
  /// người dùng, `credential_exists` nếu tài khoản đã có mật khẩu.
  Future<void> create(String uid, {required String username, required String passwordHash});

  Future<void> recordFailure(String uid, {required int attempts, DateTime? lockedUntil});

  Future<void> resetFailures(String uid);

  /// Đặt mật khẩu mới (đã băm), xoá đếm sai và khoá đăng nhập.
  Future<void> updatePassword(String uid, String passwordHash);

  /// Xoá mật khẩu và giải phóng tên đăng nhập (khi xoá tài khoản).
  Future<void> delete(String uid);
}

abstract interface class ReportRepository {
  /// Sinh ID cho báo cáo mới.
  String newId();

  /// Ghi báo cáo, thông tin người báo, chỉ mục "báo cáo của tôi" và sự kiện "created" trong
  /// một transaction.
  Future<void> create(ReportRecord report, ReporterPrivate reporter, ReportEvent createdEvent);

  Future<ReportRecord?> byId(String id);

  Future<ReporterPrivate?> reporterOf(String id);

  /// Đọc báo cáo và người báo trong transaction, gọi [apply] để tính bản mới (có thể ném lỗi
  /// để huỷ), rồi ghi báo cáo, chỉ mục của người báo và [event] (nếu có).
  Future<(ReportRecord, ReporterPrivate)> mutate(
    String id,
    (ReportRecord, ReportEvent?) Function(ReportRecord current, ReporterPrivate reporter) apply,
  );

  Future<void> addEvent(String reportId, ReportEvent event);
}

abstract interface class OtpStore {
  Future<OtpChallenge?> read(String key);

  /// Đọc và ghi nguyên tử. [mutate] có thể ném lỗi để huỷ thay đổi.
  Future<OtpChallenge> update(String key, OtpChallenge Function(OtpChallenge? current) mutate);
}

abstract interface class ConfigRepository {
  Future<CampusConfig?> read();

  Future<CampusConfig> write(CampusConfig config);
}
