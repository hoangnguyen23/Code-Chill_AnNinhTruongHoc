import 'dart:async';
import 'dart:io';

import 'package:campus_core/campus_core.dart';

import '../data/models.dart';
import '../data/repositories.dart';
import 'notification_gateway.dart';
import 'push_service.dart';
import 'zalo/zalo_templates.dart';

/// Kết quả thông báo khi có báo cáo mới, trả về cho app hiển thị ngay.
class ReportCreatedSummary {
  const ReportCreatedSummary({
    required this.reporterConfirmation,
    required this.guardsTotal,
    required this.guardsAlerted,
    required this.guardFailures,
    required this.pushDelivered,
    this.pending = false,
  });

  final SendResult? reporterConfirmation;
  final int guardsTotal;
  final int guardsAlerted;
  final List<SendResult> guardFailures;
  final int pushDelivered;

  /// Quá thời gian chờ: tin vẫn đang được gửi ở nền và sẽ có trong nhật ký.
  final bool pending;

  Map<String, Object?> toJson() => {
    'reporterConfirmation': reporterConfirmation?.toJson(),
    'guardsTotal': guardsTotal,
    'guardsAlerted': guardsAlerted,
    'guardFailures': guardFailures
        .map((r) => {'recipient': r.recipientMasked, 'message': r.userMessage, 'errorCode': r.errorCode})
        .toList(),
    'pushDelivered': pushDelivered,
    'pending': pending,
  };
}

/// Điều phối thông báo theo sự kiện nghiệp vụ: Zalo (qua [NotificationGateway]) song song FCM.
///
/// Các phương thức KHÔNG ném lỗi: chúng chạy sau khi dữ liệu đã được lưu, nên lỗi gửi tin
/// không được làm API báo thất bại (người dùng sẽ gửi lại và tạo báo cáo trùng).
class NotificationService {
  NotificationService({
    required NotificationGateway gateway,
    required PushService push,
    required UserRepository users,
    required List<VietnamPhone> extraDutyPhones,
    this.waitLimit = const Duration(seconds: 20),
  }) : _gateway = gateway,
       _push = push,
       _users = users,
       _extraDutyPhones = extraDutyPhones;

  final NotificationGateway _gateway;
  final PushService _push;
  final UserRepository _users;
  final List<VietnamPhone> _extraDutyPhones;
  final Duration waitLimit;

  /// Zalo chưa cấu hình: chỉ gửi push, không tạo kết quả Zalo thất bại cho người dùng xem.
  bool get _zaloOn => _gateway.mode != 'off';

  Future<ReportCreatedSummary> reportCreated(ReportRecord report, ReporterPrivate reporter) async {
    final createdText = formatVietnamDateTime(report.createdAt);
    // Không đọc được danh sách bảo vệ vẫn phải gửi xác nhận cho người báo và báo số trực trong .env.
    final staff = await _safe(_users.listStaff, const <UserRecord>[], 'đọc danh sách bảo vệ');

    // Người báo chưa nhập số điện thoại thì không có tin Zalo xác nhận (vẫn thấy kết quả trong app).
    final reporterPhone = _zaloOn ? reporter.phone : null;
    final confirmation = reporterPhone == null
        ? Future<SendResult?>.value()
        : _gateway.send(
            TemplateMessage(
              recipient: reporterPhone,
              template: ZaloTemplateKey.reportReceived,
              purpose: NotificationPurpose.reportReceived,
              reportId: report.id,
              data: {
                'customer_name': reporter.displayName.isEmpty ? 'Bạn' : reporter.displayName,
                'report_code': report.code,
                'incident_type': report.type.label,
                'location': report.locationText,
                'created_time': createdText,
              },
            ),
          );

    // Bảo vệ đang trực trong app + số trực cố định trong .env, bỏ trùng và bỏ chính người báo.
    final recipients = <VietnamPhone, String>{};
    for (final g in staff.where((u) => _zaloOn && u.role == UserRole.guard && u.onDuty)) {
      final phone = g.phone;
      if (phone != null) recipients[phone] = g.profileComplete ? g.displayName : 'Bảo vệ trực';
    }
    for (final p in _zaloOn ? _extraDutyPhones : const <VietnamPhone>[]) {
      recipients.putIfAbsent(p, () => 'Bảo vệ trực');
    }
    recipients.remove(reporter.phone);

    final alerts = [
      for (final entry in recipients.entries)
        _gateway.send(
          TemplateMessage(
            recipient: entry.key,
            template: ZaloTemplateKey.guardAlert,
            purpose: NotificationPurpose.guardAlert,
            reportId: report.id,
            data: {
              'guard_name': entry.value,
              'report_code': report.code,
              'incident_type': report.type.label,
              'severity': report.severity.label,
              'location': report.locationText,
              'reported_time': createdText,
            },
          ),
        ),
    ];

    final push = _pushToUsers(
      staff.where((u) => u.uid != reporter.uid).toList(),
      PushMessage(
        title: report.emergency ? 'KHẨN CẤP: ${report.type.label}' : 'Sự cố mới: ${report.type.label}',
        body: '${report.code}, ${report.locationText}',
        data: {'type': 'report', 'reportId': report.id},
        urgent: true,
      ),
    );

    try {
      final results = await Future.wait<SendResult?>([confirmation, ...alerts]).timeout(waitLimit);
      final delivered = await push.timeout(const Duration(seconds: 5), onTimeout: () => 0);
      final guardResults = results.skip(1).whereType<SendResult>().toList();
      return ReportCreatedSummary(
        reporterConfirmation: results.first,
        guardsTotal: guardResults.length,
        guardsAlerted: guardResults.where((r) => r.success).length,
        guardFailures: guardResults.where((r) => !r.success).toList(),
        pushDelivered: delivered,
      );
    } on TimeoutException {
      return ReportCreatedSummary(
        reporterConfirmation: null,
        guardsTotal: recipients.length,
        guardsAlerted: 0,
        guardFailures: const [],
        pushDelivered: 0,
        pending: true,
      );
    }
  }

