import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/auth/application/session.dart';
import '../widgets/offline_banner.dart';
import 'role_navigation.dart';

/// Khung chung: banner mất mạng + thanh điều hướng dưới theo vai trò.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentRoleProvider);
    if (role == null) return child;
    final destinations = destinationsFor(role);
    final index = destinations.indexWhere((d) => location.startsWith(d.path));
    final offline = ref.watch(offlineProvider).value ?? false;
    return Scaffold(
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            // Banner đã chiếm phần tai thỏ/thanh trạng thái nên bỏ padding trên của màn con.
            child: MediaQuery.removePadding(context: context, removeTop: offline, child: child),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index < 0 ? 0 : index,
        onDestinationSelected: (i) => context.go(destinations[i].path),
        destinations: [
          for (final d in destinations)
            NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: d.label),
        ],
      ),
    );
  }
}
