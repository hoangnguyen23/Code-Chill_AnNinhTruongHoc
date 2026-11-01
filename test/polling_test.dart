import 'dart:convert';

import 'package:campus_safety/core/network/api_client.dart';
import 'package:campus_safety/core/network/api_error.dart';
import 'package:campus_safety/core/network/polling.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late int status;
  late Object body;
  late int gets;

  ApiClient client() => ApiClient(
        baseUrl: 'http://x',
        idToken: () async => 'token',
        client: MockClient((req) async {
          if (req.method == 'GET') gets++;
          return http.Response(jsonEncode(body), status);
        }),
      );

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

  setUp(() {
    status = 200;
    body = {'n': 1};
    gets = 0;
  });

  test('tải ngay, dữ liệu không đổi thì không phát lại, ghi xong thì tải lại liền', () async {
    final api = client();
    final seen = <Object?>[];
    final sub = pollApi(api, '/a', (j) => j['n'], every: const Duration(hours: 1)).listen(seen.add);
    await settle();
    expect(seen, [1]);

    api.notifyChanged();
    await settle();
    expect(seen, [1], reason: 'dữ liệu y hệt');
    expect(gets, 2);

    body = {'n': 2};
    await api.post('/b', {});
    await settle();
    expect(seen, [1, 2]);
    await sub.cancel();
  });

  test('mất mạng giữ dữ liệu cũ; lỗi quyền vẫn phát ra', () async {
    final api = client();
    final seen = <Object?>[];
    final errors = <Object>[];
    final sub = pollApi(api, '/a', (j) => j['n'], every: const Duration(hours: 1)).listen(seen.add, onError: errors.add);
    await settle();

    status = 503;
    body = {'error': {'code': 'x', 'message': 'm'}};
    api.notifyChanged();
    await settle();
    expect(errors, isEmpty);

    status = 403;
    api.notifyChanged();
    await settle();
    expect(errors.single, isA<ApiError>().having((e) => e.statusCode, 'status', 403));
    await sub.cancel();
  });

  test('chưa có dữ liệu mà lỗi thì báo, có mạng lại thì tự hồi phục', () async {
    status = 503;
    body = {'error': {'code': 'x', 'message': 'm'}};
    final api = client();
    final seen = <Object?>[];
    final errors = <Object>[];
    final sub = pollApi(api, '/a', (j) => j['n'], every: const Duration(hours: 1)).listen(seen.add, onError: errors.add);
    await settle();
    expect(errors, hasLength(1));

    status = 200;
    body = {'n': 5};
    api.notifyChanged();
    await settle();
    expect(seen, [5]);
    await sub.cancel();
  });

  test('hết lỗi quyền mà dữ liệu y hệt thì vẫn phát lại để thoát màn lỗi', () async {
    final api = client();
    final seen = <Object?>[];
    final sub = pollApi(api, '/a', (j) => j['n'], every: const Duration(hours: 1)).listen(seen.add, onError: (_) {});
    await settle();

    status = 403;
    final old = body;
    body = {'error': {'code': 'x', 'message': 'm'}};
    api.notifyChanged();
    await settle();

    status = 200;
    body = old;
    api.notifyChanged();
    await settle();
    expect(seen, [1, 1]);
    await sub.cancel();
  });

  test('huỷ lắng nghe thì dừng tải', () async {
    final api = client();
    final sub = pollApi(api, '/a', (j) => j['n'], every: const Duration(milliseconds: 5)).listen((_) {});
    await settle();
    await sub.cancel();
    final after = gets;
    await settle();
    api.notifyChanged();
    await settle();
    expect(gets, after);
  });
}
