import 'package:campus_core/campus_core.dart';

import 'report.dart';

/// Đọc báo cáo theo thời gian thực từ Firestore; ghi qua backend.
abstract interface class ReportRepository {
  Stream<List<ReportSummary>> watchMyReports(String uid);

  Stream<Report?> watchReport(String id);

  Stream<List<ReportEventItem>> watchEvents(String id);

  /// Người báo thật (quản trị, hoặc chính người báo).
  Stream<ReporterContact?> watchReporterContact(String id);

  /// Báo cáo chưa đóng (Đã gửi / Đã tiếp nhận / Đang xử lý).
  Stream<List<Report>> watchOpenReports();

  /// Báo cáo tạo từ [from] tới nay, mới nhất trước.
  Stream<List<Report>> watchReportsSince(DateTime from);

  Stream<List<Report>> watchAssignedTo(String uid);

  Future<SubmitReportResult> submit(ReportDraft draft);

  /// Trả về kết quả gửi Zalo cho người báo (nếu có).
  Future<ZaloDelivery?> changeStatus(String id, ReportStatus to, {String? note});

  Future<ZaloDelivery?> assign(String id, String assigneeUid);

  Future<void> comment(String id, String text);
}
