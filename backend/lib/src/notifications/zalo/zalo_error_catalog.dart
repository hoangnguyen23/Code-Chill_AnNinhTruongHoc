/// Ánh xạ mã lỗi ZBS Template Message (ZNS) sang thông báo tiếng Việt.
///
/// Nguồn: "Bảng mã lỗi" tại
/// https://developers.zalo.me/docs/zbs-template-message/bang-ma-loi/
/// (mục "Mã lỗi API chung khi gửi tin Template" và "Mã lỗi API gửi tin qua SĐT").
library;

/// Nhóm lỗi, dùng để app hiển thị và để quyết định có thử lại hay không.
enum ZaloErrorKind {
  /// Số không có tài khoản Zalo, số sai định dạng, người nhận chặn/không đủ điều kiện.
  recipient('recipient'),

  /// Template sai ID, chưa duyệt, không thuộc OA/ứng dụng, chỉ gửi được cho quản trị.
  template('template'),

  /// Sai, thiếu hoặc quá dài tham số template.
  templateParams('template_params'),

  /// Hết hạn mức gửi trong ngày hoặc hết số dư ZBS Account.
  quota('quota'),

  /// Access token hết hạn/không hợp lệ và không làm mới được.
  token('token'),

  /// Gửi ngoài khung giờ cho phép (22h đến 7h).
  timeWindow('time_window'),

  /// Cấu hình OA/ứng dụng/ZBS Account chưa đúng hoặc chưa đủ quyền.
  configuration('configuration'),

  /// Không kết nối được tới Zalo.
  network('network'),

  /// Lỗi không xác định.
  unknown('unknown');

  const ZaloErrorKind(this.wire);

  final String wire;
}

class ZaloErrorInfo {
  const ZaloErrorInfo(this.code, this.kind, this.message, {this.retryable = false});

  final int code;
  final ZaloErrorKind kind;

  /// Thông báo tiếng Việt cho người dùng / quản trị.
  final String message;

  /// Có nên thử lại sau hay không (lỗi tạm thời).
  final bool retryable;
}

abstract final class ZaloErrorCatalog {
  static const _recipient = ZaloErrorKind.recipient;
  static const _template = ZaloErrorKind.template;
  static const _params = ZaloErrorKind.templateParams;
  static const _quota = ZaloErrorKind.quota;
  static const _config = ZaloErrorKind.configuration;

