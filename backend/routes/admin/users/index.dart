import 'dart:io';

import 'package:campus_core/campus_core.dart';
import 'package:campus_safety_backend/backend.dart';
import 'package:dart_frog/dart_frog.dart';

/// POST /admin/users {email, phone?, displayName, role, memberType?, onDuty?} : tạo trước tài khoản
/// (bảo vệ, quản trị, hoặc người báo khi tắt tự đăng ký). Danh sách tài khoản app đọc thẳng
/// từ Firestore (Rules chỉ cho quản trị đọc).
Future<Response> onRequest(RequestContext context) async {
  ensureMethod(context, {HttpMethod.post});
  final services = context.read<AppServices>();
  final body = await readJsonObject(context.request);

  final EmailAddress email;
  try {
    email = EmailAddress.parse(requireString(body, 'email', label: 'email', maxLength: 254));
  } on EmailFormatException catch (e) {
    throw ApiException.validation({'email': e.message});
  }
  final phone = readOptionalPhone(body);
  final name = requireString(body, 'displayName', label: 'họ tên', maxLength: ProfileLimits.maxNameLength);
  final nameError = ProfileLimits.validateDisplayName(name);
  if (nameError != null) throw ApiException.validation({'displayName': nameError});
  final role = UserRole.tryFromWire(requireString(body, 'role', label: 'vai trò', maxLength: 20));
  if (role == null) throw ApiException.validation({'role': 'Vai trò không hợp lệ.'});
  final memberType = MemberType.tryFromWire(optionalString(body, 'memberType', maxLength: 20)) ??
      (role.isStaff ? MemberType.staff : MemberType.other);

  try {
    final user = await services.users.create(
      email: email,
      phone: phone,
      displayName: name,
      role: role,
      memberType: memberType,
      onDuty: optionalBool(body, 'onDuty') ?? false,
    );
    return Response.json(statusCode: HttpStatus.created, body: {'user': user.toApiJson()});
  } on StateError {
    throw ApiException.conflict('Email ${email.value} đã có tài khoản.', code: 'email_exists');
  }
}
