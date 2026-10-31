import 'dart:io';

import 'package:dart_firebase_admin/auth.dart' as fb_auth;
import 'package:dart_firebase_admin/dart_firebase_admin.dart';
import 'package:dart_firebase_admin/firestore.dart';
import 'package:dart_firebase_admin/messaging.dart' as fb_messaging;
import 'package:http/http.dart' as http;

import 'auth/firebase_auth_service.dart';
import 'auth/otp_mailer.dart';
import 'auth/account_service.dart';
import 'config/app_config.dart';
import 'data/firestore_repositories.dart';
import 'data/firestore_safety_repositories.dart';
import 'data/models.dart';
import 'data/repositories.dart';
import 'notifications/notification_gateway.dart';
import 'notifications/notification_service.dart';
import 'notifications/push_service.dart';
import 'notifications/zalo/zalo_token_manager.dart';
import 'notifications/zalo/zalo_zns_gateway.dart';
import 'http/user_limits.dart';
import 'reports/image_store.dart';
import 'reports/report_service.dart';
import 'safety/broadcast_service.dart';
import 'safety/walk_service.dart';

/// Toàn bộ dịch vụ của backend, khởi tạo một lần trong `main.dart` và cung cấp cho route qua
/// `context.read<AppServices>()`.
class AppServices {
  AppServices({
    required this.config,
    required this.users,
    required this.reports,
    required this.campusConfig,
    required this.authTokens,
    required this.zaloTokens,
    required this.gateway,
    required this.accounts,
    required this.reportService,
    required this.notifications,
    required this.broadcasts,
    required this.walks,
    required this.images,
    UserLimits? limits,
  }) : limits = limits ?? UserLimits();

  final AppConfig config;
  final UserRepository users;
  final ReportRepository reports;
  final ConfigRepository campusConfig;
  final AuthTokenService authTokens;
  /// `null` khi chưa cấu hình Zalo.
  final ZaloTokenManager? zaloTokens;
  final NotificationGateway gateway;
  final AccountService accounts;
  final ReportService reportService;
  final NotificationService notifications;
  final BroadcastService broadcasts;
  final WalkService walks;
  final ImageService images;

  /// Giới hạn tần suất thao tác ghi theo tài khoản (chống spam).
  final UserLimits limits;

  static AppServices? _instance;

  static AppServices get instance {
    final i = _instance;
    if (i == null) throw StateError('AppServices chưa được khởi tạo (xem main.dart).');
    return i;
  }

  static set instance(AppServices value) => _instance = value;

  /// Cấu hình trường hiện tại (Firestore `config/app`), rơi về giá trị trong .env và
  /// `config/campus.json` nếu chưa có.
  Future<CampusConfig> currentCampusConfig() async {
    final stored = await campusConfig.read();
    return CampusConfig(
      campusName: (stored?.campusName.isNotEmpty ?? false) ? stored!.campusName : config.campusName,
      hotline: stored?.hotline ?? config.dutyHotline,
      buildings: (stored?.buildings.isNotEmpty ?? false) ? stored!.buildings : config.defaultBuildings,
      updatedAt: stored?.updatedAt,
    );
  }

  /// Kết nối Firebase Admin, máy chủ mail và Zalo (nếu có cấu hình) theo [config].
  factory AppServices.production(AppConfig config) {
    final credentialPath = config.serviceAccountPath;
    final Credential credential;
    if (credentialPath != null) {
      final file = File(credentialPath);
      if (!file.existsSync()) {
        throw ConfigException([
          'Không tìm thấy file service account "$credentialPath" (GOOGLE_APPLICATION_CREDENTIALS).',
        ]);
      }
      credential = Credential.fromServiceAccount(file);
    } else {
      credential = Credential.fromApplicationDefaultCredentials();
    }
    final app = FirebaseAdminApp.initializeApp(config.firebaseProjectId, credential);
    final firestore = Firestore(app);
    final httpClient = http.Client();

    final users = FirestoreUserRepository(firestore);
    final reports = FirestoreReportRepository(firestore);
    final authTokens = FirebaseAuthTokenService(fb_auth.Auth(app));

    final zaloTokens = config.zaloEnabled
        ? ZaloTokenManager(
            client: httpClient,
            store: FirestoreZaloTokenStore(firestore),
            appId: config.zaloAppId,
            secretKey: config.zaloSecretKey,
            seedRefreshToken: config.zaloSeedRefreshToken,
            seedAccessToken: config.zaloSeedAccessToken,
          )
        : null;
    final NotificationGateway gateway = zaloTokens == null
        ? const DisabledNotificationGateway()
        : ZaloZnsGateway(
            client: httpClient,
            tokens: zaloTokens,
            mode: config.znsMode,
            templateIds: config.templateIds,
            logs: FirestoreSendLogRepository(firestore),
          );
    final notifications = NotificationService(
      gateway: gateway,
      push: FcmPushService(fb_messaging.Messaging(app)),
      users: users,
      extraDutyPhones: config.dutyGuardPhones,
    );

    final reportService = ReportService(reports: reports, users: users, notifications: notifications);
    return AppServices(
      config: config,
      users: users,
      reports: reports,
      campusConfig: FirestoreConfigRepository(firestore),
      authTokens: authTokens,
      zaloTokens: zaloTokens,
      gateway: gateway,
      notifications: notifications,
      accounts: AccountService(
        store: FirestoreOtpStore(firestore),
        users: users,
        credentials: FirestoreCredentialRepository(firestore),
        mailer: SmtpOtpMailer(
          host: config.smtpHost,
          port: config.smtpPort,
          username: config.smtpUsername,
          password: config.smtpPassword,
          fromName: config.mailFromName,
          appName: config.mailFromName,
        ),
        auth: authTokens,
        pepper: config.otpPepper,
        allowSelfRegistration: config.allowSelfRegistration,
        bootstrapAdmins: config.bootstrapAdminEmails,
      ),
      reportService: reportService,
      images: ImageService(FirestoreImageRepository(firestore)),
      broadcasts: BroadcastService(broadcasts: FirestoreBroadcastRepository(firestore), notifications: notifications),
      walks: WalkService(
        walks: FirestoreWalkRepository(firestore),
        users: users,
        reports: reportService,
        notifications: notifications,
      ),
    );
  }
}
