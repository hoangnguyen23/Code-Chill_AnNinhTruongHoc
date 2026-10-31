import 'package:campus_core/campus_core.dart';
import 'package:dart_firebase_admin/firestore.dart';

import '../notifications/send_log.dart';
import '../notifications/zalo/zalo_token_manager.dart';
import 'models.dart';
import 'repositories.dart';

/// Tên collection, khớp với `firebase/firestore.rules` và app Flutter.
abstract final class Collections {
  static const users = 'users';
  static const emailIndex = 'email_index';
  static const usernameIndex = 'username_index';
  static const credentials = 'credentials';
  static const reports = 'reports';
  static const events = 'events';
  static const private = 'private';
  static const userReports = 'reports';
  static const config = 'config';
  static const otp = 'otp_challenges';
  static const zaloLogs = 'zalo_logs';
  static const system = 'system';
  static const broadcasts = 'broadcasts';
  static const walks = 'walks';
  static const reportImages = 'report_images';
}

DateTime? readDate(Object? v) => switch (v) {
      final Timestamp t =>
        DateTime.fromMicrosecondsSinceEpoch(t.seconds * 1000000 + t.nanoseconds ~/ 1000, isUtc: true),
      final DateTime d => d.toUtc(),
      final String s => DateTime.tryParse(s)?.toUtc(),
      _ => null,
    };

double? readDouble(Object? v) => v is num ? v.toDouble() : null;

String? readString(Object? v) => v is String && v.isNotEmpty ? v : null;

List<String> readStringList(Object? v) => v is List ? v.whereType<String>().toList() : const [];

