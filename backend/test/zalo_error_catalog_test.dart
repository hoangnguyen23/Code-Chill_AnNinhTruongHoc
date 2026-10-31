import 'package:campus_safety_backend/backend.dart';
import 'package:test/test.dart';

void main() {
  group('ZaloErrorCatalog: 6 nhóm lỗi bắt buộc hiển thị tiếng Việt', () {
    void expectKind(int code, ZaloErrorKind kind, String text) {
      final info = ZaloErrorCatalog.lookup(code);
      expect(info.kind, kind, reason: 'mã $code');
      expect(info.code, code);
      expect(info.message, contains(text), reason: 'mã $code');
    }

    test('số không có tài khoản Zalo', () {
      expectKind(-118, ZaloErrorKind.recipient, 'chưa có tài khoản Zalo');
      expectKind(-108, ZaloErrorKind.recipient, 'không hợp lệ');
    });

    test('template chưa duyệt hoặc sai ID', () {
      expectKind(-131, ZaloErrorKind.template, 'chưa được Zalo duyệt');
      expectKind(-109, ZaloErrorKind.template, 'Template ID không hợp lệ');
      expectKind(-117, ZaloErrorKind.template, 'chưa được quyền dùng template');
      expectKind(-127, ZaloErrorKind.template, 'quản trị viên');
    });

    test('hết quota hoặc hết số dư', () {
      expectKind(-115, ZaloErrorKind.quota, 'không đủ số dư');
      expectKind(-144, ZaloErrorKind.quota, 'hạn mức');
      expectKind(-147, ZaloErrorKind.quota, 'hạn mức');
      expectKind(-137, ZaloErrorKind.quota, 'số dư');
    });

    test('token hết hạn', () {
      expectKind(-124, ZaloErrorKind.token, 'Access token');
      final refreshFailed = ZaloErrorCatalog.tokenRefreshFailed('mã -14014: invalid');
      expect(refreshFailed.kind, ZaloErrorKind.token);
      expect(refreshFailed.message, contains('ZALO_REFRESH_TOKEN'));
      expect(refreshFailed.message, contains('-14014'));
    });

    test('gửi ngoài khung giờ cho phép', () {
      expectKind(-133, ZaloErrorKind.timeWindow, '22 giờ đến 7 giờ');
    });

    test('sai tham số template', () {
      expectKind(-1121, ZaloErrorKind.templateParams, 'dài quá');
      expectKind(-1122, ZaloErrorKind.templateParams, 'Thiếu tham số');
      expectKind(-1124, ZaloErrorKind.templateParams, 'sai định dạng');
      expectKind(-132, ZaloErrorKind.templateParams, 'không hợp lệ');
    });
  });

  test('cấu hình OA/ứng dụng', () {
    for (final code in [-101, -103, -104, -135, -136, -138]) {
      expect(ZaloErrorCatalog.lookup(code).kind, ZaloErrorKind.configuration, reason: 'mã $code');
    }
  });

  test('mã lạ vẫn có thông báo kèm mã và thông điệp gốc', () {
    final info = ZaloErrorCatalog.lookup(-98765, providerMessage: 'Something new');
    expect(info.kind, ZaloErrorKind.unknown);
    expect(info.message, contains('-98765'));
    expect(info.message, contains('Something new'));
    expect(ZaloErrorCatalog.isKnown(-98765), isFalse);
  });

  test('chỉ lỗi tạm thời mới được đánh dấu thử lại', () {
    expect(ZaloErrorCatalog.lookup(-100).retryable, isTrue);
    expect(ZaloErrorCatalog.network.retryable, isTrue);
    expect(ZaloErrorCatalog.lookup(-118).retryable, isFalse);
    expect(ZaloErrorCatalog.lookup(-115).retryable, isFalse);
  });

  test('không thông báo nào chứa gạch ngang dài', () {
    for (final code in [-108, -109, -115, -118, -124, -131, -133, -1122, -144, -100]) {
      expect(ZaloErrorCatalog.lookup(code).message, isNot(contains('—')));
    }
  });
}
