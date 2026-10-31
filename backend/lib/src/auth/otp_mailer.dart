import 'dart:io';

import 'package:campus_core/campus_core.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

/// Gửi email thất bại. [message] là tiếng Việt, hiển thị cho người dùng.
class OtpMailException implements Exception {
  const OtpMailException(this.message, {this.detail});

  final String message;

  /// Lỗi gốc từ máy chủ mail, chỉ ghi log.
  final String? detail;

  @override
  String toString() => 'OtpMailException: $message${detail == null ? '' : ' ($detail)'}';
}

/// Kênh gửi mã OTP tới email. Bản cài đặt: [SmtpOtpMailer].
abstract interface class OtpMailer {
  /// Hiển thị trên màn đăng nhập, ví dụ `email`.
  String get mode;

  /// Gửi mã. [action] là việc cần xác nhận, ví dụ "đăng ký tài khoản", "đặt lại mật khẩu".
  /// Ném [OtpMailException] nếu thất bại.
  Future<void> sendOtp(EmailAddress to, String code, {required Duration ttl, String action = 'đăng ký tài khoản'});
}

/// Gửi OTP qua SMTP (mặc định Gmail với Mật khẩu ứng dụng).
class SmtpOtpMailer implements OtpMailer {
  SmtpOtpMailer({
    required String host,
    required int port,
    required String username,
    required String password,
    required this.fromName,
    required this.appName,
    this.timeout = const Duration(seconds: 20),
  })  : _username = username,
        _server = SmtpServer(
          host,
          port: port,
          // Cổng 465 dùng SSL ngay từ đầu; cổng 587 dùng STARTTLS (thư viện bắt buộc mã hoá).
          ssl: port == 465,
          username: username,
          password: password,
        );

  final SmtpServer _server;
  final String _username;
  final String fromName;
  final String appName;
  final Duration timeout;

  @override
  String get mode => 'email';

  @override
  Future<void> sendOtp(EmailAddress to, String code, {required Duration ttl, String action = 'đăng ký tài khoản'}) async {
    final minutes = ttl.inMinutes;
    final message = Message()
      ..from = Address(_username, fromName)
      ..recipients.add(to.value)
      ..subject = 'Mã $action $appName: $code'
      ..text = 'Mã xác nhận $action ứng dụng $appName của bạn là $code.\n'
          'Mã có hiệu lực trong $minutes phút. Tuyệt đối không chia sẻ mã này cho người khác.\n\n'
          'Nếu bạn không yêu cầu mã, hãy bỏ qua email này.'
      ..html = '<p>Mã xác nhận ${_escape(action)} ứng dụng <b>${_escape(appName)}</b> của bạn là:</p>'
          '<p style="font-size:28px;font-weight:bold;letter-spacing:6px">$code</p>'
          '<p>Mã có hiệu lực trong $minutes phút. Tuyệt đối không chia sẻ mã này cho người khác.</p>'
          '<p style="color:#666">Nếu bạn không yêu cầu mã, hãy bỏ qua email này.</p>';
    try {
      await send(message, _server, timeout: timeout);
    } on MailerException catch (e) {
      final detail = e.problems.map((p) => '${p.code}: ${p.msg}').join('; ');
      stderr.writeln('[mail] Gửi OTP tới ${to.masked} thất bại: ${e.message} $detail');
      final authFailed = e is SmtpClientAuthenticationException || e.problems.any((p) => p.code == '535');
      throw OtpMailException(
        authFailed
            ? 'Máy chủ không đăng nhập được tài khoản gửi mail. Quản trị cần kiểm tra SMTP_USERNAME/SMTP_PASSWORD.'
            : 'Không gửi được email. Kiểm tra lại địa chỉ email rồi thử lại.',
        detail: '${e.message} $detail',
      );
    } on Object catch (e) {
      // SocketException, TimeoutException...
      stderr.writeln('[mail] Gửi OTP tới ${to.masked} thất bại: $e');
      throw OtpMailException('Không kết nối được máy chủ gửi mail. Thử lại sau ít phút.', detail: '$e');
    }
  }

  static String _escape(String s) =>
      s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
}
