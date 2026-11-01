import 'package:campus_core/campus_core.dart';

import 'report.dart';

/// Đọc và ghi báo cáo qua backend. Các luồng `watch` tự làm mới định kỳ.
abstract interface class ReportRepository {
  Stream<List<ReportSummary>> watchMyReports();

  /// Báo cáo, lịch sử và người báo thật (chỉ quản trị, hoặc chính người báo).
  Stream<ReportDetail> watchDetail(String id);

  /// Báo cáo chưa đóng (Đã gửi / Đã tiếp nhận / Đang xử lý).
  Stream<List<Report>> watchOpenReports();

  /// Báo cáo tạo từ [from] tới nay, mới nhất trước.
  Stream<List<Report>> watchReportsSince(DateTime from);

  Stream<List<Report>> watchAssignedToMe();

  Future<SubmitReportResult> submit(ReportDraft draft);

  Future<void> changeStatus(String id, ReportStatus to, {String? note});

  Future<void> assign(String id, String assigneeUid);

  Future<void> comment(String id, String text);
}
