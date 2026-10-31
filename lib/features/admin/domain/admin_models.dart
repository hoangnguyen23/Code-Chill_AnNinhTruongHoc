/// Mô hình dữ liệu cho màn quản trị (Zalo, nhật ký gửi tin).
library;

DateTime? _date(Object? v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  try {
    final converted = (v as dynamic).toDate();
    if (converted is DateTime) return converted;
  } on NoSuchMethodError {
    // Không phải Timestamp.
  }
  return null;
}

class ZaloParamInfo {
  const ZaloParamInfo({
    required this.name,
    required this.typeLabel,
    required this.maxLength,
    required this.description,
    required this.sample,
  });

  factory ZaloParamInfo.fromJson(Map<String, Object?> j) => ZaloParamInfo(
        name: j['name']! as String,
        typeLabel: (j['typeLabel'] as String?) ?? '',
        maxLength: (j['maxLength'] as int?) ?? 30,
        description: (j['description'] as String?) ?? '',
        sample: (j['sample'] as String?) ?? '',
      );

  final String name;
  final String typeLabel;
  final int maxLength;
  final String description;
  final String sample;
}

class ZaloTemplateInfo {
  const ZaloTemplateInfo({
    required this.key,
    required this.title,
    required this.envVar,
    required this.configured,
    required this.templateId,
    required this.params,
  });

  factory ZaloTemplateInfo.fromJson(Map<String, Object?> j) => ZaloTemplateInfo(
        key: j['key']! as String,
        title: (j['title'] as String?) ?? '',
        envVar: (j['envVar'] as String?) ?? '',
        configured: j['configured'] == true,
        templateId: j['templateId'] as String?,
        params: ((j['params'] as List?) ?? const [])
            .whereType<Map>()
            .map((p) => ZaloParamInfo.fromJson(p.cast<String, Object?>()))
            .toList(),
      );

  final String key;
  final String title;
  final String envVar;
  final bool configured;
  final String? templateId;
  final List<ZaloParamInfo> params;
}

class ZaloTokenInfo {
  const ZaloTokenInfo({
    required this.valid,
    this.expiresAt,
    this.lastRefreshAt,
    this.lastError,
    this.lastErrorAt,
  });

  factory ZaloTokenInfo.fromJson(Map<String, Object?> j) => ZaloTokenInfo(
        valid: j['accessTokenValid'] == true,
        expiresAt: _date(j['accessTokenExpiresAt']),
        lastRefreshAt: _date(j['lastRefreshAt']),
        lastError: (j['lastError'] ?? j['error']) as String?,
        lastErrorAt: _date(j['lastErrorAt']),
      );

  final bool valid;
  final DateTime? expiresAt;
  final DateTime? lastRefreshAt;
  final String? lastError;
  final DateTime? lastErrorAt;
}

class ZaloStatus {
  const ZaloStatus({
    required this.mode,
    required this.token,
    required this.templates,
    required this.warnings,
  });

  factory ZaloStatus.fromJson(Map<String, Object?> j) => ZaloStatus(
        mode: (j['mode'] as String?) ?? 'development',
        token: ZaloTokenInfo.fromJson((j['token'] as Map?)?.cast<String, Object?>() ?? const {}),
        templates: ((j['templates'] as List?) ?? const [])
            .whereType<Map>()
            .map((t) => ZaloTemplateInfo.fromJson(t.cast<String, Object?>()))
            .toList(),
        warnings: ((j['warnings'] as List?) ?? const []).whereType<String>().toList(),
      );

  final String mode;
  final ZaloTokenInfo token;
  final List<ZaloTemplateInfo> templates;
  final List<String> warnings;

  bool get isDevelopment => mode == 'development';
}

/// Kết quả một lần gửi tin (từ "Gửi thử" hoặc từ nhật ký `zalo_logs`).
class SendLogItem {
  const SendLogItem({
    required this.id,
    required this.success,
    required this.template,
    required this.recipient,
    required this.mode,
    required this.trackingId,
    this.createdAt,
    this.purpose,
    this.templateId,
    this.messageId,
    this.errorCode,
    this.errorKind,
    this.message,
    this.providerMessage,
    this.durationMs,
    this.dailyQuota,
    this.remainingQuota,
    this.attempts,
    this.reportId,
  });

  factory SendLogItem.fromMap(String id, Map<String, dynamic> d) => SendLogItem(
        id: id,
        success: d['success'] == true,
        template: (d['template'] as String?) ?? '',
        recipient: (d['recipient'] as String?) ?? '',
        mode: (d['mode'] as String?) ?? '',
        trackingId: (d['trackingId'] as String?) ?? '',
        createdAt: _date(d['createdAt'] ?? d['sentAt']),
        purpose: d['purpose'] as String?,
        templateId: d['templateId'] as String?,
        messageId: d['messageId'] as String?,
        errorCode: (d['errorCode'] as num?)?.toInt(),
        errorKind: d['errorKind'] as String?,
        message: d['message'] as String?,
        providerMessage: d['providerMessage'] as String?,
        durationMs: (d['durationMs'] as num?)?.toInt(),
        dailyQuota: (d['dailyQuota'] as num?)?.toInt(),
        remainingQuota: (d['remainingQuota'] as num?)?.toInt(),
        attempts: (d['attempts'] as num?)?.toInt(),
        reportId: d['reportId'] as String?,
      );

  final String id;
  final bool success;
  final String template;
  final String recipient;
  final String mode;
  final String trackingId;
  final DateTime? createdAt;
  final String? purpose;
  final String? templateId;
  final String? messageId;
  final int? errorCode;
  final String? errorKind;
  final String? message;
  final String? providerMessage;
  final int? durationMs;
  final int? dailyQuota;
  final int? remainingQuota;
  final int? attempts;
  final String? reportId;
}

String templateTitle(String key) => switch (key) {
      'otp' => 'Mã OTP đăng nhập',
      'report_received' => 'Xác nhận đã nhận báo cáo',
      'status_update' => 'Cập nhật trạng thái',
      'guard_alert' => 'Cảnh báo bảo vệ',
      _ => key,
    };

String purposeLabel(String? purpose) => switch (purpose) {
      'otp' => 'Đăng nhập',
      'report_received' => 'Xác nhận báo cáo',
      'status_update' => 'Đổi trạng thái',
      'guard_alert' => 'Cảnh báo bảo vệ',
      'test' => 'Gửi thử',
      _ => purpose ?? '',
    };
