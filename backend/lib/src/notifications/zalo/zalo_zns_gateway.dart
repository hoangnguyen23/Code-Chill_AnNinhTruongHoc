import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../../config/app_config.dart';
import '../notification_gateway.dart';
import '../send_log.dart';
import 'zalo_error_catalog.dart';
import 'zalo_templates.dart';
import 'zalo_token_manager.dart';

/// Gửi tin ZBS Template Message (trước đây là ZNS) qua số điện thoại.
///
/// Theo tài liệu "API Gửi tin" và "API Gửi tin sử dụng development mode":
/// - `POST https://business.openapi.zalo.me/message/template`
/// - Header `access_token: <OA access token>`, `Content-Type: application/json`
/// - Body: `phone` (84xxxxxxxxx), `template_id`, `template_data`, `tracking_id`
///   (tối đa 48 ký tự, không ký tự đặc biệt) và `mode: "development"` khi thử nghiệm.
/// - Thành công: `{"error": 0, "message": "Success", "data": {"msg_id", "sent_time", "quota"}}`.
class ZaloZnsGateway implements NotificationGateway {
  ZaloZnsGateway({
    required http.Client client,
    required ZaloTokenManager tokens,
    required ZnsMode mode,
    required Map<ZaloTemplateKey, String> templateIds,
    required SendLogRepository logs,
    DateTime Function()? clock,
    Random? random,
    Uri? endpoint,
    this.timeout = const Duration(seconds: 12),
  })  : _client = client,
        _tokens = tokens,
        _mode = mode,
        _templateIds = Map.unmodifiable(templateIds),
        _logs = logs,
        _clock = clock ?? DateTime.now,
        _random = random ?? Random.secure(),
        _endpoint = endpoint ?? sendEndpoint;

  static final Uri sendEndpoint = Uri.parse('https://business.openapi.zalo.me/message/template');

  final http.Client _client;
  final ZaloTokenManager _tokens;
  final ZnsMode _mode;
  final Map<ZaloTemplateKey, String> _templateIds;
  final SendLogRepository _logs;
  final DateTime Function() _clock;
  final Random _random;
  final Uri _endpoint;
  final Duration timeout;

  @override
  String get channel => 'zalo_zns';

  @override
  String get mode => _mode.name;

  @override
  bool isConfigured(ZaloTemplateKey template) => _templateIds.containsKey(template);

  String? templateId(ZaloTemplateKey template) => _templateIds[template];

  @override
  Future<SendResult> send(TemplateMessage message) async {
    final started = _clock();
    final stopwatch = Stopwatch()..start();
    final trackingId = newTrackingId(message.purpose);
    final templateId = _templateIds[message.template];

    SendResult fail(ZaloErrorInfo info, {String? providerMessage, int attempts = 0}) => SendResult(
          success: false,
          channel: channel,
          template: message.template,
          templateId: templateId,
          trackingId: trackingId,
          recipientMasked: message.recipient.masked,
          mode: mode,
          sentAt: started,
          durationMs: stopwatch.elapsedMilliseconds,
          errorCode: info.code == 0 ? null : info.code,
          errorKind: info.kind,
          userMessage: info.message,
          providerMessage: providerMessage,
          retryable: info.retryable,
          attempts: attempts,
        );

    Future<SendResult> attempt() async {
      if (templateId == null) {
        return fail(ZaloErrorCatalog.templateNotConfigured(message.template.envVar, message.template.title));
      }
      final Map<String, String> data;
      try {
        data = buildTemplateData(message.template, message.data);
      } on TemplateDataException catch (e) {
        return fail(ZaloErrorInfo(0, ZaloErrorKind.templateParams, e.message));
      }
      final body = <String, Object?>{
        'phone': message.recipient.international,
        'template_id': templateId,
        'template_data': data,
        'tracking_id': trackingId,
        if (_mode == ZnsMode.development) 'mode': 'development',
      };
      return _sendWithTokenRetry(body, fail, started, stopwatch, message, templateId, trackingId);
    }

    final result = await attempt();
    await _writeLog(message, result);
    return result;
  }

