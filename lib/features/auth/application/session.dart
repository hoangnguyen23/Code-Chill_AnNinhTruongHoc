import 'package:campus_core/campus_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/polling.dart';
import '../data/backend_auth_repository.dart';
import '../domain/app_user.dart';
import '../domain/auth_repository.dart';
import '../../../core/notifications/push_notifications.dart';

/// Trạng thái phiên dùng cho điều hướng.
sealed class Session {
  const Session();
}

class SessionLoading extends Session {
  const SessionLoading();
}

class SessionSignedOut extends Session {
  const SessionSignedOut();
}

class SessionReady extends Session {
  const SessionReady(this.user);

  final AppUser user;
}

/// Đã đăng nhập nhưng tài khoản bị khoá hoặc không tìm thấy hồ sơ.
class SessionBlocked extends Session {
  const SessionBlocked(this.message);

  final String message;
}

/// Hồ sơ người đang đăng nhập, tải từ backend và làm mới định kỳ.
final currentUserProvider = StreamProvider<AppUser?>((ref) {
  final authUser = ref.watch(authStateProvider).value;
  if (authUser == null) return Stream.value(null);
  return pollApi<AppUser?>(
    ref.watch(apiClientProvider),
    '/me',
    (j) => AppUser.fromApi((j['user']! as Map).cast<String, Object?>()),
    every: const Duration(seconds: 15),
  );
});

final sessionProvider = Provider<Session>((ref) {
  final auth = ref.watch(authStateProvider);
  if (!auth.hasValue) return const SessionLoading();
  if (auth.value == null) return const SessionSignedOut();
  final profile = ref.watch(currentUserProvider);
  // Backend từ chối (403) tức là quản trị vừa khoá tài khoản.
  if (profile.error case ApiError(statusCode: 403)) {
    return const SessionBlocked('Tài khoản đã bị khoá. Liên hệ quản trị để được hỗ trợ.');
  }
  if (profile.hasError && !profile.hasValue) {
    return const SessionBlocked('Không tải được hồ sơ. Kiểm tra mạng hoặc đăng nhập lại.');
  }
  if (!profile.hasValue) return const SessionLoading();
  final user = profile.value;
  if (user == null) {
    return const SessionBlocked(
      'Tài khoản không còn tồn tại (có thể đã bị quản trị xoá). Hãy đăng xuất rồi đăng ký lại.',
    );
  }
  if (!user.active) return const SessionBlocked('Tài khoản đã bị khoá. Liên hệ quản trị để được hỗ trợ.');
  return SessionReady(user);
});

/// Người dùng hiện tại (chỉ dùng trong màn đã đăng nhập).
final signedInUserProvider = Provider<AppUser?>((ref) {
  final s = ref.watch(sessionProvider);
  return s is SessionReady ? s.user : null;
});

final currentRoleProvider = Provider<UserRole?>((ref) => ref.watch(signedInUserProvider)?.role);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final push = ref.watch(pushNotificationsProvider);
  return BackendAuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(firebaseAuthProvider),
    beforeSignOut: push.unregister,
  );
});
