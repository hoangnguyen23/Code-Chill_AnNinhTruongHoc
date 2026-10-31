import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_config.dart';

/// Địa chỉ backend đang dùng. Mặc định lấy từ `--dart-define=API_BASE_URL`; người dùng có thể đổi
/// ngay trong app (màn đăng nhập) khi IP Wi-Fi của máy chạy backend thay đổi, không cần build lại.
class ServerUrlController extends Notifier<String> {
  static const _key = 'api_base_url';

  @override
  String build() {
    _load();
    return AppConfig.apiBaseUrl;
  }

  Future<void> _load() async {
    try {
      final saved = (await SharedPreferences.getInstance()).getString(_key);
      if (saved != null && saved.isNotEmpty && saved != state) state = saved;
    } on Object {
      // Không đọc được thì dùng mặc định.
    }
  }

  /// Lưu địa chỉ mới (đã chuẩn hoá bằng [normalizeServerUrl]). Chuỗi rỗng là về mặc định.
  Future<void> set(String url) async {
    final value = url.isEmpty ? AppConfig.apiBaseUrl : url;
    state = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (url.isEmpty) {
        await prefs.remove(_key);
      } else {
        await prefs.setString(_key, value);
      }
    } on Object {
      // Lưu thất bại chỉ ảnh hưởng lần mở sau.
    }
  }
}

final serverUrlProvider = NotifierProvider<ServerUrlController, String>(ServerUrlController.new);

/// Chuẩn hoá địa chỉ người dùng nhập: thêm `http://` nếu thiếu, cổng 8080 nếu chỉ nhập IP, bỏ `/` cuối.
/// Trả về `null` nếu không hợp lệ.
String? normalizeServerUrl(String input) {
  var v = input.trim();
  if (v.isEmpty) return null;
  if (!v.startsWith('http://') && !v.startsWith('https://')) v = 'http://$v';
  final uri = Uri.tryParse(v);
  if (uri == null || uri.host.isEmpty || (uri.path.isNotEmpty && uri.path != '/')) return null;
  final withPort = (!uri.hasPort && uri.scheme == 'http') ? uri.replace(port: 8080) : uri;
  final s = withPort.replace(path: '').toString();
  return s.endsWith('/') ? s.substring(0, s.length - 1) : s;
}
