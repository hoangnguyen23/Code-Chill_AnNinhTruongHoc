import 'notification_gateway.dart';

/// Một dòng nhật ký gửi tin (collection `zalo_logs`, chỉ quản trị đọc được).
class SendLogEntry {
  SendLogEntry({
    required this.result,
    required this.purpose,
    this.reportId,
    this.actorUid,
  });

  final SendResult result;
  final NotificationPurpose purpose;
  final String? reportId;
  final String? actorUid;

  Map<String, Object?> toFirestore() => {
        'createdAt': result.sentAt.toUtc(),
        'channel': result.channel,
        'purpose': purpose.wire,
        'template': result.template.wire,
        'templateId': result.templateId,
        'trackingId': result.trackingId,
        'recipient': result.recipientMasked,
        'mode': result.mode,
        'success': result.success,
        'errorCode': result.errorCode,
        'errorKind': result.errorKind?.wire,
        'message': result.userMessage,
        'providerMessage': result.providerMessage,
        'messageId': result.messageId,
        'dailyQuota': result.dailyQuota,
        'remainingQuota': result.remainingQuota,
        'durationMs': result.durationMs,
        'attempts': result.attempts,
        'reportId': reportId,
        'actorUid': actorUid,
      };
}

abstract interface class SendLogRepository {
  Future<void> add(SendLogEntry entry);
}
