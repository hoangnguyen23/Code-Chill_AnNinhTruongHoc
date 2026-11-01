import 'dart:async';
import 'dart:convert';

import 'api_client.dart';
import 'api_error.dart';

/// `false` khi app ở nền: ngừng hỏi định kỳ để tiết kiệm pin và lưu lượng.
var pollingEnabled = true;

/// Biến `GET` thành luồng dữ liệu: tải ngay, tải lại mỗi [every], và tải lại liền khi app vừa ghi
/// dữ liệu hoặc nhận thông báo đẩy ([ApiClient.changes]). Dữ liệu không đổi thì không phát lại,
/// nên màn hình không dựng lại vô ích.
///
/// Lỗi mạng khi đã có dữ liệu thì giữ dữ liệu cũ. Lỗi 4xx (mất quyền, tài khoản bị khoá) luôn được
/// phát ra để màn hình phản ứng.
Stream<T> pollApi<T>(
  ApiClient api,
  String path,
  T Function(Map<String, Object?> json) parse, {
  Duration every = const Duration(seconds: 8),
}) {
  late final StreamController<T> controller;
  Timer? timer;
  StreamSubscription<void>? changes;
  String? last;
  var loading = false;
  var again = false;

  Future<void> load() async {
    if (loading) {
      again = true;
      return;
    }
    loading = true;
    try {
      final json = await api.get(path);
      if (controller.isClosed) return;
      final encoded = jsonEncode(json);
      if (encoded != last) {
        last = encoded;
        controller.add(parse(json));
      }
    } on ApiError catch (e, st) {
      final status = e.statusCode ?? 0;
      final clientError = status >= 400 && status < 500;
      if (!controller.isClosed && (last == null || clientError)) controller.addError(e, st);
      // Lần sau dữ liệu trở lại y hệt (vd. quản trị mở khoá) vẫn phải phát để màn hình thoát lỗi.
      if (clientError) last = null;
    } finally {
      loading = false;
      if (again) {
        again = false;
        unawaited(load());
      }
    }
  }

  controller = StreamController<T>(
    onListen: () {
      unawaited(load());
      timer = Timer.periodic(every, (_) {
        if (pollingEnabled) unawaited(load());
      });
      changes = api.changes.listen((_) => unawaited(load()));
    },
    onCancel: () async {
      timer?.cancel();
      await changes?.cancel();
      await controller.close();
    },
  );
  return controller.stream;
}
