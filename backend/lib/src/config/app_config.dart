import 'dart:convert';
import 'dart:io';

import 'package:campus_core/campus_core.dart';

import '../notifications/zalo/zalo_templates.dart';

/// Chế độ gửi ZBS Template Message. `development` thêm `"mode": "development"` vào body
/// (chỉ gửi được tới quản trị viên ứng dụng/OA); `production` gửi thật.
enum ZnsMode {
  development,
  production;

  static ZnsMode? tryParse(String? raw) {
    for (final m in values) {
      if (m.name == raw?.trim().toLowerCase()) return m;
    }
    return null;
  }
}

class ConfigException implements Exception {
  ConfigException(this.problems);

  final List<String> problems;

  @override
  String toString() =>
      'Cấu hình backend chưa đúng (.env):\n${problems.map((p) => '  - $p').join('\n')}';
}

/// Toàn bộ cấu hình đọc từ `.env` / biến môi trường.
class AppConfig {
  AppConfig({
    required this.firebaseProjectId,
    required this.serviceAccountPath,
    required this.zaloAppId,
    required this.zaloSecretKey,
    required this.zaloSeedAccessToken,
    required this.zaloSeedRefreshToken,
    required this.znsMode,
    required this.templateIds,
    required this.otpPepper,
    required this.smtpHost,
    required this.smtpPort,
    required this.smtpUsername,
    required this.smtpPassword,
    required this.mailFromName,
    required this.allowSelfRegistration,
    required this.bootstrapAdminEmails,
    required this.dutyGuardPhones,
    required this.dutyHotline,
    required this.campusName,
    required this.defaultBuildings,
    required this.trustProxy,
    this.warnings = const [],
  });

  final String firebaseProjectId;
  final String? serviceAccountPath;
  final String zaloAppId;
  final String zaloSecretKey;
  final String? zaloSeedAccessToken;
  final String zaloSeedRefreshToken;
  final ZnsMode znsMode;
  final Map<ZaloTemplateKey, String> templateIds;
  final String otpPepper;

  /// Máy chủ gửi email OTP (mặc định Gmail).
  final String smtpHost;
  final int smtpPort;
  final String smtpUsername;
  final String smtpPassword;
  final String mailFromName;
  final bool allowSelfRegistration;
  final Set<EmailAddress> bootstrapAdminEmails;

  /// Có cấu hình Zalo hay không. Tắt Zalo thì tin báo cáo chỉ gửi qua push FCM.
  bool get zaloEnabled => zaloAppId.isNotEmpty;
  final List<VietnamPhone> dutyGuardPhones;
  final String? dutyHotline;
  final String campusName;
  final List<String> defaultBuildings;
  final bool trustProxy;

  /// Cảnh báo không chặn khởi động (ví dụ thiếu template ID).
  final List<String> warnings;

  /// Mọi biến cấu hình backend đọc (xem `.env.example`).
  static final List<String> knownKeys = [
    'FIREBASE_PROJECT_ID',
    'GOOGLE_APPLICATION_CREDENTIALS',
    'ZALO_APP_ID',
    'ZALO_SECRET_KEY',
    'ZALO_ACCESS_TOKEN',
    'ZALO_REFRESH_TOKEN',
    'ZALO_ZNS_MODE',
    for (final key in ZaloTemplateKey.values) key.envVar,
    'OTP_PEPPER',
    'SMTP_HOST',
    'SMTP_PORT',
    'SMTP_USERNAME',
    'SMTP_PASSWORD',
    'MAIL_FROM_NAME',
    'ALLOW_SELF_REGISTRATION',
    'BOOTSTRAP_ADMIN_EMAILS',
    'DUTY_HOTLINE',
    'DUTY_GUARD_PHONES',
    'CAMPUS_NAME',
    'TRUST_PROXY',
  ];

