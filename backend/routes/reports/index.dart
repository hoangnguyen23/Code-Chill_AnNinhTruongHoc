import 'dart:io';

import 'package:campus_core/campus_core.dart';
import 'package:campus_safety_backend/backend.dart';
import 'package:dart_frog/dart_frog.dart';

/// POST /reports : gửi báo cáo (cả báo cáo thường và khẩn cấp với `emergency: true`).
///
/// Ghi báo cáo, gửi Zalo xác nhận cho người báo kèm mã sự cố, gửi Zalo cảnh báo tới bảo vệ trực
/// và push FCM tới bảo vệ/quản trị. Trả về kết quả gửi để app hiển thị ngay.
Future<Response> onRequest(RequestContext context) async {
  ensureMethod(context, {HttpMethod.post});
  final services = context.read<AppServices>();
  final user = context.read<UserRecord>();
  final body = await readJsonObject(context.request);
  services.limits.check(services.limits.reports, user.uid, 'gửi báo cáo');

  final ReportDraft draft;
  try {
    draft = ReportDraft.fromJson(body);
  } on FormatException catch (e) {
    final field = e.message;
    throw ApiException.validation({
      field: switch (field) {
        'type' => 'Chọn loại sự cố.',
        'severity' => 'Chọn mức độ khẩn cấp.',
        'occurredAt' => 'Thời gian xảy ra không hợp lệ.',
        _ => 'Dữ liệu báo cáo không hợp lệ.',
      },
    });
  } on TypeError {
    throw ApiException.badRequest('Dữ liệu báo cáo sai kiểu.');
  }

  final (report, summary) = await services.reportService.create(user, draft);
  return Response.json(
    statusCode: HttpStatus.created,
    body: {
      'report': report.toApiJson(),
      'notifications': summary.toJson(),
    },
  );
}
