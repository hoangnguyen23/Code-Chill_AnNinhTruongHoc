import 'package:campus_safety_backend/backend.dart';
import 'package:dart_frog/dart_frog.dart';

/// GET /admin/zalo/status : chế độ gửi, các template đã cấu hình (kèm tham số và dữ liệu mẫu)
/// và tình trạng access token. Không trả về token.
Future<Response> onRequest(RequestContext context) async {
  ensureMethod(context, {HttpMethod.get});
  final services = context.read<AppServices>();
  final zaloTokens = services.zaloTokens;
  Map<String, Object?> token;
  try {
    token = zaloTokens == null ? {'error': 'Backend chưa cấu hình Zalo (ZALO_APP_ID...).'} : await zaloTokens.status();
  } on Object catch (e) {
    token = {'error': 'Không đọc được trạng thái token: $e'};
  }
  return Response.json(body: {
    'mode': services.gateway.mode,
    'token': token,
    'warnings': services.config.warnings,
    'templates': [
      for (final key in ZaloTemplateKey.values)
        {
          'key': key.wire,
          'title': key.title,
          'envVar': key.envVar,
          'configured': services.gateway.isConfigured(key),
          'templateId': services.config.templateIds[key],
          'params': key.params.map((p) => p.toJson()).toList(),
        },
    ],
  });
}
