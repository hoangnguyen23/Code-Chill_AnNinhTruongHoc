/// Định nghĩa 4 template ZBS Template Message mà backend sử dụng.
///
/// Tên tham số ở đây PHẢI trùng với tên tham số khi đăng ký template trên ZBS Account
/// (xem README, mục "Đăng ký template"). Độ dài tối đa lấy theo bảng "Danh sách param type"
/// trong tài liệu API Tạo Template của Zalo; giá trị dài hơn sẽ bị cắt để tránh lỗi -1121.
library;

/// Loại tham số Zalo (giá trị `type` khi tạo template) và độ dài tối đa.
enum ZaloParamType {
  customerName(1, 'Tên khách hàng', 30),
  phoneNumber(2, 'Số điện thoại', 15),
  address(3, 'Địa chỉ', 200),
  code(4, 'Mã số', 30),
  customLabel(5, 'Nhãn tùy chỉnh', 30),
  transactionStatus(6, 'Trạng thái giao dịch', 30),
  contactInfo(7, 'Thông tin liên hệ', 50),
  time(11, 'Thời gian', 20),
  otp(12, 'OTP', 10);

  const ZaloParamType(this.zaloType, this.label, this.maxLength);

  final int zaloType;
  final String label;
  final int maxLength;
}

class ZaloParamSpec {
  const ZaloParamSpec(this.name, this.type, this.description, this.sample);

  final String name;
  final ZaloParamType type;
  final String description;
  final String sample;

  int get maxLength => type.maxLength;

  Map<String, Object?> toJson() => {
        'name': name,
        'type': type.zaloType,
        'typeLabel': type.label,
        'maxLength': maxLength,
        'description': description,
        'sample': sample,
      };
}

enum ZaloTemplateKey {
  otp(
    'otp',
    'ZALO_TEMPLATE_OTP',
    'Mã OTP đăng nhập',
    [
      ZaloParamSpec('otp', ZaloParamType.otp, 'Mã 6 chữ số', '482915'),
    ],
  ),
  reportReceived(
    'report_received',
    'ZALO_TEMPLATE_REPORT_RECEIVED',
    'Xác nhận đã nhận báo cáo',
    [
      ZaloParamSpec('customer_name', ZaloParamType.customerName, 'Tên người báo', 'Trần Minh Khoa'),
      ZaloParamSpec('report_code', ZaloParamType.code, 'Mã sự cố', 'SC-261019-K7Q4'),
      ZaloParamSpec('incident_type', ZaloParamType.customLabel, 'Loại sự cố', 'Trộm cắp'),
      ZaloParamSpec('location', ZaloParamType.address, 'Vị trí', 'Toà A2, tầng 3, phòng 305'),
      ZaloParamSpec('created_time', ZaloParamType.time, 'Thời điểm ghi nhận', '14:05 19/10/2026'),
    ],
  ),
  statusUpdate(
    'status_update',
    'ZALO_TEMPLATE_STATUS_UPDATE',
    'Cập nhật trạng thái báo cáo',
    [
      ZaloParamSpec('customer_name', ZaloParamType.customerName, 'Tên người báo', 'Trần Minh Khoa'),
      ZaloParamSpec('report_code', ZaloParamType.code, 'Mã sự cố', 'SC-261019-K7Q4'),
      ZaloParamSpec('status', ZaloParamType.transactionStatus, 'Trạng thái mới', 'Đang xử lý'),
      ZaloParamSpec('updated_time', ZaloParamType.time, 'Thời điểm cập nhật', '14:20 19/10/2026'),
    ],
  ),
  guardAlert(
    'guard_alert',
    'ZALO_TEMPLATE_GUARD_ALERT',
    'Cảnh báo sự cố mới cho bảo vệ',
    [
      ZaloParamSpec('guard_name', ZaloParamType.customerName, 'Tên bảo vệ nhận tin', 'Lê Văn Hùng'),
      ZaloParamSpec('report_code', ZaloParamType.code, 'Mã sự cố', 'SC-261019-K7Q4'),
      ZaloParamSpec('incident_type', ZaloParamType.customLabel, 'Loại sự cố', 'Đánh nhau'),
      ZaloParamSpec('severity', ZaloParamType.customLabel, 'Mức độ', 'Khẩn cấp'),
      ZaloParamSpec('location', ZaloParamType.address, 'Vị trí', 'Sân trường, cổng sau'),
      ZaloParamSpec('reported_time', ZaloParamType.time, 'Thời điểm báo', '14:05 19/10/2026'),
    ],
  );

  const ZaloTemplateKey(this.wire, this.envVar, this.title, this.params);

  /// Khoá dùng trong API và log.
  final String wire;

  /// Biến môi trường chứa template ID.
  final String envVar;
  final String title;
  final List<ZaloParamSpec> params;

  Map<String, String> get sampleData => {for (final p in params) p.name: p.sample};

  static ZaloTemplateKey? tryFromWire(String? wire) {
    for (final k in values) {
      if (k.wire == wire) return k;
    }
    return null;
  }
}

class TemplateDataException implements Exception {
  TemplateDataException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Chuẩn hoá `template_data` trước khi gửi:
/// - bắt buộc đủ tham số, loại bỏ tham số thừa;
/// - gộp khoảng trắng, bỏ xuống dòng;
/// - cắt theo độ dài tối đa của loại tham số (thêm dấu "…" nếu bị cắt).
///
/// Ném [TemplateDataException] (tiếng Việt) nếu thiếu tham số.
Map<String, String> buildTemplateData(ZaloTemplateKey key, Map<String, String> raw) {
  final missing = <String>[];
  final out = <String, String>{};
  for (final p in key.params) {
    final value = raw[p.name]?.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
    if (value.isEmpty) {
      missing.add(p.name);
      continue;
    }
    out[p.name] = truncateForZalo(value, p.maxLength);
  }
  if (missing.isNotEmpty) {
    throw TemplateDataException(
      'Thiếu tham số cho template "${key.title}": ${missing.join(', ')}.',
    );
  }
  return out;
}

/// Cắt chuỗi theo số ký tự (rune), giữ nguyên dấu tiếng Việt.
String truncateForZalo(String value, int maxLength) {
  final runes = value.runes.toList();
  if (runes.length <= maxLength) return value;
  if (maxLength <= 1) return String.fromCharCodes(runes.take(maxLength));
  return '${String.fromCharCodes(runes.take(maxLength - 1))}…';
}
