import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'core/notifications/push_notifications.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } on Object catch (e) {
    runApp(FirebaseSetupErrorApp(error: e));
    return;
  }

  // Tắt tự thử lại của Riverpod 3: màn hình có nút "Thử lại" rõ ràng.
  final container = ProviderContainer(retry: (_, _) => null);
  try {
    await container.read(pushNotificationsProvider).initialize();
  } on Object catch (e) {
    debugPrint('Không khởi tạo được thông báo: $e');
  }

  runApp(UncontrolledProviderScope(container: container, child: const CampusSafetyApp()));
}

/// Hiện khi chưa chạy `flutterfire configure` (xem README, mục "Cấu hình Firebase").
class FirebaseSetupErrorApp extends StatelessWidget {
  const FirebaseSetupErrorApp({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('vi')],
      locale: const Locale('vi'),
      home: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          return Scaffold(
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Icon(Icons.settings_suggest_rounded, size: 48, color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text('Chưa cấu hình Firebase', style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  Text(
                    'Chạy lệnh sau ở thư mục dự án rồi khởi động lại ứng dụng:',
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const SelectableText('flutterfire configure --platforms=android'),
                  ),
                  const SizedBox(height: 16),
                  Text('Chi tiết lỗi: $error', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
