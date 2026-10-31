import 'package:campus_core/campus_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/network/api_client.dart';
import '../domain/report.dart';
import '../domain/report_repository.dart';

class FirestoreReportRepository implements ReportRepository {
  FirestoreReportRepository(this._db, this._api);

  final FirebaseFirestore _db;
  final ApiClient _api;

  static const _limit = 300;

  CollectionReference<Map<String, dynamic>> get _reports => _db.collection('reports');

  List<Report> _map(QuerySnapshot<Map<String, dynamic>> s) =>
      s.docs.map((d) => Report.fromMap(d.id, d.data())).toList();

  @override
  Stream<List<ReportSummary>> watchMyReports(String uid) => _db
      .collection('users/$uid/reports')
      .orderBy('createdAt', descending: true)
      .limit(_limit)
      .snapshots()
      .map((s) => s.docs.map((d) => ReportSummary.fromMap(d.id, d.data())).toList());

  @override
  Stream<Report?> watchReport(String id) =>
      _reports.doc(id).snapshots().map((s) => s.exists ? Report.fromMap(s.id, s.data()!) : null);

  @override
  Stream<List<ReportEventItem>> watchEvents(String id) => _reports
      .doc(id)
      .collection('events')
      .orderBy('createdAt')
      .snapshots()
      .map((s) => s.docs.map((d) => ReportEventItem.fromMap(d.id, d.data())).toList());

  @override
  Stream<ReporterContact?> watchReporterContact(String id) => _reports
      .doc(id)
      .collection('private')
      .doc('reporter')
      .snapshots()
      .map((s) => s.exists ? ReporterContact.fromMap(s.data()!) : null);

  @override
  Stream<List<Report>> watchOpenReports() => _reports
      .where('status', whereIn: [
        ReportStatus.submitted.wire,
        ReportStatus.received.wire,
        ReportStatus.inProgress.wire,
      ])
      .orderBy('createdAt', descending: true)
      .limit(_limit)
      .snapshots()
      .map(_map);

  @override
  Stream<List<Report>> watchReportsSince(DateTime from) => _reports
      .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
      .orderBy('createdAt', descending: true)
      .limit(1000)
      .snapshots()
      .map(_map);

  @override
  Stream<List<Report>> watchAssignedTo(String uid) => _reports
      .where('assigneeUid', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .limit(_limit)
      .snapshots()
      .map(_map);

  @override
  Future<SubmitReportResult> submit(ReportDraft draft) async =>
      SubmitReportResult.fromJson(await _api.post('/reports', draft.toJson()));

  @override
  Future<ZaloDelivery?> changeStatus(String id, ReportStatus to, {String? note}) async {
    final res = await _api.post('/reports/$id/status', {
      'status': to.wire,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
    return _delivery(res);
  }

  @override
  Future<ZaloDelivery?> assign(String id, String assigneeUid) async =>
      _delivery(await _api.post('/reports/$id/assign', {'assigneeUid': assigneeUid}));

  @override
  Future<void> comment(String id, String text) async {
    await _api.post('/reports/$id/comments', {'text': text.trim()});
  }

  ZaloDelivery? _delivery(Map<String, Object?> res) {
    final n = res['reporterNotification'];
    return n is Map ? ZaloDelivery.fromJson(n.cast<String, Object?>()) : null;
  }
}
