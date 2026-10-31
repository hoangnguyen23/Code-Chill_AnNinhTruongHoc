import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../firebase/firebase_providers.dart';
import '../network/api_client.dart';

/// Push FCM song song với tin Zalo.
///
/// - Kênh "Cảnh báo sự cố" (ưu tiên cao) cho bảo vệ/quản trị, kênh "Cập nhật báo cáo" cho người báo.
///   ID kênh trùng với backend (`FcmPushService`).
/// - Khi app đang mở, FCM không tự hiện thông báo nên dùng flutter_local_notifications.
/// - Bấm thông báo: phát `reportId` qua [reportTaps] để app mở chi tiết báo cáo.
class PushNotifications {
  PushNotifications(this._messaging, this._api, {FlutterLocalNotificationsPlugin? local})
      : _local = local ?? FlutterLocalNotificationsPlugin();

  final FirebaseMessaging _messaging;
  final ApiClient _api;
  final FlutterLocalNotificationsPlugin _local;

  static const urgentChannel = AndroidNotificationChannel(
    'incident_alerts',
    'Cảnh báo sự cố',
    description: 'Sự cố mới và báo cáo khẩn cấp gửi tới bảo vệ trực.',
    importance: Importance.max,
  );

  static const updatesChannel = AndroidNotificationChannel(
    'report_updates',
    'Cập nhật báo cáo',
    description: 'Trạng thái và trao đổi về báo cáo của bạn.',
    importance: Importance.high,
  );

  final _taps = StreamController<String>.broadcast();
  final _subscriptions = <StreamSubscription<Object?>>[];
  StreamSubscription<String>? _tokenRefresh;
  String? _pendingReportId;
  bool _initialized = false;

  Stream<String> get reportTaps => _taps.stream;

  /// Báo cáo được mở từ thông báo khi app khởi động (đọc một lần).
  String? takePendingReportId() {
    final id = _pendingReportId;
    _pendingReportId = null;
    return id;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    final android = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(urgentChannel);
    await android?.createNotificationChannel(updatesChannel);
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) => _emitTap(response.payload),
    );

    final launch = await _local.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      _pendingReportId = launch!.notificationResponse?.payload;
    }
    final initial = await _messaging.getInitialMessage();
    if (initial != null) _pendingReportId = initial.data['reportId'] as String?;

    _subscriptions
      ..add(FirebaseMessaging.onMessage.listen(_showForeground))
      ..add(FirebaseMessaging.onMessageOpenedApp.listen((m) => _emitTap(m.data['reportId'] as String?)));
  }

  // firebase_messaging 17 đánh dấu getToken/onTokenRefresh/deleteToken là deprecated để chuyển sang
  // định danh FID (register/onRegistered). Backend gửi push qua FCM HTTP v1 bằng dart_firebase_admin,
  // vốn nhắm tới registration token (trường `token`), nên app vẫn dùng registration token.
  // Các API này vẫn hoạt động; khi Admin SDK hỗ trợ gửi theo FID thì đổi sang register().

  /// Gọi khi đã đăng nhập: xin quyền thông báo (Android 13+) và đăng ký token với backend.
  Future<void> registerForCurrentUser() async {
    try {
      await _messaging.requestPermission();
      // ignore: deprecated_member_use
      final token = await _messaging.getToken();
      if (token != null) await _api.post('/me/fcm_token', {'token': token});
      await _tokenRefresh?.cancel();
      // ignore: deprecated_member_use
      _tokenRefresh = _messaging.onTokenRefresh.listen((t) async {
        try {
          await _api.post('/me/fcm_token', {'token': t});
        } on Object catch (e) {
          debugPrint('Không cập nhật được FCM token: $e');
        }
      });
    } on Object catch (e) {
      // Push là kênh phụ; Zalo vẫn hoạt động nếu push lỗi.
      debugPrint('Không đăng ký được push: $e');
    }
  }

  /// Gọi trước khi đăng xuất: huỷ đăng ký token để máy này không nhận tin của tài khoản cũ.
  Future<void> unregister() async {
    await _tokenRefresh?.cancel();
    _tokenRefresh = null;
    // ignore: deprecated_member_use
    final token = await _messaging.getToken();
    if (token != null) {
      await _api.delete('/me/fcm_token', {'token': token}).timeout(const Duration(seconds: 5));
    }
    // ignore: deprecated_member_use
    await _messaging.deleteToken();
  }

  void _emitTap(String? reportId) {
    if (reportId == null || reportId.isEmpty) return;
    _taps.add(reportId);
  }

  Future<void> _showForeground(RemoteMessage message) async {
    final n = message.notification;
    if (n == null) return;
    final urgent = n.android?.channelId == urgentChannel.id;
    final channel = urgent ? urgentChannel : updatesChannel;
    await _local.show(
      id: message.messageId.hashCode & 0x7fffffff,
      title: n.title,
      body: n.body,
      payload: message.data['reportId'] as String?,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: channel.importance,
          priority: urgent ? Priority.max : Priority.high,
          category: urgent ? AndroidNotificationCategory.alarm : AndroidNotificationCategory.status,
        ),
      ),
    );
  }

  Future<void> dispose() async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    await _tokenRefresh?.cancel();
    await _taps.close();
  }
}

final pushNotificationsProvider = Provider<PushNotifications>((ref) {
  final push = PushNotifications(ref.watch(messagingProvider), ref.watch(apiClientProvider));
  ref.onDispose(push.dispose);
  return push;
});
