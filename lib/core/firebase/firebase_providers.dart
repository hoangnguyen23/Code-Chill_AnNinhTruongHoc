import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/server_url.dart';
import '../network/api_client.dart';
import '../network/api_error.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

final messagingProvider = Provider<FirebaseMessaging>((ref) => FirebaseMessaging.instance);

/// Trạng thái đăng nhập Firebase Auth (custom token do backend cấp sau khi xác thực OTP).
final authStateProvider = StreamProvider<User?>((ref) => ref.watch(firebaseAuthProvider).authStateChanges());

final apiClientProvider = Provider<ApiClient>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return ApiClient(
    baseUrl: ref.watch(serverUrlProvider),
    idToken: () async {
      try {
        return await auth.currentUser?.getIdToken();
      } on FirebaseAuthException catch (e) {
        if (e.code == 'network-request-failed') throw ApiError.network();
        // Phiên đã bị thu hồi hoặc tài khoản đã xoá: về màn đăng nhập.
        await auth.signOut();
        return null;
      }
    },
    onSessionExpired: auth.signOut,
  );
});
