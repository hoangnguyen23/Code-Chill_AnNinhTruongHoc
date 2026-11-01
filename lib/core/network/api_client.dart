import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'api_error.dart';

/// Lấy Firebase ID token hiện tại (null nếu chưa đăng nhập).
typedef IdTokenProvider = Future<String?> Function();

/// Gọi backend dart_frog. App không chứa secret nào; mọi thao tác ghi đều qua đây.
class ApiClient {
  ApiClient({
    required this.baseUrl,
    required this.idToken,
    this.onSessionExpired,
    http.Client? client,
    this.timeout = AppConfig.requestTimeout,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final IdTokenProvider idToken;

  /// Gọi khi backend báo phiên hết hạn hoặc đã bị thu hồi (đổi mật khẩu, tài khoản bị xoá).
  final Future<void> Function()? onSessionExpired;
  final http.Client _client;
  final Duration timeout;

  final _changes = StreamController<void>.broadcast();

  /// Phát khi dữ liệu có thể đã đổi, để các màn hình đang mở tải lại ngay (xem `pollApi`).
  Stream<void> get changes => _changes.stream;

  void notifyChanged() => _changes.add(null);

  Future<Map<String, Object?>> get(String path, {bool auth = true}) =>
      _send('GET', path, auth: auth);

  Future<Map<String, Object?>> post(String path, [Map<String, Object?>? body, bool auth = true]) =>
      _send('POST', path, body: body, auth: auth);

  Future<Map<String, Object?>> patch(String path, Map<String, Object?> body) =>
      _send('PATCH', path, body: body);

  Future<Map<String, Object?>> put(String path, Map<String, Object?> body) =>
      _send('PUT', path, body: body);

  Future<Map<String, Object?>> delete(String path, [Map<String, Object?>? body]) =>
      _send('DELETE', path, body: body);

  Future<Map<String, Object?>> _send(
    String method,
    String path, {
    Map<String, Object?>? body,
    bool auth = true,
  }) async {
    final headers = <String, String>{
      HttpHeaders.acceptHeader: 'application/json',
      if (body != null) HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8',
    };
    if (auth) {
      final token = await idToken();
      if (token == null) {
        throw const ApiError(
          code: 'unauthorized',
          statusCode: 401,
          message: 'Bạn cần đăng nhập để tiếp tục.',
        );
      }
      headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
    }

    final request = http.Request(method, Uri.parse('$baseUrl$path'))..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);

    final http.Response response;
    try {
      response = await http.Response.fromStream(await _client.send(request).timeout(timeout))
          .timeout(timeout);
    } on TimeoutException {
      throw ApiError.timeout();
    } on SocketException {
      throw ApiError.network();
    } on http.ClientException {
      throw ApiError.network();
    } on HandshakeException {
      throw ApiError.network();
    }

    Object? decoded;
    try {
      decoded = response.bodyBytes.isEmpty ? <String, Object?>{} : jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw ApiError.unexpected(response.statusCode);
    }
    if (response.statusCode == 401 && auth) unawaited(onSessionExpired?.call());
    if (response.statusCode >= 400) throw ApiError.fromBody(response.statusCode, decoded);
    if (method != 'GET' && auth) notifyChanged();
    if (decoded is Map<String, Object?>) return decoded;
    throw ApiError.unexpected(response.statusCode);
  }
}
