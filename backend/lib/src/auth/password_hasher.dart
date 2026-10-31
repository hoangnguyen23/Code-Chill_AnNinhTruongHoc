import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Băm mật khẩu bằng PBKDF2-HMAC-SHA256 có muối ngẫu nhiên.
///
/// Định dạng lưu: `pbkdf2_sha256$<số vòng>$<muối base64>$<băm base64>`, nên tăng [iterations]
/// sau này vẫn kiểm tra được mật khẩu cũ.
class PasswordHasher {
  PasswordHasher({this.iterations = 80000, Random? random}) : _random = random ?? Random.secure();

  final int iterations;
  final Random _random;

  static const _prefix = 'pbkdf2_sha256';
  static const _keyLength = 32;

  String hash(String password) {
    final salt = Uint8List.fromList(List.generate(16, (_) => _random.nextInt(256)));
    final key = _pbkdf2(utf8.encode(password), salt, iterations);
    return '$_prefix\$$iterations\$${base64Encode(salt)}\$${base64Encode(key)}';
  }

  bool verify(String password, String stored) {
    final parts = stored.split(r'$');
    if (parts.length != 4 || parts[0] != _prefix) return false;
    final rounds = int.tryParse(parts[1]);
    if (rounds == null || rounds < 1) return false;
    final List<int> salt, expected;
    try {
      salt = base64Decode(parts[2]);
      expected = base64Decode(parts[3]);
    } on FormatException {
      return false;
    }
    final actual = _pbkdf2(utf8.encode(password), salt, rounds);
    if (actual.length != expected.length) return false;
    var diff = 0;
    for (var i = 0; i < actual.length; i++) {
      diff |= actual[i] ^ expected[i];
    }
    return diff == 0;
  }

  /// PBKDF2 (RFC 8018) với khoá dài 32 byte = đúng một khối SHA-256.
  static List<int> _pbkdf2(List<int> password, List<int> salt, int rounds) {
    final hmac = Hmac(sha256, password);
    var u = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    final result = Uint8List.fromList(u);
    for (var i = 1; i < rounds; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < _keyLength; j++) {
        result[j] ^= u[j];
      }
    }
    return result;
  }
}
