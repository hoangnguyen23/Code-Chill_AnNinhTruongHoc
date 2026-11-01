/// Cấu hình build. Truyền khi chạy:
///
/// ```
/// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
/// ```
///
/// - Mặc định: backend đã deploy trên Render.
/// - Máy ảo Android chạy backend trên máy tính: `http://10.0.2.2:8080`.
abstract final class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://an-ninh-truong-hoc-api.onrender.com',
  );

  static const String appName = 'An ninh trường học';

  /// Thời gian chờ tối đa cho một request (gửi báo cáo chờ backend gửi xong thông báo đẩy).
  static const Duration requestTimeout = Duration(seconds: 30);
}
