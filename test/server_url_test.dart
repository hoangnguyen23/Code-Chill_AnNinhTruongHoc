import 'package:campus_safety/core/config/server_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chuẩn hoá địa chỉ máy chủ', () {
    expect(normalizeServerUrl('192.168.1.10'), 'http://192.168.1.10:8080');
    expect(normalizeServerUrl(' 192.168.1.10:9000/ '), 'http://192.168.1.10:9000');
    expect(normalizeServerUrl('http://10.12.51.220:8080'), 'http://10.12.51.220:8080');
    expect(normalizeServerUrl('https://api.truong.edu.vn'), 'https://api.truong.edu.vn');
    expect(normalizeServerUrl(''), isNull);
    expect(normalizeServerUrl('http://10.0.0.1:8080/api'), isNull);
  });
}
