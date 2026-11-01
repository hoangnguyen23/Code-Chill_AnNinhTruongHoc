import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/firebase/firebase_providers.dart';
import '../../core/network/api_client.dart';

/// Cấu hình trường công khai (`GET /config`): tên trường, số trực, danh sách khu vực.
class CampusInfo {
  const CampusInfo({
    required this.campusName,
    required this.hotline,
    required this.buildings,
  });

  factory CampusInfo.fromJson(Map<String, Object?> j) => CampusInfo(
        campusName: (j['campusName'] as String?) ?? '',
        hotline: j['hotline'] as String?,
        buildings: (j['buildings'] as List?)?.whereType<String>().toList() ?? const [],
      );

  final String campusName;
  final String? hotline;
  final List<String> buildings;

  bool get hasHotline => hotline != null && hotline!.trim().isNotEmpty;
}

abstract interface class CampusRepository {
  Future<CampusInfo> load();
}

class BackendCampusRepository implements CampusRepository {
  BackendCampusRepository(this._api);

  final ApiClient _api;

  @override
  Future<CampusInfo> load() async => CampusInfo.fromJson(await _api.get('/config', auth: false));
}

final campusRepositoryProvider = Provider<CampusRepository>(
  (ref) => BackendCampusRepository(ref.watch(apiClientProvider)),
);

final campusInfoProvider = FutureProvider<CampusInfo>((ref) => ref.watch(campusRepositoryProvider).load());

/// Gọi số trực an ninh bằng trình quay số của máy.
Future<bool> callHotline(String number) {
  final digits = number.replaceAll(RegExp(r'[^0-9+]'), '');
  return launchUrl(Uri(scheme: 'tel', path: digits));
}
