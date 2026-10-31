import 'dart:convert';
import 'dart:io';

import 'package:campus_core/campus_core.dart';
import 'package:dart_frog/dart_frog.dart';

import 'api_exception.dart';

/// Đọc body JSON dạng object. Ném [ApiException] 400 nếu sai định dạng.
Future<Map<String, Object?>> readJsonObject(Request request) async {
  final String raw;
  try {
    raw = await request.body();
  } on Object {
    throw ApiException.badRequest('Không đọc được dữ liệu gửi lên.');
  }
  if (raw.length > 64 * 1024) {
    throw ApiException(HttpStatus.requestEntityTooLarge, 'payload_too_large', 'Dữ liệu gửi lên quá lớn.');
  }
  if (raw.trim().isEmpty) return {};
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, Object?>) return decoded;
  } on FormatException {
    // xử lý bên dưới
  }
  throw ApiException.badRequest('Dữ liệu gửi lên không phải JSON hợp lệ.');
}

String requireString(Map<String, Object?> body, String key, {String? label, int maxLength = 500}) {
  final v = body[key];
  if (v is! String || v.trim().isEmpty) {
    throw ApiException.validation({key: 'Thiếu ${label ?? key}.'});
  }
  if (v.length > maxLength) {
    throw ApiException.validation({key: '${label ?? key} tối đa $maxLength ký tự.'});
  }
  return v.trim();
}

String? optionalString(Map<String, Object?> body, String key, {String? label, int maxLength = 500}) {
  final v = body[key];
  if (v == null) return null;
  if (v is! String) throw ApiException.validation({key: '${label ?? key} không hợp lệ.'});
  if (v.length > maxLength) {
    throw ApiException.validation({key: '${label ?? key} tối đa $maxLength ký tự.'});
  }
  return v.trim();
}

bool? optionalBool(Map<String, Object?> body, String key) {
  final v = body[key];
  if (v == null) return null;
  if (v is bool) return v;
  throw ApiException.validation({key: 'Giá trị $key phải là true/false.'});
}

double? optionalDouble(Map<String, Object?> body, String key) {
  final v = body[key];
  if (v == null) return null;
  if (v is num && v.isFinite) return v.toDouble();
  throw ApiException.validation({key: 'Giá trị $key phải là số.'});
}

int? optionalInt(Map<String, Object?> body, String key) {
  final v = body[key];
  if (v == null) return null;
  if (v is int) return v;
  if (v is num && v == v.roundToDouble()) return v.toInt();
  throw ApiException.validation({key: 'Giá trị $key phải là số nguyên.'});
}

/// Số điện thoại tuỳ chọn ở trường `phone`: không gửi hoặc chuỗi rỗng trả về `null`,
/// sai định dạng thì báo lỗi tiếng Việt.
VietnamPhone? readOptionalPhone(Map<String, Object?> body) {
  final raw = optionalString(body, 'phone', label: 'số điện thoại', maxLength: 30);
  if (raw == null || raw.isEmpty) return null;
  try {
    return VietnamPhone.parse(raw);
  } on PhoneFormatException catch (e) {
    throw ApiException.validation({'phone': e.message});
  }
}

/// IP của client. Khi [trustProxy] bật (chạy sau Cloud Run/Nginx) thì lấy IP đầu tiên trong
/// `X-Forwarded-For`.
String clientIp(RequestContext context, {required bool trustProxy}) {
  if (trustProxy) {
    final forwarded = context.request.headers['x-forwarded-for'];
    if (forwarded != null && forwarded.trim().isNotEmpty) {
      return forwarded.split(',').first.trim();
    }
  }
  return context.request.connectionInfo.remoteAddress.address;
}

/// Chỉ cho phép các phương thức trong [allowed].
void ensureMethod(RequestContext context, Set<HttpMethod> allowed) {
  if (!allowed.contains(context.request.method)) throw ApiException.methodNotAllowed();
}
