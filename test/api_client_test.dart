import 'dart:convert';

import 'package:campus_safety/core/network/api_client.dart';
import 'package:campus_safety/core/network/api_error.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  ApiClient client(MockClientHandler handler, {String? token = 'id-token'}) => ApiClient(
        baseUrl: 'http://backend.test',
        idToken: () async => token,
        client: MockClient(handler),
      );

  http.Response json(int status, Object body) => http.Response.bytes(
        utf8.encode(jsonEncode(body)),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  test('gắn Firebase ID token và trả JSON', () async {
    late http.Request seen;
    final api = client((req) async {
      seen = req;
      return json(200, {'ok': true});
    });
    expect(await api.post('/reports', {'a': 1}), {'ok': true});
    expect(seen.headers['authorization'], 'Bearer id-token');
    expect(seen.url.toString(), 'http://backend.test/reports');
  });

  test('chưa đăng nhập thì không gọi API cần xác thực', () async {
    var called = false;
    final api = client((_) async {
      called = true;
      return json(200, {});
    }, token: null);
    await expectLater(api.get('/me'), throwsA(isA<ApiError>().having((e) => e.statusCode, 'status', 401)));
    expect(called, isFalse);
  });

  test('lỗi từ backend giữ nguyên thông báo tiếng Việt và mã lỗi', () async {
    final api = client((_) async => json(503, {
          'error': {'code': 'email_send_failed', 'message': 'Không gửi được email. Kiểm tra lại địa chỉ email rồi thử lại.'},
        }));
    await expectLater(
      api.post('/auth/password/forgot', {'email': 'khoa@gmail.com'}, false),
      throwsA(isA<ApiError>()
          .having((e) => e.code, 'code', 'email_send_failed')
          .having((e) => e.message, 'message', contains('Không gửi được email'))),
    );
  });

  test('lỗi validate theo trường', () async {
    final api = client((_) async => json(422, {
          'error': {
            'code': 'validation_failed',
            'message': 'Chọn toà nhà hoặc khu vực xảy ra sự cố.',
            'details': {
              'fields': {'building': 'Chọn toà nhà hoặc khu vực xảy ra sự cố.'},
            },
          },
        }));
    await expectLater(
      api.post('/reports', {}),
      throwsA(isA<ApiError>().having((e) => e.fieldErrors['building'], 'building', isNotNull)),
    );
  });

  test('giới hạn tần suất có thời gian chờ', () async {
    final api = client((_) async => json(429, {
          'error': {'code': 'otp_cooldown', 'message': 'Vui lòng đợi 45 giây trước khi gửi lại mã.', 'retryAfterSeconds': 45},
        }));
    await expectLater(
      api.post('/auth/otp/request', {'email': 'khoa@gmail.com'}, false),
      throwsA(isA<ApiError>().having((e) => e.retryAfter, 'retryAfter', const Duration(seconds: 45))),
    );
  });

  test('mất mạng thành lỗi tiếng Việt', () async {
    final api = client((_) async => throw http.ClientException('Connection refused'));
    await expectLater(
      api.get('/config', auth: false),
      throwsA(isA<ApiError>()
          .having((e) => e.isNetwork, 'isNetwork', isTrue)
          .having((e) => e.message, 'message', contains('Không kết nối được máy chủ'))),
    );
  });

  test('phản hồi không phải JSON', () async {
    final api = client((_) async => http.Response('<html>Bad gateway</html>', 502));
    await expectLater(api.get('/config', auth: false), throwsA(isA<ApiError>().having((e) => e.statusCode, 'status', 502)));
  });

  test('errorMessage cho lỗi Firestore thiếu quyền', () {
    expect(errorMessage(Exception('[cloud_firestore/permission-denied] Missing permissions')), contains('không có quyền'));
  });

  test('backend báo 401: gọi onSessionExpired; lỗi khác hoặc API công khai thì không', () async {
    var expired = 0;
    final api = ApiClient(
      baseUrl: 'http://x',
      idToken: () async => 'id-token',
      onSessionExpired: () async => expired++,
      client: MockClient((req) async => http.Response(
            req.url.path == '/loi' ? '{"error":{"code":"internal","message":"m"}}' : '{"error":{"code":"unauthorized","message":"m"}}',
            req.url.path == '/loi' ? 500 : 401,
          )),
    );
    await expectLater(api.get('/me'), throwsA(isA<ApiError>()));
    expect(expired, 1);
    await expectLater(api.post('/auth/login', {'username': 'a'}, false), throwsA(isA<ApiError>()));
    expect(expired, 1, reason: 'đăng nhập sai không phải hết phiên');
    await expectLater(api.get('/loi'), throwsA(isA<ApiError>()));
    expect(expired, 1);
  });
}
