import 'package:dart_firebase_admin/firestore.dart';

import '../safety/broadcast_service.dart';
import '../safety/walk_service.dart';
import 'firestore_repositories.dart';

/// Cảnh báo toàn trường (`broadcasts/{id}`).
class FirestoreBroadcastRepository implements BroadcastRepository {
  FirestoreBroadcastRepository(this._db);

  final Firestore _db;

  CollectionReference<DocumentData> get _col => _db.collection(Collections.broadcasts);

  @override
  String newId() => _col.doc().id;

  @override
  Future<void> create(BroadcastRecord r) async {
    await _col.doc(r.id).set({
      'title': r.title,
      'body': r.body,
      'level': r.level.wire,
      'active': r.active,
      'createdAt': r.createdAt.toUtc(),
      'expiresAt': r.expiresAt.toUtc(),
      'createdByUid': r.createdByUid,
      'createdByName': r.createdByName,
      'endedAt': null,
    });
  }

  @override
  Future<BroadcastRecord?> byId(String id) async {
    final snap = await _col.doc(id).get();
    final d = snap.data();
    if (!snap.exists || d == null) return null;
    return BroadcastRecord(
      id: snap.id,
      title: (d['title'] as String?) ?? '',
      body: (d['body'] as String?) ?? '',
      level: BroadcastLevel.tryFromWire(d['level'] as String?) ?? BroadcastLevel.info,
      createdAt: readDate(d['createdAt']) ?? DateTime.now().toUtc(),
      expiresAt: readDate(d['expiresAt']) ?? DateTime.now().toUtc(),
      createdByUid: (d['createdByUid'] as String?) ?? '',
      createdByName: (d['createdByName'] as String?) ?? '',
      active: d['active'] == true,
      endedAt: readDate(d['endedAt']),
    );
  }

  @override
  Future<void> end(String id, DateTime at) async {
    await _col.doc(id).update({'active': false, 'endedAt': at.toUtc()});
  }
}

/// Lượt "Đi cùng tôi" (`walks/{id}`).
class FirestoreWalkRepository implements WalkRepository {
  FirestoreWalkRepository(this._db);

  final Firestore _db;

  CollectionReference<DocumentData> get _col => _db.collection(Collections.walks);

  static WalkRecord? fromDoc(DocumentSnapshot<DocumentData> doc) {
    final d = doc.data();
    if (!doc.exists || d == null) return null;
    final uid = d['uid'];
    final started = readDate(d['startedAt']);
    final due = readDate(d['dueAt']);
    if (uid is! String || started == null || due == null) return null;
    return WalkRecord(
      id: doc.id,
      uid: uid,
      displayName: (d['displayName'] as String?) ?? '',
      phone: readString(d['phone']),
      destination: (d['destination'] as String?) ?? '',
      startedAt: started,
      dueAt: due,
      status: WalkStatus.fromWire(d['status'] as String?),
      updatedAt: readDate(d['updatedAt']) ?? started,
      lastLatitude: readDouble(d['lastLatitude']),
      lastLongitude: readDouble(d['lastLongitude']),
      lastAccuracy: readDouble(d['lastAccuracy']),
      lastLocationAt: readDate(d['lastLocationAt']),
      reportId: readString(d['reportId']),
      endedAt: readDate(d['endedAt']),
    );
  }

  static Map<String, Object?> toDoc(WalkRecord w) => {
        'uid': w.uid,
        'displayName': w.displayName,
        'phone': w.phone,
        'destination': w.destination,
        'startedAt': w.startedAt.toUtc(),
        'dueAt': w.dueAt.toUtc(),
        'status': w.status.wire,
        'updatedAt': w.updatedAt.toUtc(),
        'lastLatitude': w.lastLatitude,
        'lastLongitude': w.lastLongitude,
        'lastAccuracy': w.lastAccuracy,
        'lastLocationAt': w.lastLocationAt?.toUtc(),
        'reportId': w.reportId,
        'endedAt': w.endedAt?.toUtc(),
      };

  @override
  String newId() => _col.doc().id;

  @override
  Future<WalkRecord?> byId(String id) async => fromDoc(await _col.doc(id).get());

  @override
  Future<WalkRecord?> activeFor(String uid) async {
    final snap = await _col
        .where('uid', WhereFilter.equal, uid)
        .where('status', WhereFilter.equal, WalkStatus.active.wire)
        .limit(1)
        .get();
    return snap.docs.map(fromDoc).whereType<WalkRecord>().firstOrNull;
  }

  @override
  Future<List<WalkRecord>> listActive() async {
    final snap = await _col.where('status', WhereFilter.equal, WalkStatus.active.wire).get();
    return snap.docs.map(fromDoc).whereType<WalkRecord>().toList();
  }

  @override
  Future<void> save(WalkRecord walk) async {
    await _col.doc(walk.id).set(toDoc(walk));
  }

  @override
  Future<WalkRecord?> updateIfActive(String id, WalkRecord Function(WalkRecord current) update) {
    return _db.runTransaction((tx) async {
      final ref = _col.doc(id);
      final current = fromDoc(await tx.get(ref));
      if (current == null || !current.isActive) return null;
      final next = update(current);
      tx.set(ref, toDoc(next));
      return next;
    });
  }
}
