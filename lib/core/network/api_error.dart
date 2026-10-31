/// Lỗi trả về từ backend (`{"error": {"code", "message", "details"}}`) hoặc lỗi mạng.
/// [message] luôn là tiếng Việt, hiển thị trực tiếp cho người dùng.
class ApiError implements Exception {
  const ApiError({
    required this.code,
    required this.message,
    this.statusCode,
    this.fieldErrors = const {},
    this.retryAfter,
    this.details = const {},
  });

  factory ApiError.network() => const ApiError(
        code: 'network',
        message: 'Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.',
      );

  factory ApiError.timeout() => const ApiError(
        code: 'timeout',
        message: 'Máy chủ phản hồi quá lâu. Thử lại sau ít phút.',
      );

  factory ApiError.unexpected([int? status]) => ApiError(
        code: 'unexpected',
        statusCode: status,
        message: 'Máy chủ trả về dữ liệu không đọc được${status == null ? '' : ' (mã $status)'}.',
      );

  /// Đọc body lỗi chuẩn của backend.
  factory ApiError.fromBody(int statusCode, Object? body) {
    if (body is Map && body['error'] is Map) {
      final e = body['error'] as Map;
      final details = e['details'] is Map ? Map<String, Object?>.from(e['details'] as Map) : <String, Object?>{};
      final fields = details['fields'] is Map
          ? (details['fields'] as Map).map((k, v) => MapEntry('$k', '$v'))
          : <String, String>{};
      final retry = e['retryAfterSeconds'];
      return ApiError(
        code: (e['code'] as String?) ?? 'error',
        message: (e['message'] as String?) ?? 'Có lỗi xảy ra.',
        statusCode: statusCode,
        fieldErrors: fields,
        retryAfter: retry is int ? Duration(seconds: retry) : null,
        details: details,
      );
    }
    return ApiError.unexpected(statusCode);
  }

  final String code;
  final String message;
  final int? statusCode;
  final Map<String, String> fieldErrors;
  final Duration? retryAfter;
  final Map<String, Object?> details;

  bool get isNetwork => code == 'network' || code == 'timeout';
  bool get isUnauthorized => statusCode == 401;

  /// Lỗi đến từ Zalo (mã `zalo_*`).
  bool get isZalo => code.startsWith('zalo_');

  int? get zaloErrorCode => details['zaloErrorCode'] as int?;

  @override
  String toString() => message;
}

/// Lấy thông báo tiếng Việt từ một lỗi bất kỳ.
String errorMessage(Object error) {
  if (error is ApiError) return error.message;
  final text = error.toString();
  if (text.contains('permission-denied')) {
    return 'Bạn không có quyền xem dữ liệu này.';
  }
  if (text.contains('unavailable') || text.contains('network')) {
    return 'Mất kết nối. Dữ liệu sẽ tự cập nhật khi có mạng.';
  }
  if (text.contains('failed-precondition') && text.contains('index')) {
    return 'Firestore chưa có chỉ mục cho truy vấn này. Quản trị cần deploy firestore.indexes.json.';
  }
  return 'Đã có lỗi xảy ra. Vui lòng thử lại.';
}