class FirestoreUserRepository implements UserRepository {
  FirestoreUserRepository(this._db, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final Firestore _db;
  final DateTime Function() _clock;

  CollectionReference<DocumentData> get _users => _db.collection(Collections.users);

  static UserRecord? fromDoc(DocumentSnapshot<DocumentData> doc) {
    final d = doc.data();
    if (!doc.exists || d == null) return null;
    final email = EmailAddress.tryParse(d['email'] as String?);
    if (email == null) return null;
    return UserRecord(
      uid: doc.id,
      email: email,
      phone: VietnamPhone.tryParse(d['phone'] as String?),
      username: readString(d['username']),
      displayName: (d['displayName'] as String?) ?? '',
      role: UserRole.fromWire(d['role'] as String?),
      memberType: MemberType.fromWire(d['memberType'] as String?),
      active: d['active'] != false,
      onDuty: d['onDuty'] == true,
      fcmTokens: readStringList(d['fcmTokens']),
      createdAt: readDate(d['createdAt']),
      updatedAt: readDate(d['updatedAt']),
      lastLoginAt: readDate(d['lastLoginAt']),
    );
  }

  static Map<String, Object?> toDoc(UserRecord u) => {
        'email': u.email.value,
        'username': u.username,
        'phone': u.phone?.international,
        'phoneLocal': u.phone?.local,
        'displayName': u.displayName,
        'role': u.role.wire,
        'memberType': u.memberType.wire,
        'active': u.active,
        'onDuty': u.onDuty,
        'fcmTokens': u.fcmTokens,
        'createdAt': u.createdAt,
        'updatedAt': u.updatedAt,
        'lastLoginAt': u.lastLoginAt,
      };

  DocumentReference<DocumentData> _emailIndex(EmailAddress email) =>
      _db.doc('${Collections.emailIndex}/${email.value}');

  @override
  Future<UserRecord?> byId(String uid) async => fromDoc(await _users.doc(uid).get());

  @override
  Future<UserRecord?> byEmail(EmailAddress email) async {
    final idx = await _emailIndex(email).get();
    final uid = idx.data()?['uid'];
    if (uid is! String) return null;
    return byId(uid);
  }

  @override
  Future<(UserRecord, bool)> getOrCreate(EmailAddress email, {required UserRole role}) {
    return _db.runTransaction((tx) async {
      final idxRef = _emailIndex(email);
      final idx = await tx.get(idxRef);
      final existingUid = idx.data()?['uid'];
      if (existingUid is String) {
        final existing = fromDoc(await tx.get(_users.doc(existingUid)));
        if (existing != null) return (existing, false);
      }
      final now = _clock().toUtc();
      final ref = _users.doc();
      final user = UserRecord(
        uid: ref.id,
        email: email,
        displayName: '',
        role: role,
        memberType: MemberType.other,
        active: true,
        onDuty: false,
        createdAt: now,
        updatedAt: now,
      );
      tx.set(ref, toDoc(user));
      tx.set(idxRef, {'uid': ref.id, 'createdAt': now});
      return (user, true);
    });
  }

  @override
  Future<UserRecord> create({
    required EmailAddress email,
    required String displayName,
    required UserRole role,
    required MemberType memberType,
    VietnamPhone? phone,
    bool onDuty = false,
  }) {
    return _db.runTransaction((tx) async {
      final idxRef = _emailIndex(email);
      final idx = await tx.get(idxRef);
      if (idx.exists) throw StateError('email_exists');
      final now = _clock().toUtc();
      final ref = _users.doc();
      final user = UserRecord(
        uid: ref.id,
        email: email,
        phone: phone,
        displayName: displayName,
        role: role,
        memberType: memberType,
        active: true,
        onDuty: onDuty && role.isStaff,
        createdAt: now,
        updatedAt: now,
      );
      tx.set(ref, toDoc(user));
      tx.set(idxRef, {'uid': ref.id, 'createdAt': now});
      return user;
    });
  }

  @override
  Future<UserRecord> update(
    String uid, {
    String? displayName,
    VietnamPhone? phone,
    bool clearPhone = false,
    String? username,
    MemberType? memberType,
    UserRole? role,
    bool? active,
    bool? onDuty,
    DateTime? lastLoginAt,
  }) async {
    final now = _clock().toUtc();
    await _users.doc(uid).update({
      'displayName': ?displayName,
      if (clearPhone) ...{'phone': null, 'phoneLocal': null},
      if (phone != null) ...{'phone': phone.international, 'phoneLocal': phone.local},
      'username': ?username,
      if (memberType != null) 'memberType': memberType.wire,
      if (role != null) 'role': role.wire,
      'active': ?active,
      'onDuty': ?onDuty,
      if (lastLoginAt != null) 'lastLoginAt': lastLoginAt.toUtc(),
      'updatedAt': now,
    });
    final updated = await byId(uid);
    if (updated == null) throw StateError('user_not_found');
    return updated;
  }

  /// Giữ tối đa [maxFcmTokens] thiết bị gần nhất để danh sách không phình vô hạn.
  static const maxFcmTokens = 10;

  @override
  Future<void> addFcmToken(String uid, String token) {
    return _db.runTransaction((tx) async {
      final ref = _users.doc(uid);
      final current = readStringList((await tx.get(ref)).data()?['fcmTokens']);
      final next = [...current.where((t) => t != token), token];
      tx.update(ref, {
        'fcmTokens': next.length > maxFcmTokens ? next.sublist(next.length - maxFcmTokens) : next,
        'updatedAt': _clock().toUtc(),
      });
    });
  }

  @override
  Future<void> removeFcmToken(String uid, String token) async {
    await _users.doc(uid).update({'fcmTokens': FieldValue.arrayRemove([token])});
  }

  @override
  Future<void> delete(String uid) async {
    final user = await byId(uid);
    final mine = await _users.doc(uid).collection(Collections.userReports).get();
    for (final d in mine.docs) {
      await d.ref.delete();
    }
    if (user != null) await _db.doc('${Collections.emailIndex}/${user.email.value}').delete();
    await _users.doc(uid).delete();
  }

  @override
  Future<List<UserRecord>> listActive() async {
    final snap = await _users.where('active', WhereFilter.equal, true).get();
    return snap.docs.map(fromDoc).whereType<UserRecord>().toList();
  }

  @override
  Future<List<UserRecord>> listStaff() async {
    final snap = await _users
        .where('role', WhereFilter.isIn, [UserRole.guard.wire, UserRole.admin.wire])
        .get();
    return snap.docs.map(fromDoc).whereType<UserRecord>().where((u) => u.active).toList();
  }
}

class FirestoreReportRepository implements ReportRepository {
  FirestoreReportRepository(this._db);

  final Firestore _db;

  DocumentReference<DocumentData> _report(String id) => _db.doc('${Collections.reports}/$id');

  DocumentReference<DocumentData> _private(String id) =>
      _db.doc('${Collections.reports}/$id/${Collections.private}/reporter');

  DocumentReference<DocumentData> _userIndex(String uid, String reportId) =>
      _db.doc('${Collections.users}/$uid/${Collections.userReports}/$reportId');

