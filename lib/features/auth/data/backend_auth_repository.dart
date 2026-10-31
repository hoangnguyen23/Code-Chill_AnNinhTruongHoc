import 'package:campus_core/campus_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../domain/app_user.dart';
import '../domain/auth_repository.dart';

class BackendAuthRepository implements AuthRepository {
  BackendAuthRepository(this._api, this._auth, {this.beforeSignOut});

  final ApiClient _api;
  final FirebaseAuth _auth;

  /// Gọi trước khi đăng xuất (huỷ đăng ký push).
  final Future<void> Function()? beforeSignOut;

  @override
  Future<AppUser> login(String username, String password) async {
    final res = await _api.post('/auth/login', {'username': username.trim(), 'password': password}, false);
    return _signIn(res);
  }

  @override
  Future<OtpChallengeInfo> requestRegistration(RegistrationDraft draft) async {
    final res = await _api.post(
      '/auth/register/request',
      {
        'email': draft.email.trim(),
        'username': draft.username.trim(),
        'password': draft.password,
        'displayName': draft.displayName.trim(),
        'memberType': draft.memberType.wire,
      },
      false,
    );
    return OtpChallengeInfo(
      email: (res['email'] as String?) ?? draft.email.trim(),
      emailMasked: (res['emailMasked'] as String?) ?? draft.email.trim(),
      expiresIn: Duration(seconds: (res['expiresInSeconds'] as int?) ?? OtpPolicy.ttl.inSeconds),
      resendAfter: Duration(seconds: (res['resendAfterSeconds'] as int?) ?? OtpPolicy.resendCooldown.inSeconds),
      mode: (res['mode'] as String?) ?? 'email',
      draft: draft,
    );
  }

  @override
  Future<AppUser> verifyRegistration(String email, String code) async {
    final res = await _api.post('/auth/register/verify', {'email': email, 'code': code}, false);
    return _signIn(res);
  }

  @override
  Future<OtpChallengeInfo> requestPasswordReset(String email) async {
    final res = await _api.post('/auth/password/forgot', {'email': email.trim()}, false);
    return OtpChallengeInfo(
      email: (res['email'] as String?) ?? email.trim(),
      emailMasked: (res['emailMasked'] as String?) ?? email.trim(),
      expiresIn: Duration(seconds: (res['expiresInSeconds'] as int?) ?? OtpPolicy.ttl.inSeconds),
      resendAfter: Duration(seconds: (res['resendAfterSeconds'] as int?) ?? OtpPolicy.resendCooldown.inSeconds),
      mode: (res['mode'] as String?) ?? 'email',
    );
  }

  @override
  Future<AppUser> resetPassword(String email, String code, String newPassword) async {
    final res = await _api.post(
      '/auth/password/reset',
      {'email': email, 'code': code, 'password': newPassword},
      false,
    );
    return _signIn(res);
  }

  @override
  Future<void> changePassword(String currentPassword, String newPassword) async {
    await _api.post('/me/password', {'currentPassword': currentPassword, 'newPassword': newPassword});
  }

  /// Đăng nhập Firebase bằng custom token backend vừa cấp.
  Future<AppUser> _signIn(Map<String, Object?> res) async {
    final token = res['customToken'] as String?;
    final user = res['user'];
    if (token == null || user is! Map<String, Object?>) throw ApiError.unexpected();
    try {
      await _auth.signInWithCustomToken(token);
    } on FirebaseAuthException catch (e) {
      throw ApiError(
        code: 'firebase_auth',
        message: e.code == 'network-request-failed'
            ? 'Không kết nối được Firebase. Kiểm tra mạng rồi thử lại.'
            : 'Không đăng nhập được Firebase (${e.code}). Kiểm tra cấu hình Firebase của app và backend.',
      );
    }
    return AppUser.fromApi(user);
  }

  @override
  Future<AppUser> updateProfile({String? displayName, String? phone, MemberType? memberType, bool? onDuty}) async {
    final res = await _api.patch('/me', {
      'displayName': ?displayName,
      'phone': ?phone,
      if (memberType != null) 'memberType': memberType.wire,
      'onDuty': ?onDuty,
    });
    return AppUser.fromApi(res['user']! as Map<String, Object?>);
  }

  @override
  Future<void> signOut() async {
    try {
      await beforeSignOut?.call();
    } on Object {
      // Không chặn đăng xuất nếu huỷ đăng ký push thất bại (ví dụ đang mất mạng).
    }
    await _auth.signOut();
  }
}
