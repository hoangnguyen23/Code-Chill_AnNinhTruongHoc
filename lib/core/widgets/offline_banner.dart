import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// `true` khi thiết bị không có kết nối mạng nào.
final offlineProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  bool offline(List<ConnectivityResult> r) => r.isEmpty || r.every((e) => e == ConnectivityResult.none);
  yield offline(await connectivity.checkConnectivity());
  yield* connectivity.onConnectivityChanged.map(offline);
});

/// Banner mỏng trên cùng khi mất mạng. Nút khẩn cấp vẫn mở được và gợi ý gọi trực.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(offlineProvider).value ?? false;
    final scheme = Theme.of(context).colorScheme;
    return AnimatedSize(
      duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 200),
      child: !offline
          ? const SizedBox(width: double.infinity)
          : Material(
              color: scheme.inverseSurface,
              child: SafeArea(
                bottom: false,
                child: Semantics(
                  liveRegion: true,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Icon(Icons.wifi_off_rounded, size: 18, color: scheme.onInverseSurface),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Mất kết nối mạng. Khi khẩn cấp, hãy gọi trực an ninh.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onInverseSurface),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