  static Map<String, Object?> toDoc(ReportRecord r) => {
        'code': r.code,
        'type': r.type.wire,
        'severity': r.severity.wire,
        'severityRank': r.severity.rank,
        'status': r.status.wire,
        'description': r.description,
        'occurredAt': r.occurredAt.toUtc(),
        'createdAt': r.createdAt.toUtc(),
        'updatedAt': r.updatedAt.toUtc(),
        'emergency': r.emergency,
        'anonymous': r.anonymous,
        'building': r.building,
        'floor': r.floor,
        'room': r.room,
        'locationText': r.locationText,
        'latitude': r.latitude,
        'longitude': r.longitude,
        'accuracyMeters': r.accuracyMeters,
        'reporterUid': r.anonymous ? null : r.reporterUid,
        'reporterName': r.anonymous ? null : r.reporterName,
        'reporterPhone': r.anonymous ? null : r.reporterPhone,
        'reporterMemberType': r.anonymous ? null : r.reporterMemberType?.wire,
        'imagePaths': r.imagePaths,
        'assigneeUid': r.assigneeUid,
        'assigneeName': r.assigneeName,
        'lastNote': r.lastNote,
        'closedAt': r.closedAt?.toUtc(),
      };

  /// Bản tóm tắt cho danh sách "Báo cáo của tôi" (`users/{uid}/reports/{id}`).
  static Map<String, Object?> toIndexDoc(ReportRecord r) => {
        'code': r.code,
        'type': r.type.wire,
        'severity': r.severity.wire,
        'status': r.status.wire,
        'emergency': r.emergency,
        'anonymous': r.anonymous,
        'locationText': r.locationText,
        'createdAt': r.createdAt.toUtc(),
        'updatedAt': r.updatedAt.toUtc(),
      };

  static Map<String, Object?> eventDoc(ReportEvent e) => {
        'type': e.type.wire,
        'createdAt': e.createdAt.toUtc(),
        'actorUid': e.actorUid,
        'actorName': e.actorName,
        'actorRole': e.actorRole.wire,
        'fromStatus': e.fromStatus?.wire,
        'toStatus': e.toStatus?.wire,
        'note': e.note,
      };

  static ReportRecord? fromDoc(DocumentSnapshot<DocumentData> doc) {
    final d = doc.data();
    if (!doc.exists || d == null) return null;
    final now = DateTime.now().toUtc();
    return ReportRecord(
      id: doc.id,
      code: (d['code'] as String?) ?? doc.id,
      type: IncidentType.fromWire(d['type'] as String?),
      severity: Severity.fromWire(d['severity'] as String?),
      status: ReportStatus.fromWire(d['status'] as String?),
      description: (d['description'] as String?) ?? '',
      occurredAt: readDate(d['occurredAt']) ?? now,
      createdAt: readDate(d['createdAt']) ?? now,
      updatedAt: readDate(d['updatedAt']) ?? now,
      emergency: d['emergency'] == true,
      anonymous: d['anonymous'] == true,
      building: readString(d['building']),
      floor: readString(d['floor']),
      room: readString(d['room']),
      latitude: readDouble(d['latitude']),
      longitude: readDouble(d['longitude']),
      accuracyMeters: readDouble(d['accuracyMeters']),
      reporterUid: readString(d['reporterUid']),
      reporterName: readString(d['reporterName']),
      reporterPhone: readString(d['reporterPhone']),
      reporterMemberType: MemberType.tryFromWire(d['reporterMemberType'] as String?),
      imagePaths: readStringList(d['imagePaths']),
      assigneeUid: readString(d['assigneeUid']),
      assigneeName: readString(d['assigneeName']),
      lastNote: readString(d['lastNote']),
      closedAt: readDate(d['closedAt']),
    );
  }

  static ReporterPrivate? privateFromDoc(DocumentSnapshot<DocumentData> doc) {
    final d = doc.data();
    if (!doc.exists || d == null) return null;
    final uid = d['uid'];
    if (uid is! String) return null;
    return ReporterPrivate(
      uid: uid,
      email: EmailAddress.tryParse(d['email'] as String?),
      phone: VietnamPhone.tryParse(d['phone'] as String?),
      displayName: (d['displayName'] as String?) ?? '',
    );
  }

  static Map<String, Object?> privateDoc(ReporterPrivate p) => {
        'uid': p.uid,
        'email': p.email?.value,
        'phone': p.phone?.international,
        'phoneLocal': p.phone?.local,
        'displayName': p.displayName,
      };

