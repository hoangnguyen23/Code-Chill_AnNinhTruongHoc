/// Quy tắc tên đăng nhập và mật khẩu, dùng chung để app báo lỗi giống hệt backend.
library;

abstract final class UsernamePolicy {
  static const minLength = 3;
  static const maxLength = 30;

  static final _pattern = RegExp(r'^[a-z][a-z0-9._]*$');

  /// Chuẩn hoá: bỏ khoảng trắng hai đầu, chữ thường.
  static String normalize(String input) => input.trim().toLowerCase();

  /// Lỗi tiếng Việt, hoặc `null` nếu hợp lệ.
  static String? validate(String? input) {
    final v = normalize(input ?? '');
    if (v.isEmpty) return 'Nhập tên đăng nhập.';
    if (v.length < minLength || v.length > maxLength) {
      return 'Tên đăng nhập dài $minLength đến $maxLength ký tự.';
    }
    if (!_pattern.hasMatch(v)) {
      return 'Tên đăng nhập bắt đầu bằng chữ cái, chỉ gồm chữ không dấu, số, dấu chấm hoặc gạch dưới.';
    }
    if (v.contains('..') || v.endsWith('.')) return 'Dấu chấm không được đứng liền nhau hoặc ở cuối.';
    return null;
  }
}

abstract final class PasswordPolicy {
  static const minLength = 8;
  static const maxLength = 64;

  /// Lỗi tiếng Việt, hoặc `null` nếu hợp lệ. Mật khẩu không bị chuẩn hoá (giữ nguyên khoảng trắng).
  static String? validate(String? input) {
    final v = input ?? '';
    if (v.isEmpty) return 'Nhập mật khẩu.';
    if (v.length < minLength) return 'Mật khẩu ít nhất $minLength ký tự.';
    if (v.length > maxLength) return 'Mật khẩu tối đa $maxLength ký tự.';
    if (!RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v)) {
      return 'Mật khẩu cần có cả chữ và số.';
    }
    return null;
  }
}

/// Giới hạn đăng nhập sai.
abstract final class LoginPolicy {
  static const maxFailures = 5;
  static const lockDuration = Duration(minutes: 15);
}
