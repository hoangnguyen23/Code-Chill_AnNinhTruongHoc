import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'zalo_error_catalog.dart';

/// Trạng thái token OA đang dùng, lưu ở Firestore `system/zalo_oauth` (client không đọc được).
class ZaloTokenState {
  const ZaloTokenState({
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresAt,
    required this.updatedAt,
    required this.seedFingerprint,
    this.lastError,
    this.lastErrorAt,
    this.lastRefreshAt,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime accessTokenExpiresAt;
  final DateTime updatedAt;

  /// Dấu vân tay của ZALO_REFRESH_TOKEN trong .env đã dùng để khởi tạo. Khi quản trị dán
  /// refresh token mới vào .env, dấu vân tay đổi và backend nạp lại token từ .env.
  final String seedFingerprint;
  final String? lastError;
  final DateTime? lastErrorAt;
  final DateTime? lastRefreshAt;

  ZaloTokenState copyWith({String? lastError, DateTime? lastErrorAt}) => ZaloTokenState(
        accessToken: accessToken,
        refreshToken: refreshToken,
        accessTokenExpiresAt: accessTokenExpiresAt,
        updatedAt: updatedAt,
        seedFingerprint: seedFingerprint,
        lastError: lastError ?? this.lastError,
        lastErrorAt: lastErrorAt ?? this.lastErrorAt,
        lastRefreshAt: lastRefreshAt,
      );
}

abstract interface class ZaloTokenStore {
  Future<ZaloTokenState?> read();
  Future<void> write(ZaloTokenState state);
}

class ZaloTokenException implements Exception {
  ZaloTokenException(this.detail) : info = ZaloErrorCatalog.tokenRefreshFailed(detail);

  final String detail;
  final ZaloErrorInfo info;

  @override
  String toString() => info.message;
}

/// Lấy và tự làm mới access token của Zalo OA theo OAuth v4.
///
/// Theo tài liệu "Xác thực và ủy quyền cho ứng dụng" của Zalo:
/// - Access token hiệu lực 25 giờ; refresh token hiệu lực 3 tháng.
/// - Refresh token chỉ dùng được MỘT lần; mỗi lần làm mới trả về refresh token mới và
///   access token cũ hết hiệu lực ngay. Vì vậy token mới luôn được lưu lại vào [ZaloTokenStore]
///   và mọi lần làm mới trong cùng tiến trình được gộp thành một request (single-flight).
class ZaloTokenManager {
  ZaloTokenManager({
    required http.Client client,
    required ZaloTokenStore store,
    required String appId,
    required String secretKey,
    required String seedRefreshToken,
    String? seedAccessToken,
    DateTime Function()? clock,
    Uri? endpoint,
    this.timeout = const Duration(seconds: 15),
  })  : _client = client,
        _store = store,
        _appId = appId,
        _secretKey = secretKey,
        _seedRefreshToken = seedRefreshToken,
        _seedAccessToken = seedAccessToken,
        _clock = clock ?? DateTime.now,
        _endpoint = endpoint ?? oauthEndpoint;

  static final Uri oauthEndpoint = Uri.parse('https://oauth.zaloapp.com/v4/oa/access_token');

  /// Làm mới sớm nếu access token còn ít hơn khoảng này.
  static const Duration refreshMargin = Duration(minutes: 5);

  /// Access token dán tay trong .env không rõ thời điểm cấp, coi như còn hiệu lực 1 giờ.
  static const Duration seededAccessTokenLifetime = Duration(hours: 1);

  final http.Client _client;
  final ZaloTokenStore _store;
  final String _appId;
  final String _secretKey;
  final String _seedRefreshToken;
  final String? _seedAccessToken;
  final DateTime Function() _clock;
  final Uri _endpoint;
  final Duration timeout;

  ZaloTokenState? _cache;
  Completer<String>? _inflight;
  Timer? _timer;

  static String fingerprint(String token) =>
      sha256.convert(utf8.encode(token)).toString().substring(0, 16);

  /// Access token còn hiệu lực, tự làm mới nếu sắp hết hạn.
  Future<String> accessToken() async {
    final state = await _state();
    if (_isUsable(state, margin: refreshMargin)) return state.accessToken;
    return _refresh(state);
  }

  /// Gọi khi Zalo trả lỗi -124 cho [rejectedAccessToken]. Nếu tiến trình khác đã làm mới
  /// trong lúc đó thì dùng luôn token mới, không làm mới lần nữa.
  Future<String> forceRefresh({required String rejectedAccessToken}) async {
    final state = await _state(reload: true);
    if (state.accessToken != rejectedAccessToken && _isUsable(state)) {
      return state.accessToken;
    }
    return _refresh(state);
  }

  /// Thông tin cho màn quản trị (không lộ token).
  Future<Map<String, Object?>> status() async {
    final s = await _state(reload: true);
    return {
      'hasAccessToken': s.accessToken.isNotEmpty,
      'accessTokenExpiresAt': s.accessTokenExpiresAt.toUtc().toIso8601String(),
      'accessTokenValid': _isUsable(s),
      'updatedAt': s.updatedAt.toUtc().toIso8601String(),
      'lastRefreshAt': s.lastRefreshAt?.toUtc().toIso8601String(),
      'lastError': s.lastError,
      'lastErrorAt': s.lastErrorAt?.toUtc().toIso8601String(),
    };
  }

  /// Định kỳ làm mới trước khi hết hạn để refresh token luôn được "gia hạn" 3 tháng.
  void startAutoRefresh({Duration every = const Duration(minutes: 30)}) {
    _timer?.cancel();
    _timer = Timer.periodic(every, (_) async {
      try {
        final s = await _state(reload: true);
        if (!_isUsable(s, margin: const Duration(hours: 2))) await _refresh(s);
      } on Object catch (e) {
        stderr.writeln('[zalo] Tự làm mới token thất bại: $e');
      }
    });
  }

  void dispose() => _timer?.cancel();

  bool _isUsable(ZaloTokenState s, {Duration margin = Duration.zero}) =>
      s.accessToken.isNotEmpty && s.accessTokenExpiresAt.isAfter(_clock().add(margin));

  Future<ZaloTokenState> _state({bool reload = false}) async {
    final cached = _cache;
    if (!reload && cached != null) return cached;
    final stored = await _store.read();
    final seedFp = fingerprint(_seedRefreshToken);
    if (stored != null && stored.seedFingerprint == seedFp) {
      return _cache = stored;
    }
    final now = _clock();
    final seedAccess = _seedAccessToken ?? '';
    final seeded = ZaloTokenState(
      accessToken: seedAccess,
      refreshToken: _seedRefreshToken,
      accessTokenExpiresAt:
          seedAccess.isEmpty ? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true) : now.add(seededAccessTokenLifetime),
      updatedAt: now,
      seedFingerprint: seedFp,
    );
    await _store.write(seeded);
    return _cache = seeded;
  }

  Future<String> _refresh(ZaloTokenState current) {
    final inflight = _inflight;
    if (inflight != null) return inflight.future;
    final completer = _inflight = Completer<String>();
    unawaited(() async {
      try {
        completer.complete(await _doRefresh(current));
      } on Object catch (e, st) {
        completer.completeError(e, st);
      } finally {
        _inflight = null;
      }
    }());
    return completer.future;
  }

  Future<String> _doRefresh(ZaloTokenState current) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            _endpoint,
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded',
              'secret_key': _secretKey,
            },
            body: {
              'refresh_token': current.refreshToken,
              'app_id': _appId,
              'grant_type': 'refresh_token',
            },
          )
          .timeout(timeout);
    } on Object catch (e) {
      throw await _fail(current, 'không kết nối được oauth.zaloapp.com: ${_short(e)}');
    }

    Object? json;
    try {
      json = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      json = null;
    }
    if (json is Map && json['access_token'] is String && json['refresh_token'] is String) {
      final now = _clock();
      final expiresIn = int.tryParse('${json['expires_in'] ?? ''}') ?? 90000;
      final next = ZaloTokenState(
        accessToken: json['access_token'] as String,
        refreshToken: json['refresh_token'] as String,
        accessTokenExpiresAt: now.add(Duration(seconds: expiresIn)),
        updatedAt: now,
        lastRefreshAt: now,
        seedFingerprint: current.seedFingerprint,
      );
      await _store.write(next);
      _cache = next;
      return next.accessToken;
    }

    // Có thể một tiến trình backend khác vừa dùng refresh token này. Đọc lại kho token.
    final latest = await _store.read();
    if (latest != null && latest.refreshToken != current.refreshToken && _isUsable(latest)) {
      _cache = latest;
      return latest.accessToken;
    }

    final detail = json is Map
        ? 'mã ${json['error'] ?? response.statusCode}: '
            '${json['error_description'] ?? json['error_name'] ?? json['message'] ?? 'không rõ'}'
        : 'HTTP ${response.statusCode}';
    throw await _fail(current, detail);
  }

  Future<ZaloTokenException> _fail(ZaloTokenState current, String detail) async {
    try {
      // Ghi lỗi lên bản mới nhất trong kho để không đè mất token mà tiến trình khác vừa lưu.
      final base = await _store.read() ?? current;
      final failed = base.copyWith(lastError: detail, lastErrorAt: _clock());
      await _store.write(failed);
      _cache = failed;
    } on Object {
      // Không che lỗi gốc nếu ghi trạng thái lỗi thất bại.
    }
    return ZaloTokenException(detail);
  }

  static String _short(Object e) {
    final s = e.toString();
    return s.length > 120 ? '${s.substring(0, 120)}…' : s;
  }
}
