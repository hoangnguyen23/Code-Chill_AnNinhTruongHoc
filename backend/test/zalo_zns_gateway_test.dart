import 'dart:convert';

import 'package:campus_core/campus_core.dart';
import 'package:campus_safety_backend/backend.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'support/fakes.dart';

/// Giả lập máy chủ Zalo bằng MockClient của package:http để kiểm tra đúng request/response
/// theo tài liệu. Mã chạy thật gọi https://business.openapi.zalo.me và https://oauth.zaloapp.com.
void main() {
  final now = DateTime.utc(2026, 10, 19, 3);
  final phone = VietnamPhone.parse('0912345678');
  const templates = {
    ZaloTemplateKey.otp: 'tplOtp123',
    ZaloTemplateKey.reportReceived: 'tplRpt456',
  };

  late MemorySendLogRepository logs;
  late MemoryTokenStore store;
  late List<http.Request> sendRequests;
  late List<http.Request> oauthRequests;

  ZaloTokenState validState(String access, String refresh) => ZaloTokenState(
        accessToken: access,
        refreshToken: refresh,
        accessTokenExpiresAt: now.add(const Duration(hours: 20)),
        updatedAt: now,
        seedFingerprint: ZaloTokenManager.fingerprint('seed-rt'),
      );

  setUp(() {
    logs = MemorySendLogRepository();
    store = MemoryTokenStore(validState('AT-1', 'RT-1'));
    sendRequests = [];
    oauthRequests = [];
  });

  ZaloZnsGateway gateway({
    required Future<http.Response> Function(http.Request) onSend,
    Future<http.Response> Function(http.Request)? onOauth,
    ZnsMode mode = ZnsMode.production,
  }) {
    final client = MockClient((req) async {
      if (req.url.host == 'business.openapi.zalo.me') {
        sendRequests.add(req);
        return onSend(req);
      }
      oauthRequests.add(req);
      if (onOauth == null) return http.Response('{"error":-1}', 400);
      return onOauth(req);
    });
    final tokens = ZaloTokenManager(
      client: client,
      store: store,
      appId: '1234567890',
      secretKey: 'app-secret',
      seedRefreshToken: 'seed-rt',
      clock: () => now,
    );
    return ZaloZnsGateway(
      client: client,
      tokens: tokens,
      mode: mode,
      templateIds: templates,
      logs: logs,
      clock: () => now,
    );
  }

  http.Response json(Object body) => http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  final okBody = {
    'error': 0,
    'message': 'Success',
    'data': {
      'msg_id': 'a4d0243feee163bd3af2',
      'sent_time': '1626926349402',
      'sending_mode': '1',
      'quota': {'dailyQuota': '500', 'remainingQuota': '499'},
    },
  };

  TemplateMessage otpMessage() => TemplateMessage(
        recipient: phone,
        template: ZaloTemplateKey.otp,
        data: const {'otp': '482915'},
        purpose: NotificationPurpose.otp,
      );

  test('gửi thành công: đúng endpoint, header, body theo tài liệu', () async {
    final gw = gateway(onSend: (_) async => json(okBody));
    final result = await gw.send(otpMessage());

    expect(result.success, isTrue);
    expect(result.messageId, 'a4d0243feee163bd3af2');
    expect(result.dailyQuota, 500);
    expect(result.remainingQuota, 499);
    expect(result.attempts, 1);

    final req = sendRequests.single;
    expect(req.method, 'POST');
    expect(req.url.toString(), 'https://business.openapi.zalo.me/message/template');
    expect(req.headers['access_token'], 'AT-1');
    expect(req.headers['content-type'], startsWith('application/json'));
    final body = jsonDecode(req.body) as Map<String, Object?>;
    expect(body['phone'], '84912345678');
    expect(body['template_id'], 'tplOtp123');
    expect(body['template_data'], {'otp': '482915'});
    expect(body.containsKey('mode'), isFalse, reason: 'production không gửi tham số mode');
    final tracking = body['tracking_id'] as String;
    expect(tracking.length, lessThanOrEqualTo(48));
    expect(RegExp(r'^[A-Za-z0-9]+$').hasMatch(tracking), isTrue);
    expect(tracking, startsWith('OTP'));
    expect(result.trackingId, tracking);
  });

  test('chế độ development thêm "mode": "development"', () async {
    final gw = gateway(onSend: (_) async => json(okBody), mode: ZnsMode.development);
    final result = await gw.send(otpMessage());
    expect(jsonDecode(sendRequests.single.body)['mode'], 'development');
    expect(result.mode, 'development');
  });

  test('ghi nhật ký mỗi lần gửi, che số điện thoại', () async {
    final gw = gateway(onSend: (_) async => json(okBody));
    await gw.send(otpMessage());
    final entry = logs.entries.single.toFirestore();
    expect(entry['recipient'], '84912***678');
    expect(entry['template'], 'otp');
    expect(entry['templateId'], 'tplOtp123');
    expect(entry['trackingId'], isNotEmpty);
    expect(entry['success'], isTrue);
    expect(entry['purpose'], 'otp');
    expect(jsonEncode(entry.map((k, v) => MapEntry(k, '$v'))), isNot(contains('84912345678')));
  });

  test('lỗi -118: số chưa có Zalo, thông báo tiếng Việt và log thất bại', () async {
    final gw = gateway(onSend: (_) async => json({'error': -118, 'message': 'Zalo account not existed'}));
    final result = await gw.send(otpMessage());
    expect(result.success, isFalse);
    expect(result.errorCode, -118);
    expect(result.errorKind, ZaloErrorKind.recipient);
    expect(result.userMessage, contains('chưa có tài khoản Zalo'));
    expect(result.providerMessage, 'Zalo account not existed');
    final entry = logs.entries.single.toFirestore();
    expect(entry['success'], isFalse);
    expect(entry['errorCode'], -118);
  });

  test('lỗi -124: tự làm mới token theo OAuth v4 rồi gửi lại', () async {
    var call = 0;
    final gw = gateway(
      onSend: (req) async {
        call++;
        if (req.headers['access_token'] == 'AT-1') {
          return json({'error': -124, 'message': 'Access token invalid'});
        }
        return json(okBody);
      },
      onOauth: (_) async => json({'access_token': 'AT-2', 'refresh_token': 'RT-2', 'expires_in': '90000'}),
    );
    final result = await gw.send(otpMessage());

    expect(result.success, isTrue);
    expect(result.attempts, 2);
    expect(call, 2);
    expect(sendRequests.last.headers['access_token'], 'AT-2');

    final oauth = oauthRequests.single;
    expect(oauth.url.toString(), 'https://oauth.zaloapp.com/v4/oa/access_token');
    expect(oauth.headers['secret_key'], 'app-secret');
    expect(oauth.headers['content-type'], startsWith('application/x-www-form-urlencoded'));
    expect(oauth.bodyFields, {'refresh_token': 'RT-1', 'app_id': '1234567890', 'grant_type': 'refresh_token'});

    // Refresh token chỉ dùng 1 lần: token mới phải được lưu lại.
    expect(store.state!.accessToken, 'AT-2');
    expect(store.state!.refreshToken, 'RT-2');
    expect(store.state!.accessTokenExpiresAt, now.add(const Duration(seconds: 90000)));
  });

  test('lỗi -124 và làm mới thất bại: báo token hết hạn, hướng dẫn cập nhật refresh token', () async {
    final gw = gateway(
      onSend: (_) async => json({'error': -124, 'message': 'Access token invalid'}),
      onOauth: (_) async => json({'error': -14014, 'error_name': 'Invalid refresh token'}),
    );
    final result = await gw.send(otpMessage());
    expect(result.success, isFalse);
    expect(result.errorKind, ZaloErrorKind.token);
    expect(result.userMessage, contains('ZALO_REFRESH_TOKEN'));
    expect(store.state!.lastError, contains('-14014'));
  });

  test('lỗi -131 / -115 / -133 / -1122 ánh xạ đúng nhóm', () async {
    for (final (code, kind) in [
      (-131, ZaloErrorKind.template),
      (-115, ZaloErrorKind.quota),
      (-133, ZaloErrorKind.timeWindow),
      (-1122, ZaloErrorKind.templateParams),
    ]) {
      final gw = gateway(onSend: (_) async => json({'error': code, 'message': 'x'}));
      final result = await gw.send(otpMessage());
      expect(result.errorKind, kind, reason: 'mã $code');
      expect(result.userMessage, isNotEmpty);
    }
  });

  test('mất kết nối: lỗi mạng, có thể thử lại', () async {
    final gw = gateway(onSend: (_) async => throw http.ClientException('Connection refused'));
    final result = await gw.send(otpMessage());
    expect(result.success, isFalse);
    expect(result.errorKind, ZaloErrorKind.network);
    expect(result.retryable, isTrue);
    expect(logs.entries, hasLength(1));
  });

  test('phản hồi không phải JSON', () async {
    final gw = gateway(onSend: (_) async => http.Response('<html>502</html>', 502));
    final result = await gw.send(otpMessage());
    expect(result.success, isFalse);
    expect(result.errorKind, ZaloErrorKind.unknown);
    expect(result.providerMessage, contains('502'));
  });

  test('template chưa cấu hình: không gọi Zalo, vẫn ghi log', () async {
    final gw = gateway(onSend: (_) async => json(okBody));
    final result = await gw.send(TemplateMessage(
      recipient: phone,
      template: ZaloTemplateKey.guardAlert,
      data: ZaloTemplateKey.guardAlert.sampleData,
      purpose: NotificationPurpose.guardAlert,
    ));
    expect(result.success, isFalse);
    expect(result.errorKind, ZaloErrorKind.template);
    expect(result.userMessage, contains('ZALO_TEMPLATE_GUARD_ALERT'));
    expect(sendRequests, isEmpty);
    expect(logs.entries, hasLength(1));
  });

  test('thiếu tham số: không gọi Zalo, báo tên tham số', () async {
    final gw = gateway(onSend: (_) async => json(okBody));
    final result = await gw.send(TemplateMessage(
      recipient: phone,
      template: ZaloTemplateKey.reportReceived,
      data: const {'customer_name': 'An'},
      purpose: NotificationPurpose.reportReceived,
    ));
    expect(result.errorKind, ZaloErrorKind.templateParams);
    expect(result.userMessage, contains('report_code'));
    expect(sendRequests, isEmpty);
  });
}
