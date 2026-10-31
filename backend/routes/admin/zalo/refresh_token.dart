import 'package:campus_safety_backend/backend.dart';
import 'package:dart_frog/dart_frog.dart';

/// POST /admin/zalo/refresh_token : làm mới access token Zalo ngay (dùng để kiểm tra
/// refresh token còn sống). Không trả về token.
Future<Response> onRequest(RequestContext context) async {
  ensureMethod(context, {HttpMethod.post});
  final services = context.read<AppServices>();
  final zaloTokens = services.zaloTokens;
  if (zaloTokens == null) {
    throw ApiException(409, 'zalo_disabled', 'Backend chưa cấu hình Zalo (ZALO_APP_ID...) nên không có token để làm mới.');
  }
  try {
    final current = await zaloTokens.accessToken();
    await zaloTokens.forceRefresh(rejectedAccessToken: current);
  } on ZaloTokenException catch (e) {
    throw ApiException(502, 'zalo_token', e.info.message, details: {'detail': e.detail});
  }
  return Response.json(body: {'ok': true, 'token': await zaloTokens.status()});
}
