import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Chế độ sáng/tối, lưu trên máy. Mặc định theo hệ thống.
class ThemeModeController extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';

  @override
  ThemeMode build() {
    _load();
    return ThemeMode.system;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = ThemeMode.values.where((m) => m.name == prefs.getString(_key)).firstOrNull;
      if (saved != null && saved != state) state = saved;
    } on Object {
      // Không đọc được thì dùng mặc định.
    }
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, mode.name);
    } on Object {
      // Lưu thất bại chỉ ảnh hưởng lần mở sau.
    }
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);