  @override
  Future<void> create(ReportRecord report, ReporterPrivate reporter, ReportEvent createdEvent) {
    return _db.runTransaction((tx) async {
      tx.create(_report(report.id), toDoc(report));
      tx.set(_private(report.id), privateDoc(reporter));
      tx.set(_userIndex(reporter.uid, report.id), toIndexDoc(report));
      tx.set(_report(report.id).collection(Collections.events).doc(), eventDoc(createdEvent));
    });
  }

  @override
  Future<ReportRecord?> byId(String id) async => fromDoc(await _report(id).get());

  @override
  Future<ReporterPrivate?> reporterOf(String id) async => privateFromDoc(await _private(id).get());

  @override
  Future<(ReportRecord, ReporterPrivate)> mutate(
    String id,
    (ReportRecord, ReportEvent?) Function(ReportRecord current, ReporterPrivate reporter) apply,
  ) {
    return _db.runTransaction((tx) async {
      final current = fromDoc(await tx.get(_report(id)));
      final reporter = privateFromDoc(await tx.get(_private(id)));
      if (current == null || reporter == null) throw StateError('report_not_found');
      final (next, event) = apply(current, reporter);
      tx.set(_report(id), toDoc(next));
      tx.set(_userIndex(reporter.uid, id), toIndexDoc(next));
      if (event != null) {
        tx.set(_report(id).collection(Collections.events).doc(), eventDoc(event));
      }
      return (next, reporter);
    });
  }

  @override
  Future<void> addEvent(String reportId, ReportEvent event) async {
    await _report(reportId).collection(Collections.events).add(eventDoc(event));
    await _report(reportId).update({'updatedAt': event.createdAt.toUtc()});
  }

  @override
  String newId() => _db.collection(Collections.reports).doc().id;
}

class FirestoreCredentialRepository implements CredentialRepository {
  FirestoreCredentialRepository(this._db);

  final Firestore _db;

  DocumentReference<DocumentData> _cred(String uid) => _db.doc('${Collections.credentials}/$uid');

  DocumentReference<DocumentData> _index(String username) => _db.doc('${Collections.usernameIndex}/$username');

  static StoredCredential? _from(String uid, Map<String, Object?>? d) {
    if (d == null) return null;
    final username = readString(d['username']);
    final hash = readString(d['passwordHash']);
    if (username == null || hash == null) return null;
    return StoredCredential(
      uid: uid,
      username: username,
      passwordHash: hash,
      failedAttempts: (d['failedAttempts'] as num?)?.toInt() ?? 0,
      lockedUntil: readDate(d['lockedUntil']),
    );
  }

  @override
  Future<StoredCredential?> byUid(String uid) async {
    final snap = await _cred(uid).get();
    return snap.exists ? _from(uid, snap.data()) : null;
  }

  @override
  Future<StoredCredential?> byUsername(String username) async {
    final uid = (await _index(username).get()).data()?['uid'];
    return uid is String ? byUid(uid) : null;
  }

  @override
  Future<bool> usernameTaken(String username) async => (await _index(username).get()).exists;

  @override
  Future<void> create(String uid, {required String username, required String passwordHash}) {
    return _db.runTransaction((tx) async {
      if ((await tx.get(_index(username))).exists) throw StateError('username_taken');
      if ((await tx.get(_cred(uid))).exists) throw StateError('credential_exists');
      final now = DateTime.now().toUtc();
      tx.set(_index(username), {'uid': uid, 'createdAt': now});
      tx.set(_cred(uid), {
        'username': username,
        'passwordHash': passwordHash,
        'failedAttempts': 0,
        'lockedUntil': null,
        'createdAt': now,
      });
    });
  }

  @override
  Future<void> recordFailure(String uid, {required int attempts, DateTime? lockedUntil}) async {
    await _cred(uid).update({'failedAttempts': attempts, 'lockedUntil': lockedUntil?.toUtc()});
  }

  @override
  Future<void> resetFailures(String uid) async {
    await _cred(uid).update({'failedAttempts': 0, 'lockedUntil': null});
  }

  @override
  Future<void> updatePassword(String uid, String passwordHash) async {
    await _cred(uid).update({
      'passwordHash': passwordHash,
      'failedAttempts': 0,
      'lockedUntil': null,
      'passwordChangedAt': DateTime.now().toUtc(),
    });
  }

  @override
  Future<void> delete(String uid) async {
    final cred = await byUid(uid);
    if (cred != null) await _index(cred.username).delete();
    await _cred(uid).delete();
  }
}

class FirestoreOtpStore implements OtpStore {
  FirestoreOtpStore(this._db);

  final Firestore _db;

