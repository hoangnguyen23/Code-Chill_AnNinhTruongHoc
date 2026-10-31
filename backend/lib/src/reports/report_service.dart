import 'package:campus_core/campus_core.dart';

import '../data/models.dart';
import '../data/repositories.dart';
import '../http/api_exception.dart';
import '../notifications/notification_gateway.dart';
import '../notifications/notification_service.dart';

/// Nghiệp vụ báo cáo sự cố. Mọi thao tác ghi đều đi qua đây để kiểm tra quyền, kiểm tra dữ
/// liệu và gửi thông báo nhất quán (client không được ghi trực tiếp vào Firestore).
class ReportService {
  ReportService({
    required ReportRepository reports,
    required UserRepository users,
    required NotificationService notifications,
    DateTime Function()? clock,
  })  : _reports = reports,
        _users = users,
        _notifications = notifications,
        _clock = clock ?? DateTime.now;

  final ReportRepository _reports;
  final UserRepository _users;
  final NotificationService _notifications;
  final DateTime Function() _clock;

  static const anonymousName = 'Người báo (ẩn danh)';

  Future<(ReportRecord, ReportCreatedSummary)> create(UserRecord actor, ReportDraft draft) async {
    if (!Permissions.canCreateReport(actor.actor)) throw ApiException.forbidden();
    final now = _clock().toUtc();
    final errors = validateReportDraft(draft, now: now);
    if (errors.isNotEmpty) throw ApiException.validation(errors);

    final description = draft.description.trim();
    final report = ReportRecord(
      id: _reports.newId(),
      code: generateReportCode(now: now),
      type: draft.type,
      severity: draft.effectiveSeverity,
      status: ReportStatus.submitted,
      description: description.isEmpty && draft.emergency ? 'Báo cáo khẩn cấp, chưa có mô tả.' : description,
      occurredAt: draft.occurredAt.toUtc(),
      createdAt: now,
      updatedAt: now,
      emergency: draft.emergency,
      anonymous: draft.anonymous,
      building: draft.building,
      floor: draft.floor,
      room: draft.room,
      latitude: draft.latitude,
      longitude: draft.longitude,
      accuracyMeters: draft.accuracyMeters,
      reporterUid: draft.anonymous ? null : actor.uid,
      reporterName: draft.anonymous ? null : (actor.profileComplete ? actor.displayName : null),
      reporterPhone: draft.anonymous ? null : actor.phone?.local,
      reporterMemberType: draft.anonymous ? null : actor.memberType,
      imagePaths: draft.imagePaths,
    );
    final reporter = ReporterPrivate(
      uid: actor.uid,
      email: actor.email,
      phone: actor.phone,
      displayName: actor.displayName,
    );
    await _reports.create(
      report,
      reporter,
      ReportEvent(
        type: ReportEventType.created,
        createdAt: now,
        actorUid: draft.anonymous ? null : actor.uid,
        actorName: draft.anonymous ? anonymousName : _nameOf(actor),
        // Ẩn danh thì không để lộ người báo là bảo vệ hay quản trị.
        actorRole: draft.anonymous ? UserRole.reporter : actor.role,
        toStatus: ReportStatus.submitted,
        note: draft.emergency ? 'Báo cáo khẩn cấp' : null,
      ),
    );
    final summary = await _notifications.reportCreated(report, reporter);
    return (report, summary);
  }

  Future<(ReportRecord, SendResult?)> changeStatus(
    UserRecord actor,
    String reportId, {
    required ReportStatus to,
    String? note,
  }) async {
    final trimmedNote = note?.trim();
    final now = _clock().toUtc();
    final (next, reporter) = await _mutate(reportId, (current, _) {
      if (!Permissions.canChangeStatus(actor.actor, assigneeUid: current.assigneeUid)) {
        throw ApiException.forbidden(
          'Báo cáo đang do ${current.assigneeName ?? 'người khác'} xử lý. Liên hệ quản trị nếu cần đổi.',
        );
      }
      final error = ReportStatusMachine.validate(
        from: current.status,
        to: to,
        role: actor.role,
        note: trimmedNote,
      );
      if (error != null) throw ApiException.conflict(error, code: 'invalid_transition');
      final selfAssign = actor.role == UserRole.guard &&
          current.assigneeUid == null &&
          (to == ReportStatus.received || to == ReportStatus.inProgress);
      final next = current.copyWith(
        status: to,
        updatedAt: now,
        assigneeUid: selfAssign ? actor.uid : null,
        assigneeName: selfAssign ? _nameOf(actor) : null,
        // Ghi chú gắn với trạng thái mới; đổi trạng thái không kèm ghi chú thì xoá ghi chú cũ.
        lastNote: (trimmedNote?.isNotEmpty ?? false) ? trimmedNote : null,
        clearLastNote: !(trimmedNote?.isNotEmpty ?? false),
        closedAt: to.isClosed ? now : null,
        clearClosedAt: !to.isClosed,
      );
      return (
        next,
        ReportEvent(
          type: ReportEventType.status,
          createdAt: now,
          actorUid: actor.uid,
          actorName: _nameOf(actor),
          actorRole: actor.role,
          fromStatus: current.status,
          toStatus: to,
          note: (trimmedNote?.isNotEmpty ?? false) ? trimmedNote : null,
        ),
      );
    });
    final zalo = await _notifications.statusChanged(next, reporter, note: trimmedNote);
    return (next, zalo);
  }

