import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase/firebase_providers.dart';
import '../../core/network/api_client.dart';
import '../../core/services/location_service.dart';
import '../auth/application/session.dart';

enum WalkStatus {
  active('active', 'Đang đi'),
  arrived('arrived', 'Đã tới nơi'),
  cancelled('cancelled', 'Đã huỷ'),
  overdue('overdue', 'Quá giờ, đã báo bảo vệ'),
  sos('sos', 'Đã bấm khẩn cấp');

  const WalkStatus(this.wire, this.label);

  final String wire;
  final String label;

  static WalkStatus fromWire(String? wire) =>
      values.where((v) => v.wire == wire).firstOrNull ?? WalkStatus.cancelled;
}

/// Một lượt "Đi cùng tôi" (Firestore `walks/{id}`). Backend tự báo bảo vệ khi quá [dueAt].
class Walk {
  const Walk({
    required this.id,
    required this.uid,
    required this.displayName,
    required this.destination,
    required this.startedAt,
    required this.dueAt,
    required this.status,
    this.phone,
    this.latitude,
    this.longitude,
    this.locationAt,
    this.reportId,
  });

  factory Walk.fromMap(String id, Map<String, dynamic> d) => Walk(
        id: id,
        uid: (d['uid'] as String?) ?? '',
        displayName: (d['displayName'] as String?) ?? '',
        phone: d['phone'] as String?,
        destination: (d['destination'] as String?) ?? '',
        startedAt: _date(d['startedAt']) ?? DateTime.now(),
        dueAt: _date(d['dueAt']) ?? DateTime.now(),
        status: WalkStatus.fromWire(d['status'] as String?),
        latitude: (d['lastLatitude'] as num?)?.toDouble(),
        longitude: (d['lastLongitude'] as num?)?.toDouble(),
        locationAt: _date(d['lastLocationAt']),
        reportId: d['reportId'] as String?,
      );

  final String id;
  final String uid;
  final String displayName;
  final String? phone;
  final String destination;
  final DateTime startedAt;
  final DateTime dueAt;
  final WalkStatus status;
  final double? latitude;
  final double? longitude;
  final DateTime? locationAt;
  final String? reportId;

  bool get hasLocation => latitude != null && longitude != null;

  /// Còn bao lâu tới giờ hẹn (âm nghĩa là đã quá giờ, backend sắp báo bảo vệ).
  Duration remaining(DateTime now) => dueAt.difference(now);

  static DateTime? _date(Object? v) => v is Timestamp ? v.toDate() : null;
}

class WalkRepository {
  WalkRepository(this._db, this._api);

  final FirebaseFirestore _db;
  final ApiClient _api;

  CollectionReference<Map<String, dynamic>> get _walks => _db.collection('walks');

  List<Walk> _map(QuerySnapshot<Map<String, dynamic>> s) => s.docs.map((d) => Walk.fromMap(d.id, d.data())).toList();

  /// Lượt đang đi của chính mình.
  Stream<Walk?> watchMyActive(String uid) => _walks
      .where('uid', isEqualTo: uid)
      .where('status', isEqualTo: WalkStatus.active.wire)
      .limit(1)
      .snapshots()
      .map((s) => _map(s).firstOrNull);

  /// Mọi lượt đang đi (bảo vệ, quản trị).
  Stream<List<Walk>> watchAllActive() =>
      _walks.where('status', isEqualTo: WalkStatus.active.wire).snapshots().map(_map);

  Future<void> start({required String destination, required int minutes, LocationFix? at}) => _api.post('/walks', {
        'destination': destination.trim(),
        'minutes': minutes,
        ...?_coords(at),
      });

  Future<void> sendLocation(String id, LocationFix at) => _api.post('/walks/$id/location', _coords(at));

  Future<void> arrive(String id) => _api.post('/walks/$id/arrive');

  Future<void> cancel(String id) => _api.post('/walks/$id/cancel');

  Future<void> extend(String id, int minutes) => _api.post('/walks/$id/extend', {'minutes': minutes});

  /// Trả về ID báo cáo khẩn cấp vừa tạo.
  Future<String?> sos(String id, LocationFix? at) async {
    final res = await _api.post('/walks/$id/sos', _coords(at) ?? const {});
    return (res['walk'] as Map?)?['reportId'] as String?;
  }

  static Map<String, Object?>? _coords(LocationFix? at) => at == null
      ? null
      : {'latitude': at.latitude, 'longitude': at.longitude, 'accuracy': at.accuracyMeters};
}

final walkRepositoryProvider = Provider<WalkRepository>(
  (ref) => WalkRepository(ref.watch(firestoreProvider), ref.watch(apiClientProvider)),
);

final myActiveWalkProvider = StreamProvider<Walk?>((ref) {
  final uid = ref.watch(signedInUserProvider)?.uid;
  if (uid == null) return Stream.value(null);
  return ref.watch(walkRepositoryProvider).watchMyActive(uid);
});

final activeWalksProvider = StreamProvider.autoDispose<List<Walk>>(
  (ref) => ref.watch(walkRepositoryProvider).watchAllActive(),
);
