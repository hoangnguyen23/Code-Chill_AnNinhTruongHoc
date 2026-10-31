/// Cấu hình build. Truyền khi chạy:
///
/// ```
/// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
/// ```
///
/// - Máy ảo Android: `http://10.0.2.2:8080` (mặc định) trỏ tới backend chạy trên máy tính.
/// - Điện thoại thật qua USB: chạy `adb reverse tcp:8080 tcp:8080` rồi dùng `http://127.0.0.1:8080`.
/// - Bản phát hành: URL HTTPS của backend đã deploy.
abstract final class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  static const String appName = 'An ninh trường học';

  /// Thời gian chờ tối đa cho một request. Gửi báo cáo chờ backend gửi xong tin Zalo
  /// (tối đa khoảng 20 giây) nên đặt rộng hơn.
  static const Duration requestTimeout = Duration(seconds: 30);
}
