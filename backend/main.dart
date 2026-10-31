import 'dart:io';

import 'package:campus_safety_backend/backend.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:dotenv/dotenv.dart';

/// Chạy một lần khi khởi động: đọc .env, kiểm tra cấu hình, kết nối Firebase Admin, mail và Zalo.
Future<void> init(InternetAddress ip, int port) async {
  final fileEnv = DotEnv(quiet: true);
  if (File('.env').existsSync()) fileEnv.load(['.env']);
  // Biến môi trường của hệ thống (Cloud Run, Docker) ưu tiên hơn file .env.
  final env = <String, String>{
    for (final key in AppConfig.knownKeys)
      if ((Platform.environment[key] ?? fileEnv[key]) case final String value) key: value,
  };

  final AppConfig config;
  try {
    config = AppConfig.fromEnvironment(env, defaultBuildings: AppConfig.loadDefaultBuildings());
  } on ConfigException catch (e) {
    stderr.writeln(e);
    stderr.writeln('Sao chép backend/.env.example thành backend/.env và điền đủ các giá trị trên.');
    exit(78); // EX_CONFIG
  }
  for (final w in config.warnings) {
    stderr.writeln('[cảnh báo] $w');
  }

  final services = AppServices.production(config);
  AppServices.instance = services;
  services.zaloTokens?.startAutoRefresh();
  services.walks.startOverdueTimer();
  stdout.writeln('[campus_safety] OTP gửi qua email ${config.smtpUsername} (${config.smtpHost}:${config.smtpPort}).');
  stdout.writeln(config.zaloEnabled
      ? '[campus_safety] Zalo ZNS mode: ${config.znsMode.name}. '
          'Template đã cấu hình: ${config.templateIds.length}/${ZaloTemplateKey.values.length - 1}.'
      : '[campus_safety] Zalo: tắt.');
}

Future<HttpServer> run(Handler handler, InternetAddress ip, int port) {
  return serve(handler, ip, port);
}