  /// Báo trạng thái mới cho người báo qua Zalo và push.
  Future<SendResult?> statusChanged(ReportRecord report, ReporterPrivate reporter, {String? note}) async {
    final reporterUser = await _safe(() => _users.byId(reporter.uid), null, 'đọc hồ sơ người báo');
    unawaited(
      _pushToUsers(
        [?reporterUser],
        PushMessage(
          title: 'Báo cáo ${report.code}: ${report.status.label}',
          body: (note == null || note.isEmpty) ? 'Bấm để xem chi tiết xử lý.' : note,
          data: {'type': 'report', 'reportId': report.id},
        ),
      ),
    );
    final reporterPhone = _zaloOn ? reporter.phone : null;
    if (reporterPhone == null) return null;
    try {
      return await _gateway
          .send(
            TemplateMessage(
              recipient: reporterPhone,
              template: ZaloTemplateKey.statusUpdate,
              purpose: NotificationPurpose.statusUpdate,
              reportId: report.id,
              data: {
                'customer_name': reporter.displayName.isEmpty ? 'Bạn' : reporter.displayName,
                'report_code': report.code,
                'status': report.status.label,
                'updated_time': formatVietnamDateTime(report.updatedAt),
              },
            ),
          )
          .timeout(waitLimit);
    } on TimeoutException {
      return null;
    }
  }

  Future<void> assigned(ReportRecord report, UserRecord assignee) => _pushToUsers(
    [assignee],
    PushMessage(
      title: 'Bạn được giao xử lý ${report.code}',
      body: '${report.type.label}, ${report.locationText}',
      data: {'type': 'report', 'reportId': report.id},
      urgent: report.severity.rank >= Severity.high.rank,
    ),
  );

  /// Có trao đổi mới: báo cho phía còn lại.
  Future<void> commentAdded(
    ReportRecord report,
    ReporterPrivate reporter, {
    required String authorUid,
    required bool byReporter,
    required String text,
  }) async {
    final List<UserRecord> targets;
    if (byReporter) {
      final staff = await _safe(_users.listStaff, const <UserRecord>[], 'đọc danh sách bảo vệ');
      targets = report.assigneeUid != null
          ? staff.where((u) => u.uid == report.assigneeUid).toList()
          : staff.where((u) => u.role == UserRole.guard && u.onDuty).toList();
    } else {
      targets = [?await _safe(() => _users.byId(reporter.uid), null, 'đọc hồ sơ người báo')];
    }
    await _pushToUsers(
      targets.where((u) => u.uid != authorUid).toList(),
      PushMessage(
        title: 'Trao đổi mới về ${report.code}',
        body: text.length > 120 ? '${text.substring(0, 119)}…' : text,
        data: {'type': 'report', 'reportId': report.id},
      ),
    );
  }

  /// Push tới mọi tài khoản đang hoạt động (cảnh báo toàn trường). Trả về số thiết bị nhận.
  Future<int> pushToAll(PushMessage message) async {
    final users = await _safe(_users.listActive, const <UserRecord>[], 'đọc danh sách tài khoản');
    return _pushToUsers(users, message);
  }

  /// Push tới một số tài khoản cụ thể (ví dụ người đang dùng "Đi cùng tôi").
  Future<int> pushTo(List<UserRecord> users, PushMessage message) => _pushToUsers(users, message);

  static Future<T> _safe<T>(Future<T> Function() run, T fallback, String what) async {
    try {
      return await run();
    } on Object catch (e) {
      stderr.writeln('[notify] Không $what: $e');
      return fallback;
    }
  }

  /// Gửi push và dọn token hết hiệu lực. Trả về số thiết bị nhận thành công.
  Future<int> _pushToUsers(List<UserRecord> users, PushMessage message) async {
    final owner = <String, String>{};
    for (final u in users) {
      for (final t in u.fcmTokens) {
        owner[t] = u.uid;
      }
    }
    if (owner.isEmpty) return 0;
    try {
      final result = await _push.sendToTokens(owner.keys.toList(), message);
      for (final token in result.invalidTokens) {
        final uid = owner[token];
        if (uid != null) await _users.removeFcmToken(uid, token);
      }
      return result.successCount;
    } on Object catch (e) {
      stderr.writeln('[fcm] Lỗi gửi push: $e');
      return 0;
    }
  }
}