  /// Phân công. Nếu báo cáo còn "Đã gửi" thì chuyển sang "Đã tiếp nhận" và báo người báo.
  Future<(ReportRecord, SendResult?)> assign(UserRecord actor, String reportId, String targetUid) async {
    final target = await _users.byId(targetUid);
    if (target == null || !target.active || !target.role.isStaff) {
      throw ApiException.badRequest('Chỉ giao được cho bảo vệ hoặc quản trị đang hoạt động.');
    }
    final now = _clock().toUtc();
    var statusChanged = false;
    final (next, reporter) = await _mutate(reportId, (current, _) {
      if (!Permissions.canAssign(actor.actor, targetUid: targetUid, currentAssigneeUid: current.assigneeUid)) {
        throw ApiException.forbidden('Bạn chỉ tự nhận được báo cáo chưa có người xử lý.');
      }
      if (current.status.isClosed) {
        throw ApiException.conflict('Báo cáo đã đóng, không thể phân công.', code: 'report_closed');
      }
      if (current.assigneeUid == targetUid) {
        throw ApiException.conflict('Báo cáo đã được giao cho người này.', code: 'already_assigned');
      }
      statusChanged = current.status == ReportStatus.submitted;
      final newStatus = statusChanged ? ReportStatus.received : current.status;
      return (
        current.copyWith(
          status: newStatus,
          updatedAt: now,
          assigneeUid: target.uid,
          assigneeName: _nameOf(target),
        ),
        ReportEvent(
          type: ReportEventType.assigned,
          createdAt: now,
          actorUid: actor.uid,
          actorName: _nameOf(actor),
          actorRole: actor.role,
          fromStatus: statusChanged ? current.status : null,
          toStatus: statusChanged ? newStatus : null,
          note: actor.uid == target.uid ? '${_nameOf(target)} nhận xử lý' : 'Giao cho ${_nameOf(target)}',
        ),
      );
    });
    await _notifications.assigned(next, target);
    final zalo = statusChanged ? await _notifications.statusChanged(next, reporter) : null;
    return (next, zalo);
  }

  Future<void> comment(UserRecord actor, String reportId, String text) async {
    final report = await _reports.byId(reportId);
    final reporter = await _reports.reporterOf(reportId);
    if (report == null || reporter == null) throw ApiException.notFound('Không tìm thấy báo cáo.');
    final isOwner = reporter.uid == actor.uid;
    if (!Permissions.canComment(actor.actor, isOwner: isOwner)) throw ApiException.forbidden();
    final error = validateComment(text);
    if (error != null) throw ApiException.validation({'text': error});
    final hidden = isOwner && report.anonymous;
    final trimmed = text.trim();
    await _reports.addEvent(
      reportId,
      ReportEvent(
        type: ReportEventType.comment,
        createdAt: _clock().toUtc(),
        actorUid: hidden ? null : actor.uid,
        actorName: hidden ? anonymousName : _nameOf(actor),
        actorRole: isOwner ? UserRole.reporter : actor.role,
        note: trimmed,
      ),
    );
    await _notifications.commentAdded(
      report,
      reporter,
      authorUid: actor.uid,
      byReporter: isOwner && !actor.role.isStaff,
      text: trimmed,
    );
  }

  Future<(ReportRecord, ReporterPrivate)> _mutate(
    String id,
    (ReportRecord, ReportEvent?) Function(ReportRecord, ReporterPrivate) apply,
  ) async {
    try {
      return await _reports.mutate(id, apply);
    } on StateError {
      throw ApiException.notFound('Không tìm thấy báo cáo.');
    }
  }

  static String _nameOf(UserRecord u) =>
      u.profileComplete ? u.displayName : '${u.role.label} ${u.email.masked}';
}
