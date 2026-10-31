import 'package:campus_core/campus_core.dart';
import 'package:campus_safety_backend/backend.dart';
import 'package:dart_frog/dart_frog.dart';

/// POST /admin/zalo/test_send {phone, template, data} : quản trị gửi THẬT một tin Zalo để thử.
/// Kết quả (thành công hoặc lỗi tiếng Việt) trả về ngay và được ghi vào nhật ký gửi tin.
Future<Response> onRequest(RequestContext context) async {
  ensureMethod(context, {HttpMethod.post});
  final services = context.read<AppServices>();
  final admin = context.read<UserRecord>();
  final body = await readJsonObject(context.request);

  final VietnamPhone phone;
  try {
    phone = VietnamPhone.parse(requireString(body, 'phone', label: 'số điện thoại', maxLength: 30));
  } on PhoneFormatException catch (e) {
    throw ApiException.validation({'phone': e.message});
  }
  final template = ZaloTemplateKey.tryFromWire(requireString(body, 'template', label: 'template', maxLength: 40));
  if (template == null) throw ApiException.validation({'template': 'Template không hợp lệ.'});

  final rawData = body['data'];
  final data = <String, String>{};
  if (rawData is Map) {
    for (final p in template.params) {
      final v = rawData[p.name];
      if (v != null) data[p.name] = '$v';
    }
  }

  final result = await services.gateway.send(TemplateMessage(
    recipient: phone,
    template: template,
    data: data,
    purpose: NotificationPurpose.test,
    actorUid: admin.uid,
  ));
  return Response.json(body: {'result': result.toJson()});
}