  /// Đọc cấu hình từ [env]. Ném [ConfigException] liệt kê mọi lỗi cùng lúc.
  factory AppConfig.fromEnvironment(
    Map<String, String> env, {
    List<String> defaultBuildings = const [],
  }) {
    final problems = <String>[];
    final warnings = <String>[];

    String? read(String key) {
      final v = env[key]?.trim();
      return (v == null || v.isEmpty) ? null : v;
    }

    String requireKey(String key, String hint) {
      final v = read(key);
      if (v == null) problems.add('Thiếu $key: $hint');
      return v ?? '';
    }

    bool readBool(String key, {required bool fallback}) {
      final v = read(key)?.toLowerCase();
      if (v == null) return fallback;
      if (v == 'true' || v == '1' || v == 'yes') return true;
      if (v == 'false' || v == '0' || v == 'no') return false;
      problems.add('$key phải là true hoặc false (đang là "$v").');
      return fallback;
    }

    List<VietnamPhone> readPhones(String key) {
      final raw = read(key);
      if (raw == null) return const [];
      final result = <VietnamPhone>[];
      for (final part in raw.split(RegExp(r'[,;]'))) {
        if (part.trim().isEmpty) continue;
        try {
          result.add(VietnamPhone.parse(part));
        } on PhoneFormatException catch (e) {
          problems.add('$key có số không hợp lệ "${part.trim()}": ${e.message}');
        }
      }
      return result;
    }

    List<EmailAddress> readEmails(String key) {
      final raw = read(key);
      if (raw == null) return const [];
      final result = <EmailAddress>[];
      for (final part in raw.split(RegExp(r'[,;]'))) {
        if (part.trim().isEmpty) continue;
        try {
          result.add(EmailAddress.parse(part));
        } on EmailFormatException catch (e) {
          problems.add('$key có email không hợp lệ "${part.trim()}": ${e.message}');
        }
      }
      return result;
    }

    final projectId = requireKey('FIREBASE_PROJECT_ID', 'Project ID của Firebase.');

    // Zalo là tuỳ chọn: chỉ bắt buộc đủ bộ khi đã điền ít nhất một biến Zalo.
    final zaloEnabled = ['ZALO_APP_ID', 'ZALO_SECRET_KEY', 'ZALO_REFRESH_TOKEN'].any((k) => read(k) != null);
    var appId = '';
    var secret = '';
    var refresh = '';
    ZnsMode? mode = ZnsMode.development;
    final templateIds = <ZaloTemplateKey, String>{};
    if (!zaloEnabled) {
      warnings.add('Chưa cấu hình Zalo (ZALO_APP_ID...): tin báo cáo chỉ gửi qua thông báo đẩy trong app.');
    } else {
      appId = requireKey('ZALO_APP_ID', 'ID ứng dụng trên developers.zalo.me.');
      if (appId.isNotEmpty && !RegExp(r'^\d+$').hasMatch(appId)) {
        problems.add('ZALO_APP_ID chỉ gồm chữ số.');
      }
      secret = requireKey('ZALO_SECRET_KEY', 'Khoá bí mật của ứng dụng Zalo.');
      refresh = requireKey(
        'ZALO_REFRESH_TOKEN',
        'Refresh token của OA (lấy bằng API Explorer hoặc OAuth v4, xem README).',
      );

      final modeRaw = read('ZALO_ZNS_MODE');
      mode = ZnsMode.tryParse(modeRaw);
      if (mode == null) {
        problems.add('ZALO_ZNS_MODE phải là "development" hoặc "production" (đang là "${modeRaw ?? ''}").');
      }
    }

    for (final key in ZaloTemplateKey.values) {
      // Mã OTP gửi qua email, không cần template OTP của Zalo.
      if (!zaloEnabled || key == ZaloTemplateKey.otp) continue;
      final id = read(key.envVar);
      if (id == null) {
        warnings.add('Chưa cấu hình ${key.envVar}: tin "${key.title}" sẽ không gửi được.');
      } else if (!RegExp(r'^[A-Za-z0-9]+$').hasMatch(id)) {
        problems.add('${key.envVar} chỉ gồm chữ và số (đang là "$id").');
      } else {
        templateIds[key] = id;
      }
    }

    final pepper = requireKey('OTP_PEPPER', 'Chuỗi bí mật >= 32 ký tự để băm OTP.');
    if (pepper.isNotEmpty && pepper.length < 32) {
      problems.add('OTP_PEPPER phải dài ít nhất 32 ký tự.');
    }

    final smtpUser = requireKey('SMTP_USERNAME', 'Địa chỉ Gmail dùng để gửi mã OTP.');
    if (smtpUser.isNotEmpty && EmailAddress.tryParse(smtpUser) == null) {
      problems.add('SMTP_USERNAME phải là địa chỉ email (đang là "$smtpUser").');
    }
    // Mật khẩu ứng dụng Gmail hiển thị dạng "abcd efgh ijkl mnop": bỏ khoảng trắng.
    final smtpPassword = requireKey(
      'SMTP_PASSWORD',
      'Mật khẩu ứng dụng của Gmail (myaccount.google.com/apppasswords), không phải mật khẩu đăng nhập.',
    ).replaceAll(' ', '');
    final portRaw = read('SMTP_PORT');
    final smtpPort = portRaw == null ? 587 : int.tryParse(portRaw);
    if (smtpPort == null || smtpPort <= 0 || smtpPort > 65535) {
      problems.add('SMTP_PORT phải là số cổng hợp lệ, thường là 587 hoặc 465 (đang là "$portRaw").');
    }

    final hotlineRaw = read('DUTY_HOTLINE');
    if (hotlineRaw != null && !RegExp(r'^[0-9+ ().-]{3,20}$').hasMatch(hotlineRaw)) {
      problems.add('DUTY_HOTLINE không hợp lệ.');
    }

    final config = AppConfig(
      firebaseProjectId: projectId,
      serviceAccountPath: read('GOOGLE_APPLICATION_CREDENTIALS'),
      zaloAppId: appId,
      zaloSecretKey: secret,
      zaloSeedAccessToken: read('ZALO_ACCESS_TOKEN'),
      zaloSeedRefreshToken: refresh,
      znsMode: mode ?? ZnsMode.development,
      templateIds: templateIds,
      otpPepper: pepper,
      smtpHost: read('SMTP_HOST') ?? 'smtp.gmail.com',
      smtpPort: smtpPort ?? 587,
      smtpUsername: smtpUser,
      smtpPassword: smtpPassword,
      mailFromName: read('MAIL_FROM_NAME') ?? 'An ninh trường học',
      allowSelfRegistration: readBool('ALLOW_SELF_REGISTRATION', fallback: true),
      bootstrapAdminEmails: readEmails('BOOTSTRAP_ADMIN_EMAILS').toSet(),
      dutyGuardPhones: readPhones('DUTY_GUARD_PHONES'),
      dutyHotline: hotlineRaw,
      campusName: read('CAMPUS_NAME') ?? 'Trường Đại học',
      defaultBuildings: defaultBuildings,
      trustProxy: readBool('TRUST_PROXY', fallback: false),
      warnings: warnings,
    );
    if (problems.isNotEmpty) throw ConfigException(problems);
    return config;
  }

  /// Đọc danh sách khu vực mặc định từ `config/campus.json`.
  static List<String> loadDefaultBuildings([String path = 'config/campus.json']) {
    final file = File(path);
    if (!file.existsSync()) return const [];
    final json = jsonDecode(file.readAsStringSync());
    if (json is! Map || json['buildings'] is! List) return const [];
    return (json['buildings'] as List).whereType<String>().toList();
  }
}
