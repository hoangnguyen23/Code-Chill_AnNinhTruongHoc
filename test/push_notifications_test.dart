import 'package:campus_safety/core/config/server_url.dart';
import 'package:campus_safety/core/firebase/firebase_providers.dart';
import 'package:campus_safety/core/notifications/push_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeMessaging extends Fake implements FirebaseMessaging {}

class _FakeAuth extends Fake implements FirebaseAuth {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('đổi địa chỉ máy chủ không làm mất bộ lắng nghe thông báo đã khởi tạo', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(overrides: [
      messagingProvider.overrideWithValue(_FakeMessaging()),
      firebaseAuthProvider.overrideWithValue(_FakeAuth()),
    ]);
    addTearDown(container.dispose);

    final push = container.read(pushNotificationsProvider);
    final keepAlive = container.listen(pushNotificationsProvider, (_, _) {});
    addTearDown(keepAlive.close);

    await container.read(serverUrlProvider.notifier).set('http://192.168.1.20:8080');
    await container.pump();

    expect(container.read(pushNotificationsProvider), same(push));
  });
}