  Future<SendResult> _sendWithTokenRetry(
    Map<String, Object?> body,
    SendResult Function(ZaloErrorInfo, {String? providerMessage, int attempts}) fail,
    DateTime started,
    Stopwatch stopwatch,
    TemplateMessage message,
    String templateId,
    String trackingId,
  ) async {
    String token;
    try {
      token = await _tokens.accessToken();
    } on ZaloTokenException catch (e) {
      return fail(e.info, providerMessage: e.detail);
    }

    var attempts = 1;
    var outcome = await _post(token, body);
    if (outcome.errorCode == -124) {
      // Access token bị từ chối: làm mới một lần rồi gửi lại.
      try {
        token = await _tokens.forceRefresh(rejectedAccessToken: token);
      } on ZaloTokenException catch (e) {
        return fail(e.info, providerMessage: e.detail, attempts: attempts);
      }
      attempts++;
      outcome = await _post(token, body);
    }

    if (outcome.networkError != null) {
      return fail(ZaloErrorCatalog.network, providerMessage: outcome.networkError, attempts: attempts);
    }
    if (outcome.errorCode != 0) {
      final info = ZaloErrorCatalog.lookup(outcome.errorCode, providerMessage: outcome.providerMessage);
      return fail(info, providerMessage: outcome.providerMessage, attempts: attempts);
    }

    final data = outcome.data ?? const <String, Object?>{};
    final quota = data['quota'];
    return SendResult(
      success: true,
      channel: channel,
      template: message.template,
      templateId: templateId,
      trackingId: trackingId,
      recipientMasked: message.recipient.masked,
      mode: mode,
      sentAt: started,
      durationMs: stopwatch.elapsedMilliseconds,
      messageId: data['msg_id']?.toString(),
      providerMessage: outcome.providerMessage,
      dailyQuota: quota is Map ? int.tryParse('${quota['dailyQuota']}') : null,
      remainingQuota: quota is Map ? int.tryParse('${quota['remainingQuota']}') : null,
      attempts: attempts,
    );
  }

  Future<_ZaloOutcome> _post(String accessToken, Map<String, Object?> body) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            _endpoint,
            headers: {
              'Content-Type': 'application/json',
              'access_token': accessToken,
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);
    } on TimeoutException {
      return const _ZaloOutcome.network('Hết thời gian chờ phản hồi từ Zalo');
    } on SocketException catch (e) {
      return _ZaloOutcome.network('Lỗi mạng: ${e.message}');
    } on http.ClientException catch (e) {
      return _ZaloOutcome.network('Lỗi kết nối: ${e.message}');
    }

    Object? json;
    try {
      json = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      json = null;
    }
    if (json is! Map) {
      return _ZaloOutcome(
        errorCode: -100,
        providerMessage: 'HTTP ${response.statusCode}: phản hồi không phải JSON',
      );
    }
    final code = json['error'] is int ? json['error'] as int : int.tryParse('${json['error']}');
    return _ZaloOutcome(
      errorCode: code ?? -100,
      providerMessage: json['message']?.toString(),
      data: json['data'] is Map ? Map<String, Object?>.from(json['data'] as Map) : null,
    );
  }

  Future<void> _writeLog(TemplateMessage message, SendResult result) async {
    try {
      await _logs.add(SendLogEntry(
        result: result,
        purpose: message.purpose,
        reportId: message.reportId,
        actorUid: message.actorUid,
      ));
    } on Object catch (e) {
      // Ghi log thất bại không được làm hỏng việc gửi tin.
      stderr.writeln('[zalo] Không ghi được nhật ký gửi tin ${result.trackingId}: $e');
    }
  }

  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ0123456789';

  /// Mã đối soát: tiền tố mục đích + thời gian (base36) + 6 ký tự ngẫu nhiên, chỉ gồm chữ và số,
  /// dài khoảng 17 ký tự (Zalo khuyến nghị tối đa 48, không ký tự đặc biệt).
  String newTrackingId(NotificationPurpose purpose) {
    final time = _clock().millisecondsSinceEpoch.toRadixString(36).toUpperCase();
    final rnd = List.generate(6, (_) => _alphabet[_random.nextInt(_alphabet.length)]).join();
    return '${purpose.trackingPrefix}$time$rnd';
  }
}

class _ZaloOutcome {
  const _ZaloOutcome({required this.errorCode, this.providerMessage, this.data}) : networkError = null;

  const _ZaloOutcome.network(String message)
      : networkError = message,
        errorCode = 0,
        providerMessage = null,
        data = null;

  final int errorCode;
  final String? providerMessage;
  final Map<String, Object?>? data;
  final String? networkError;
}
