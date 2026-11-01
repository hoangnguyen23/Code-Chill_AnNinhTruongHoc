import 'package:campus_core/campus_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/firebase/firebase_providers.dart';
import '../../core/format/formatters.dart';
import '../../core/network/api_client.dart';
import '../../core/network/polling.dart';
import '../../core/theme/app_theme.dart';
import '../auth/application/session.dart';

enum BroadcastLevel {
  info('info', 'Thông báo', Icons.campaign_rounded),
  warning('warning', 'Cảnh báo', Icons.warning_amber_rounded),
  danger('danger', 'Nguy hiểm', Icons.crisis_alert_rounded);

  const BroadcastLevel(this.wire, this.label, this.icon);

  final String wire;
  final String label;
  final IconData icon;

  static BroadcastLevel fromWire(String? wire) =>
      values.where((v) => v.wire == wire).firstOrNull ?? BroadcastLevel.info;
}

/// Cảnh báo toàn trường, do quản trị gửi qua backend.
class Broadcast {
  const Broadcast({
    required this.id,
    required this.title,
    required this.body,
    required this.level,
    required this.createdAt,
    required this.expiresAt,
    required this.active,
    required this.createdByName,
  });

  factory Broadcast.fromJson(Map<String, dynamic> d) => Broadcast(
        id: d['id'] as String,
        title: (d['title'] as String?) ?? '',
        body: (d['body'] as String?) ?? '',
        level: BroadcastLevel.fromWire(d['level'] as String?),
        createdAt: _date(d['createdAt']) ?? DateTime.now(),
        expiresAt: _date(d['expiresAt']) ?? DateTime.now(),
        active: d['active'] == true,
        createdByName: (d['createdByName'] as String?) ?? '',
      );

  final String id;
  final String title;
  final String body;
  final BroadcastLevel level;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool active;
  final String createdByName;

  /// Còn hiển thị trên banner: chưa bị gỡ và chưa hết hạn.
  bool isLive(DateTime now) => active && expiresAt.isAfter(now);

  static DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;
}

class BroadcastRepository {
  BroadcastRepository(this._api);

  final ApiClient _api;

  /// 20 cảnh báo gần nhất (kể cả đã gỡ), mới nhất trước.
  Stream<List<Broadcast>> watchRecent() => pollApi(
        _api,
        '/broadcasts',
        (j) => [
          for (final b in ((j['broadcasts'] as List?) ?? const []).whereType<Map>()) Broadcast.fromJson(b.cast<String, dynamic>()),
        ],
      );

  /// Trả về số thiết bị đã nhận push.
  Future<int> send({required String title, required String body, required BroadcastLevel level, required int hours}) async {
    final res = await _api.post('/admin/broadcasts', {
      'title': title.trim(),
      'body': body.trim(),
      'level': level.wire,
      'hours': hours,
    });
    return (res['pushDelivered'] as int?) ?? 0;
  }

  Future<void> end(String id) => _api.post('/admin/broadcasts/$id/end');
}

final broadcastRepositoryProvider = Provider<BroadcastRepository>(
  (ref) => BroadcastRepository(ref.watch(apiClientProvider)),
);

final recentBroadcastsProvider = StreamProvider<List<Broadcast>>((ref) {
  if (ref.watch(signedInUserProvider.select((u) => u?.uid)) == null) return Stream.value(const []);
  return ref.watch(broadcastRepositoryProvider).watchRecent();
});

/// Cảnh báo đang hiệu lực, mới nhất trước.
final liveBroadcastsProvider = Provider<List<Broadcast>>((ref) {
  final now = DateTime.now();
  return (ref.watch(recentBroadcastsProvider).value ?? const []).where((b) => b.isLive(now)).toList();
});

/// Màu theo mức độ: nguy hiểm dùng tông đỏ khẩn cấp, cảnh báo dùng hổ phách, thông báo dùng màu phụ.
(Color, Color) broadcastColors(BuildContext context, BroadcastLevel level) {
  final palette = context.palette;
  final scheme = Theme.of(context).colorScheme;
  return switch (level) {
    BroadcastLevel.danger => (palette.emergencyContainer, palette.onEmergencyContainer),
    BroadcastLevel.warning => (palette.severityBackground[Severity.medium]!, palette.severityForeground[Severity.medium]!),
    BroadcastLevel.info => (scheme.secondaryContainer, scheme.onSecondaryContainer),
  };
}

/// Banner cảnh báo toàn trường, đặt đầu các màn chính. Không có cảnh báo thì không chiếm chỗ.
class BroadcastBanner extends ConsumerWidget {
  const BroadcastBanner({super.key, this.padding = EdgeInsets.zero});

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(liveBroadcastsProvider);
    if (live.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: padding,
      child: Column(
        children: [
          for (final b in live.take(2)) ...[
            BroadcastCard(broadcast: b),
            if (b != live.take(2).last) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class BroadcastCard extends StatelessWidget {
  const BroadcastCard({super.key, required this.broadcast, this.trailing});

  final Broadcast broadcast;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (bg, fg) = broadcastColors(context, broadcast.level);
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(broadcast.level.icon, color: fg, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${broadcast.level.label.toUpperCase()} · ${formatRelative(broadcast.createdAt)}',
                    style: theme.textTheme.labelMedium?.copyWith(color: fg),
                  ),
                  const SizedBox(height: 2),
                  Text(broadcast.title, style: theme.textTheme.titleMedium?.copyWith(color: fg)),
                  const SizedBox(height: 4),
                  Text(broadcast.body, style: theme.textTheme.bodyMedium?.copyWith(color: fg)),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
