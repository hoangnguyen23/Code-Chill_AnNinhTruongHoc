import 'package:campus_core/campus_core.dart';

import 'app_user.dart';

/// Thông tin người dùng nhập ở màn đăng ký; giữ lại để gửi lại mã.
class RegistrationDraft {
  const RegistrationDraft({
    required this.email,
    required this.username,
    required this.password,
    required this.displayName,
    this.memberType = MemberType.student,
  });

  final String email;
  final String username;
  final String password;
  final String displayName;

  /// Mặc định Sinh viên; quản trị đổi sang Giảng viên trong màn Tài khoản.
  final MemberType memberType;
}

/// Kết quả gửi mã xác nhận đăng ký.
class OtpChallengeInfo {
  const OtpChallengeInfo({
    required this.email,
    required this.emailMasked,
    required this.expiresIn,
    required this.resendAfter,
    required this.mode,
    this.draft,
  });

  final String email;
  final String emailMasked;
  final Duration expiresIn;
  final Duration resendAfter;

  /// Kênh gửi mã của backend, hiện là `email`.
  final String mode;

  /// Thông tin đăng ký để gửi lại mã; `null` với mã đặt lại mật khẩu.
  final RegistrationDraft? draft;
}

abstract interface class AuthRepository {
  /// Đăng nhập bằng tên đăng nhập (hoặc email) và mật khẩu. Ném `ApiError` tiếng Việt nếu sai.
  Future<AppUser> login(String username, String password);

  /// Kiểm tra thông tin đăng ký và gửi mã OTP tới email. Chưa tạo tài khoản.
  Future<OtpChallengeInfo> requestRegistration(RegistrationDraft draft);

  /// Nhập đúng mã thì tài khoản được tạo và đăng nhập Firebase luôn.
  Future<AppUser> verifyRegistration(String email, String code);

  /// Gửi mã đặt lại mật khẩu tới email của tài khoản. Báo lỗi nếu email chưa đăng ký.
  Future<OtpChallengeInfo> requestPasswordReset(String email);

  /// Nhập đúng mã thì đặt mật khẩu mới và đăng nhập luôn.
  Future<AppUser> resetPassword(String email, String code, String newPassword);

  /// Đổi mật khẩu khi đang đăng nhập (phải nhập đúng mật khẩu hiện tại).
  Future<void> changePassword(String currentPassword, String newPassword);

  /// Cập nhật hồ sơ của chính mình. [phone] là chuỗi rỗng để xoá số điện thoại.
  Future<AppUser> updateProfile({String? displayName, String? phone, MemberType? memberType, bool? onDuty});

  Future<void> signOut();
}
