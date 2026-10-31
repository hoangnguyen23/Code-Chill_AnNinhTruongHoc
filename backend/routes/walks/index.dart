import 'dart:io';

import 'package:campus_safety_backend/backend.dart';
import 'package:dart_frog/dart_frog.dart';

/// POST /walks {destination, minutes, latitude?, longitude?, accuracy?} : bắt đầu "Đi cùng tôi".
/// Lượt đang đi app đọc thẳng từ Firestore `walks` (chính chủ và bảo vệ/quản trị).
Future<Response> onRequest(RequestContext context) async {
  ensureMethod(context, {HttpMethod.post});
  final services = context.read<AppServices>();
  final body = await readJsonObject(context.request);
  services.limits.check(services.limits.walks, context.read<UserRecord>().uid, 'bắt đầu Đi cùng tôi');
  final walk = await services.walks.start(
    context.read<UserRecord>(),
    destination: requireString(body, 'destination', label: 'nơi đến', maxLength: 200),
    minutes: optionalInt(body, 'minutes') ?? 15,
    latitude: optionalDouble(body, 'latitude'),
    longitude: optionalDouble(body, 'longitude'),
    accuracy: optionalDouble(body, 'accuracy'),
  );
  return Response.json(statusCode: HttpStatus.created, body: {'walk': walk.toApiJson()});
}