  DocumentReference<DocumentData> _ref(String key) => _db.doc('${Collections.otp}/$key');

  static OtpChallenge? fromData(Map<String, Object?>? d) {
    if (d == null) return null;
    return OtpChallenge(
      codeHash: readString(d['codeHash']),
      salt: readString(d['salt']),
      expiresAt: readDate(d['expiresAt']),
      attempts: (d['attempts'] as num?)?.toInt() ?? 0,
      sendTimes: (d['sendTimes'] is List)
          ? (d['sendTimes'] as List).map(readDate).whereType<DateTime>().toList()
          : const [],
      pending: (d['pending'] is Map)
          ? {
              for (final e in (d['pending'] as Map).entries)
                if (e.key is String && e.value is String) e.key as String: e.value as String,
            }
          : const {},
    );
  }

  static Map<String, Object?> toData(OtpChallenge c) => {
        'codeHash': c.codeHash,
        'salt': c.salt,
        'expiresAt': c.expiresAt?.toUtc(),
        'attempts': c.attempts,
        'sendTimes': c.sendTimes.map((t) => t.toUtc()).toList(),
        'pending': c.pending,
      };

  @override
  Future<OtpChallenge?> read(String key) async {
    final snap = await _ref(key).get();
    return snap.exists ? fromData(snap.data()) : null;
  }

  @override
  Future<OtpChallenge> update(String key, OtpChallenge Function(OtpChallenge? current) mutate) {
    return _db.runTransaction((tx) async {
      final snap = await tx.get(_ref(key));
      final next = mutate(snap.exists ? fromData(snap.data()) : null);
      tx.set(_ref(key), toData(next));
      return next;
    });
  }
}

class FirestoreConfigRepository implements ConfigRepository {
  FirestoreConfigRepository(this._db);

  final Firestore _db;

  DocumentReference<DocumentData> get _ref => _db.doc('${Collections.config}/app');

  @override
  Future<CampusConfig?> read() async {
    final snap = await _ref.get();
    final d = snap.data();
    if (!snap.exists || d == null) return null;
    return CampusConfig(
      campusName: (d['campusName'] as String?) ?? '',
      hotline: readString(d['hotline']),
      buildings: readStringList(d['buildings']),
      updatedAt: readDate(d['updatedAt']),
    );
  }

  @override
  Future<CampusConfig> write(CampusConfig config) async {
    await _ref.set({
      'campusName': config.campusName,
      'hotline': config.hotline,
      'buildings': config.buildings,
      'updatedAt': (config.updatedAt ?? DateTime.now()).toUtc(),
    });
    return config;
  }
}

class FirestoreSendLogRepository implements SendLogRepository {
  FirestoreSendLogRepository(this._db);

  final Firestore _db;

  @override
  Future<void> add(SendLogEntry entry) async {
    await _db.collection(Collections.zaloLogs).add(entry.toFirestore());
  }
}

class FirestoreZaloTokenStore implements ZaloTokenStore {
  FirestoreZaloTokenStore(this._db);

  final Firestore _db;

  DocumentReference<DocumentData> get _ref => _db.doc('${Collections.system}/zalo_oauth');

  @override
  Future<ZaloTokenState?> read() async {
    final snap = await _ref.get();
    final d = snap.data();
    if (!snap.exists || d == null) return null;
    final expires = readDate(d['accessTokenExpiresAt']);
    final updated = readDate(d['updatedAt']);
    final refresh = readString(d['refreshToken']);
    if (expires == null || updated == null || refresh == null) return null;
    return ZaloTokenState(
      accessToken: (d['accessToken'] as String?) ?? '',
      refreshToken: refresh,
      accessTokenExpiresAt: expires,
      updatedAt: updated,
      seedFingerprint: (d['seedFingerprint'] as String?) ?? '',
      lastError: readString(d['lastError']),
      lastErrorAt: readDate(d['lastErrorAt']),
      lastRefreshAt: readDate(d['lastRefreshAt']),
    );
  }

  @override
  Future<void> write(ZaloTokenState state) async {
    await _ref.set({
      'accessToken': state.accessToken,
      'refreshToken': state.refreshToken,
      'accessTokenExpiresAt': state.accessTokenExpiresAt.toUtc(),
      'updatedAt': state.updatedAt.toUtc(),
      'seedFingerprint': state.seedFingerprint,
      'lastError': state.lastError,
      'lastErrorAt': state.lastErrorAt?.toUtc(),
      'lastRefreshAt': state.lastRefreshAt?.toUtc(),
    });
  }
}
