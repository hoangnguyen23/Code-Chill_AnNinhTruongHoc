import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/server_url.dart';
import '../network/api_client.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);


final messagingProvider = Provider<FirebaseMessaging>((ref) => FirebaseMessaging.instance);

/// Trạng thái đăng nhập Firebase Auth (custom token do backend cấp sau khi xác thực OTP).
final authStateProvider = StreamProvider<User?>((ref) => ref.watch(firebaseAuthProvider).authStateChanges());

final apiClientProvider = Provider<ApiClient>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return ApiClient(
    baseUrl: ref.watch(serverUrlProvider),
    idToken: () async => auth.currentUser?.getIdToken(),
  );
});