  static const Map<int, ZaloErrorInfo> _byCode = {
    // Người nhận
    -108: ZaloErrorInfo(-108, _recipient,
        'Số điện thoại người nhận không hợp lệ. Kiểm tra lại số (dạng 0912345678).'),
    -118: ZaloErrorInfo(-118, _recipient,
        'Số điện thoại này chưa có tài khoản Zalo hoặc tài khoản đã bị vô hiệu hoá. Hãy dùng số đã đăng ký Zalo.'),
    -110: ZaloErrorInfo(-110, _recipient,
        'Ứng dụng Zalo của người nhận quá cũ, không hiển thị được tin. Người nhận cần cập nhật Zalo.'),
    -139: ZaloErrorInfo(-139, _recipient, 'Người nhận đã từ chối nhận loại tin này từ OA.'),
    -140: ZaloErrorInfo(-140, _recipient,
        'Người nhận chưa đủ điều kiện nhận loại tin này theo chính sách gửi tin hiện tại của Zalo.'),
    -141: ZaloErrorInfo(-141, _recipient, 'Người nhận đã từ chối nhận tin qua số điện thoại từ OA.'),

    // Template
    -109: ZaloErrorInfo(-109, _template,
        'Template ID không hợp lệ. Kiểm tra lại biến ZALO_TEMPLATE_... trong .env của backend.'),
    -131: ZaloErrorInfo(-131, _template,
        'Template chưa được Zalo duyệt. Chờ duyệt xong (trạng thái ENABLE) rồi gửi lại.'),
    -117: ZaloErrorInfo(-117, _template,
        'OA hoặc ứng dụng chưa được quyền dùng template này (template đăng ký bằng OA/App ID khác).'),
    -127: ZaloErrorInfo(-127, _template,
        'Template thử nghiệm chỉ gửi được cho quản trị viên của ứng dụng/OA. Ở chế độ development, hãy gửi tới số quản trị viên.'),
    -121: ZaloErrorInfo(-121, _template, 'Template không có nội dung.'),
    -130: ZaloErrorInfo(-130, _template, 'Nội dung template vượt quá giới hạn ký tự.'),
    -145: ZaloErrorInfo(-145, _template, 'OA không được phép gửi loại nội dung template này.'),
    -249: ZaloErrorInfo(-249, _template, 'Template này không hỗ trợ gửi qua UID.'),

    // Tham số template
    -111: ZaloErrorInfo(-111, _params, 'Dữ liệu template (template_data) đang trống.'),
    -1121: ZaloErrorInfo(-1121, _params, 'Có tham số template dài quá giới hạn ký tự.'),
    -1122: ZaloErrorInfo(-1122, _params,
        'Thiếu tham số template. Tên tham số trong code phải trùng tên khi đăng ký template.'),
    -1124: ZaloErrorInfo(-1124, _params, 'Có tham số template sai định dạng dữ liệu.'),
    -132: ZaloErrorInfo(-132, _params, 'Tham số template không hợp lệ.'),
    -116: ZaloErrorInfo(-116, _params, 'Nội dung tham số template không hợp lệ.'),
    -122: ZaloErrorInfo(-122, _params, 'Body gửi lên Zalo không đúng định dạng JSON.'),
    -153: ZaloErrorInfo(-153, _params, 'Dữ liệu truyền vào sai quy định của Zalo.'),

    // Hạn mức và số dư
    -115: ZaloErrorInfo(-115, _quota,
        'Tài khoản ZBS không đủ số dư. Nạp thêm tiền vào ZBS Account rồi gửi lại.'),
    -126: ZaloErrorInfo(-126, _quota, 'Ví chế độ development không đủ số dư.'),
    -137: ZaloErrorInfo(-137, _quota,
        'Thanh toán ZBS Account thất bại (ví không đủ số dư). Kiểm tra lại số dư ZBS Account.'),
    -144: ZaloErrorInfo(-144, _quota,
        'OA đã dùng hết hạn mức gửi tin qua số điện thoại trong ngày. Thử lại vào ngày mai.'),
    -147: ZaloErrorInfo(-147, _quota, 'Template này đã hết hạn mức gửi trong ngày.'),
    -1441: ZaloErrorInfo(-1441, _quota, 'OA đã vượt hạn mức tin khuyến mãi trong tháng.'),
    -1471: ZaloErrorInfo(-1471, _quota, 'OA đã vượt giới hạn tin hậu mãi gửi cho người dùng này trong tháng.'),
    -1472: ZaloErrorInfo(-1472, _quota, 'OA đã vượt giới hạn tin khuyến mãi gửi cho người dùng này trong ngày.'),

    // Token
    -124: ZaloErrorInfo(-124, ZaloErrorKind.token,
        'Access token Zalo hết hạn hoặc không hợp lệ và không làm mới được. Quản trị cần lấy refresh token mới.'),

    // Khung giờ
    -133: ZaloErrorInfo(-133, ZaloErrorKind.timeWindow,
        'Loại tin này không được gửi từ 22 giờ đến 7 giờ sáng (giờ Việt Nam). Hệ thống sẽ cần gửi lại sau 7 giờ.'),

    // Cấu hình OA / ứng dụng
    -101: ZaloErrorInfo(-101, _config, 'Ứng dụng Zalo không hợp lệ. Kiểm tra ZALO_APP_ID.'),
    -103: ZaloErrorInfo(-103, _config,
        'Ứng dụng Zalo chưa được kích hoạt. Vào developers.zalo.me và bấm kích hoạt ứng dụng.'),
    -104: ZaloErrorInfo(-104, _config, 'Secret key của ứng dụng Zalo không hợp lệ. Kiểm tra ZALO_SECRET_KEY.'),
    -106: ZaloErrorInfo(-106, _config, 'Phương thức gọi API Zalo không được hỗ trợ.'),
    -120: ZaloErrorInfo(-120, _config, 'OA chưa mua gói dịch vụ cho phép dùng tính năng này.'),
    -125: ZaloErrorInfo(-125, _config, 'ID Official Account không hợp lệ.'),
    -135: ZaloErrorInfo(-135, _config,
        'OA chưa có quyền gửi tin qua số điện thoại (chưa xác thực hoặc đang dùng gói miễn phí).'),
    -1351: ZaloErrorInfo(-1351, _config, 'OA bị hệ thống Zalo chặn gửi tin qua số điện thoại do vi phạm.'),
    -136: ZaloErrorInfo(-136, _config,
        'Ứng dụng chưa liên kết ZBS Account. Liên kết ZBS Account với ứng dụng rồi gửi lại.'),
    -138: ZaloErrorInfo(-138, _config, 'Ứng dụng chưa được duyệt quyền gửi tin qua số điện thoại.'),
    -1381: ZaloErrorInfo(-1381, _config, 'OA chưa cấp quyền dùng ZBS Account cho ứng dụng.'),
    -161: ZaloErrorInfo(-161, _config, 'Giá trị sending_mode không hợp lệ.'),

    // Khác
    -100: ZaloErrorInfo(-100, ZaloErrorKind.unknown,
        'Zalo báo lỗi không xác định. Thử lại sau ít phút.', retryable: true),
  };

  /// Tra cứu mã lỗi. Mã không có trong bảng trả về nhóm [ZaloErrorKind.unknown].
  static ZaloErrorInfo lookup(int code, {String? providerMessage}) {
    final known = _byCode[code];
    if (known != null) return known;
    final suffix = (providerMessage == null || providerMessage.isEmpty) ? '' : ': $providerMessage';
    return ZaloErrorInfo(code, ZaloErrorKind.unknown, 'Zalo trả về lỗi $code$suffix');
  }

  static bool isKnown(int code) => _byCode.containsKey(code);

  static const ZaloErrorInfo network = ZaloErrorInfo(
    0,
    ZaloErrorKind.network,
    'Không kết nối được máy chủ Zalo. Kiểm tra mạng của backend rồi thử lại.',
    retryable: true,
  );

  static ZaloErrorInfo templateNotConfigured(String envVar, String title) => ZaloErrorInfo(
        0,
        ZaloErrorKind.template,
        'Chưa cấu hình template "$title". Điền $envVar trong .env của backend.',
      );

  static ZaloErrorInfo tokenRefreshFailed(String detail) => ZaloErrorInfo(
        -124,
        ZaloErrorKind.token,
        'Không làm mới được access token Zalo ($detail). Refresh token có thể đã hết hạn (3 tháng) '
        'hoặc đã bị dùng. Quản trị cần lấy refresh token mới và cập nhật ZALO_REFRESH_TOKEN.',
      );
}
