import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/state_views.dart';
import '../../campus/hotline_button.dart';
import '../application/session.dart';

/// Đã đăng nhập nhưng tài khoản bị khoá hoặc không tải được hồ sơ.
class BlockedScreen extends ConsumerWidget {
  const BlockedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final message = session is SessionBlocked ? session.message : 'Không truy cập được tài khoản.';
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Expanded(
                child: EmptyState(
                  icon: Icons.lock_outline_rounded,
                  title: 'Không vào được ứng dụng',
                  message: message,
                  action: Column(
                    children: [
                      OutlinedButton(
                        onPressed: () => ref.invalidate(currentUserProvider),
                        child: const Text('Thử lại'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => ref.read(authRepositoryProvider).signOut(),
                        child: const Text('Đăng xuất'),
                      ),
                    ],
                  ),
                ),
              ),
              const HotlineButton(),
            ],
          ),
        ),
      ),
    );
  }
}
