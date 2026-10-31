import 'package:campus_core/campus_core.dart';

import 'zalo/zalo_error_catalog.dart';
import 'zalo/zalo_templates.dart';

/// Mục đích gửi tin, ghi vào nhật ký.
enum NotificationPurpose {
  otp('otp', 'OTP'),
  reportReceived('report_received', 'RPT'),
  statusUpdate('status_update', 'STS'),
  guardAlert('guard_alert', 'GRD'),
  test('test', 'TST');

  const NotificationPurpose(this.wire, this.trackingPrefix);

  final String wire;
  final String trackingPrefix;
}

/// Một tin nhắn theo template cần gửi tới một số điện thoại.
class TemplateMessage {
  const TemplateMessage({
    required this.recipient,
    required this.template,
    required this.data,
    required this.purpose,
    this.reportId,
    this.actorUid,
  });

  final VietnamPhone recipient;
  final ZaloTemplateKey template;
  final Map<String, String> data;
  final NotificationPurpose purpose;
  final String? reportId;

  /// Người bấm gửi (ví dụ quản trị dùng màn "Gửi thử").
  final String? actorUid;
}

/// Kết quả một lần gửi. Không chứa số điện thoại đầy đủ.
class SendResult {
  const SendResult({
    required this.success,
    required this.channel,
    required this.template,
    required this.trackingId,
    required this.recipientMasked,
    required this.mode,
    required this.sentAt,
    required this.durationMs,
    this.templateId,
    this.messageId,
    this.errorCode,
    this.errorKind,
    this.userMessage,
    this.providerMessage,
    this.retryable = false,
    this.dailyQuota,
    this.remainingQuota,
    this.attempts = 1,
  });

  final bool success;
  final String channel;
  final ZaloTemplateKey template;
  final String? templateId;
  final String trackingId;
  final String recipientMasked;
  final String mode;
  final DateTime sentAt;
  final int durationMs;
  final String? messageId;
  final int? errorCode;
  final ZaloErrorKind? errorKind;

  /// Thông báo tiếng Việt cho người dùng (null khi thành công).
  final String? userMessage;

  /// Thông điệp gốc từ nhà cung cấp, chỉ hiển thị cho quản trị.
  final String? providerMessage;
  final bool retryable;
  final int? dailyQuota;
  final int? remainingQuota;
  final int attempts;

  Map<String, Object?> toJson() => {
        'success': success,
        'channel': channel,
        'template': template.wire,
        'templateId': templateId,
        'trackingId': trackingId,
        'recipient': recipientMasked,
        'mode': mode,
        'sentAt': sentAt.toUtc().toIso8601String(),
        'durationMs': durationMs,
        'messageId': messageId,
        'errorCode': errorCode,
        'errorKind': errorKind?.wire,
        'message': userMessage,
        'providerMessage': providerMessage,
        'retryable': retryable,
        'dailyQuota': dailyQuota,
        'remainingQuota': remainingQuota,
        'attempts': attempts,
      };
}

/// Kênh gửi tin theo template tới số điện thoại. Bản cài đặt: [ZaloZnsGateway].
abstract interface class NotificationGateway {
  /// Tên kênh ghi vào log, ví dụ `zalo_zns`.
  String get channel;

  /// Chế độ gửi hiện tại (development / production).
  String get mode;

  /// Template đã cấu hình ID hay chưa.
  bool isConfigured(ZaloTemplateKey template);

  /// Gửi tin. Không ném lỗi: mọi thất bại trả về [SendResult.success] = false
  /// kèm [SendResult.userMessage] tiếng Việt. Mỗi lần gửi đều được ghi nhật ký.
  Future<SendResult> send(TemplateMessage message);
}

/// Dùng khi backend chưa cấu hình Zalo: không gọi mạng, mọi lần gửi trả về thất bại có lời giải thích.
class DisabledNotificationGateway implements NotificationGateway {
  const DisabledNotificationGateway({DateTime Function()? clock}) : _clock = clock;

  final DateTime Function()? _clock;

  @override
  String get channel => 'zalo_off';

  @override
  String get mode => 'off';

  @override
  bool isConfigured(ZaloTemplateKey template) => false;

  @override
  Future<SendResult> send(TemplateMessage message) async => SendResult(
        success: false,
        channel: channel,
        template: message.template,
        trackingId: '${message.purpose.trackingPrefix}-OFF',
        recipientMasked: message.recipient.masked,
        mode: mode,
        sentAt: (_clock ?? DateTime.now)().toUtc(),
        durationMs: 0,
        errorKind: ZaloErrorKind.configuration,
        userMessage: 'Backend chưa bật Zalo nên không gửi tin Zalo (vẫn có thông báo đẩy trong app).',
      );
}
