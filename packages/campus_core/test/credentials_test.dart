import 'package:campus_core/campus_core.dart';
import 'package:test/test.dart';

void main() {
  test('tên đăng nhập: chuẩn hoá chữ thường, kiểm tra ký tự', () {
    expect(UsernamePolicy.normalize('  KienNT '), 'kiennt');
    expect(UsernamePolicy.validate('kien.nt_2005'), isNull);
    expect(UsernamePolicy.validate('ab'), contains('3 đến 30'));
    expect(UsernamePolicy.validate('1kien'), contains('bắt đầu bằng chữ cái'));
    expect(UsernamePolicy.validate('kiên'), contains('không dấu'));
    expect(UsernamePolicy.validate('kien..nt'), contains('liền nhau'));
    expect(UsernamePolicy.validate(''), 'Nhập tên đăng nhập.');
  });

  test('mật khẩu: tối thiểu 8 ký tự, có chữ và số', () {
    expect(PasswordPolicy.validate('abc12345'), isNull);
    expect(PasswordPolicy.validate('abc123'), contains('ít nhất 8'));
    expect(PasswordPolicy.validate('abcdefgh'), contains('chữ và số'));
    expect(PasswordPolicy.validate('12345678'), contains('chữ và số'));
    expect(PasswordPolicy.validate('a1' * 40), contains('tối đa'));
  });
}
