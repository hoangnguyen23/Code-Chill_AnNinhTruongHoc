import 'package:campus_safety_backend/backend.dart';
import 'package:test/test.dart';

void main() {
  test('đủ 4 template với biến môi trường riêng', () {
    expect(ZaloTemplateKey.values.map((k) => k.envVar).toSet(), {
      'ZALO_TEMPLATE_OTP',
      'ZALO_TEMPLATE_REPORT_RECEIVED',
      'ZALO_TEMPLATE_STATUS_UPDATE',
      'ZALO_TEMPLATE_GUARD_ALERT',
    });
  });

  test('tên tham số khớp README', () {
    expect(ZaloTemplateKey.otp.params.map((p) => p.name), ['otp']);
    expect(ZaloTemplateKey.reportReceived.params.map((p) => p.name),
        ['customer_name', 'report_code', 'incident_type', 'location', 'created_time']);
    expect(ZaloTemplateKey.statusUpdate.params.map((p) => p.name),
        ['customer_name', 'report_code', 'status', 'updated_time']);
    expect(ZaloTemplateKey.guardAlert.params.map((p) => p.name),
        ['guard_name', 'report_code', 'incident_type', 'severity', 'location', 'reported_time']);
  });

  test('dữ liệu mẫu nằm trong giới hạn độ dài của Zalo', () {
    for (final key in ZaloTemplateKey.values) {
      for (final p in key.params) {
        expect(p.sample.runes.length, lessThanOrEqualTo(p.maxLength), reason: '${key.wire}.${p.name}');
      }
    }
  });

  group('buildTemplateData', () {
    test('thiếu tham số thì báo tên tham số', () {
      expect(
        () => buildTemplateData(ZaloTemplateKey.statusUpdate, {'customer_name': 'An'}),
        throwsA(isA<TemplateDataException>()
            .having((e) => e.message, 'message', allOf(contains('report_code'), contains('status')))),
      );
    });

    test('bỏ tham số thừa, gộp khoảng trắng', () {
      final data = buildTemplateData(ZaloTemplateKey.otp, {'otp': ' 123456 ', 'extra': 'x'});
      expect(data, {'otp': '123456'});
      final d2 = buildTemplateData(ZaloTemplateKey.guardAlert, {
        ...ZaloTemplateKey.guardAlert.sampleData,
        'location': 'Toà A2\n tầng 3',
      });
      expect(d2['location'], 'Toà A2 tầng 3');
    });

    test('cắt chuỗi quá dài theo loại tham số, giữ dấu tiếng Việt', () {
      final data = buildTemplateData(ZaloTemplateKey.reportReceived, {
        ...ZaloTemplateKey.reportReceived.sampleData,
        'customer_name': 'Nguyễn Thị Phương Thảo Quỳnh Như Bảo Ngọc',
        'location': 'Khu ${'rất ' * 80}xa',
      });
      expect(data['customer_name']!.runes.length, 30);
      expect(data['customer_name'], endsWith('…'));
      expect(data['location']!.runes.length, 200);
    });
  });
}
