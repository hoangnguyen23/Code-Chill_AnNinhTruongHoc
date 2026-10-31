import 'package:campus_safety_backend/backend.dart';
import 'package:dart_frog/dart_frog.dart';

/// GET / : kiểm tra backend còn sống (dùng cho health check khi deploy).
Response onRequest(RequestContext context) {
  final services = context.read<AppServices>();
  return Response.json(body: {
    'ok': true,
    'service': 'campus_safety_backend',
    'zaloMode': services.gateway.mode,
  });
}
