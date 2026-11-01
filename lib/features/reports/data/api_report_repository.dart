import 'package:campus_core/campus_core.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/polling.dart';
import '../domain/report.dart';
import '../domain/report_repository.dart';

class ApiReportRepository implements ReportRepository {
  ApiReportRepository(this._api);

  final ApiClient _api;

  Stream<List<Report>> _reports(String query) => pollApi(_api, '/reports?$query', (j) => _list(j).map(Report.fromJson).toList());

  static List<Map<String, dynamic>> _list(Map<String, Object?> j) =>
      ((j['reports'] as List?) ?? const []).whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();

  @override
  Stream<List<ReportSummary>> watchMyReports() => pollApi(
        _api,
        '/reports?scope=mine',
        (j) => _list(j).map((m) => ReportSummary.fromMap(m['id'] as String, m)).toList(),
      );

  @override
  Stream<ReportDetail> watchDetail(String id) => pollApi(_api, '/reports/$id', ReportDetail.fromJson);

  @override
  Stream<List<Report>> watchOpenReports() => _reports('scope=open');

  @override
  Stream<List<Report>> watchReportsSince(DateTime from) =>
      _reports('scope=since&from=${Uri.encodeQueryComponent(from.toUtc().toIso8601String())}');

  @override
  Stream<List<Report>> watchAssignedToMe() => _reports('scope=assigned');

  @override
  Future<SubmitReportResult> submit(ReportDraft draft) async =>
      SubmitReportResult.fromJson(await _api.post('/reports', draft.toJson()));

  @override
  Future<void> changeStatus(String id, ReportStatus to, {String? note}) async {
    await _api.post('/reports/$id/status', {
      'status': to.wire,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
  }

  @override
  Future<void> assign(String id, String assigneeUid) async {
    await _api.post('/reports/$id/assign', {'assigneeUid': assigneeUid});
  }

  @override
  Future<void> comment(String id, String text) async {
    await _api.post('/reports/$id/comments', {'text': text.trim()});
  }
}
