import 'dart:async';
import 'dart:convert';

import 'package:campus_safety_backend/backend.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'support/fakes.dart';

void main() {
  late TestClock clock;
  late MemoryTokenStore store;
  late List<http.Request> calls;

  setUp(() {
    clock = TestClock(DateTime.utc(2026, 10, 19, 1));
    store = MemoryTokenStore();
    calls = [];
  });

  ZaloTokenManager manager({
    String seedRefresh = 'RT-seed',
    String? seedAccess,
    Future<http.Response> Function(http.Request)? handler,
  }) =>
      ZaloTokenManager(
        client: MockClient((req) async {
          calls.add(req);
          return handler == null
              ? http.Response(jsonEncode({
                  'access_token': 'AT-${calls.length}',
                  'refresh_token': 'RT-${calls.length}',
                  'expires_in': '90000',
                }), 200)
              : handler(req);
        }),
        store: store,
        appId: '42',
        secretKey: 'secret',
        seedRefreshToken: seedRefresh,
        seedAccessToken: seedAccess,
        clock: clock.call,
      );

  test('lần đầu: nạp access token từ .env, không gọi OAuth', () async {
    final m = manager(seedAccess: 'AT-env');
    expect(await m.accessToken(), 'AT-env');
    expect(calls, isEmpty);
    expect(store.state!.refreshToken, 'RT-seed');
  });

  test('không có access token: làm mới bằng refresh token và lưu token xoay vòng', () async {
    final m = manager();
    expect(await m.accessToken(), 'AT-1');
    expect(calls.single.bodyFields['refresh_token'], 'RT-seed');
    expect(store.state!.refreshToken, 'RT-1');
    expect(store.state!.lastRefreshAt, clock.now);

    // Hết hạn sau 25 giờ: lần sau dùng refresh token MỚI.
    clock.advance(const Duration(hours: 25));
    expect(await m.accessToken(), 'AT-2');
    expect(calls.last.bodyFields['refresh_token'], 'RT-1');
  });

  test('còn hạn thì dùng lại, không gọi OAuth', () async {
    final m = manager();
    await m.accessToken();
    clock.advance(const Duration(hours: 10));
    await m.accessToken();
    expect(calls, hasLength(1));
  });

  test('nhiều request cùng lúc chỉ làm mới một lần (refresh token dùng 1 lần)', () async {
    final gate = Completer<void>();
    final m = manager(handler: (req) async {
      await gate.future;
      return http.Response(jsonEncode({'access_token': 'AT-x', 'refresh_token': 'RT-x', 'expires_in': 90000}), 200);
    });
    final futures = List.generate(5, (_) => m.accessToken());
    await Future<void>.delayed(Duration.zero);
    gate.complete();
    expect(await Future.wait(futures), everyElement('AT-x'));
    expect(calls, hasLength(1));
  });

  test('dán refresh token mới vào .env thì nạp lại', () async {
    await manager(seedRefresh: 'RT-old').accessToken();
    expect(store.state!.refreshToken, 'RT-1');
    final m2 = manager(seedRefresh: 'RT-new');
    await m2.accessToken();
    expect(calls.last.bodyFields['refresh_token'], 'RT-new');
  });

  test('khởi động lại backend với .env cũ vẫn dùng token đã xoay vòng trong kho', () async {
    await manager(seedRefresh: 'RT-seed').accessToken();
    clock.advance(const Duration(hours: 26));
    await manager(seedRefresh: 'RT-seed').accessToken();
    expect(calls.last.bodyFields['refresh_token'], 'RT-1');
  });

  test('làm mới thất bại: ném ZaloTokenException và lưu lỗi', () async {
    final m = manager(
      handler: (_) async => http.Response(
        jsonEncode({'error': -14014, 'error_name': 'Invalid parameter', 'error_description': 'refresh_token is expired'}),
        200,
      ),
    );
    await expectLater(
      m.accessToken(),
      throwsA(isA<ZaloTokenException>().having((e) => e.detail, 'detail', contains('refresh_token is expired'))),
    );
    expect(store.state!.lastError, contains('-14014'));
    final status = await m.status();
    expect(status['lastError'], contains('expired'));
    expect(status.containsKey('accessToken'), isFalse, reason: 'không lộ token');
  });

  test('forceRefresh bỏ qua khi tiến trình khác đã làm mới', () async {
    final m = manager();
    final first = await m.accessToken();
    store.state = ZaloTokenState(
      accessToken: 'AT-other',
      refreshToken: 'RT-other',
      accessTokenExpiresAt: clock.now.add(const Duration(hours: 24)),
      updatedAt: clock.now,
      seedFingerprint: ZaloTokenManager.fingerprint('RT-seed'),
    );
    expect(await m.forceRefresh(rejectedAccessToken: first), 'AT-other');
    expect(calls, hasLength(1));
  });

  test('mất mạng khi làm mới', () async {
    final m = manager(handler: (_) async => throw http.ClientException('offline'));
    await expectLater(m.accessToken(), throwsA(isA<ZaloTokenException>()));
  });
}
