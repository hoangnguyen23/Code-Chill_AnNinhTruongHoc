import 'package:campus_safety/features/safety/broadcasts.dart';
import 'package:campus_safety/features/safety/walks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 25, 20);

  test('cảnh báo chỉ hiện khi còn hiệu lực và chưa bị gỡ', () {
    Broadcast make({required bool active, required Duration expiresIn}) => Broadcast.fromJson({
          'id': 'b1',
          'title': 'Mưa bão',
          'body': 'Nghỉ học chiều nay.',
          'level': 'warning',
          'active': active,
          'createdAt': (now.subtract(const Duration(hours: 1))).toUtc().toIso8601String(),
          'expiresAt': (now.add(expiresIn)).toUtc().toIso8601String(),
        });
    expect(make(active: true, expiresIn: const Duration(hours: 2)).isLive(now), isTrue);
    expect(make(active: false, expiresIn: const Duration(hours: 2)).isLive(now), isFalse);
    expect(make(active: true, expiresIn: -const Duration(minutes: 1)).isLive(now), isFalse);
    expect(make(active: true, expiresIn: const Duration(hours: 1)).level, BroadcastLevel.warning);
    expect(BroadcastLevel.fromWire('la'), BroadcastLevel.info);
  });

  test('lượt đi: đọc dữ liệu từ API, tính thời gian còn lại', () {
    final w = Walk.fromJson({
      'id': 'w1',
      'uid': 'u1',
      'displayName': 'Trần Minh Khoa',
      'destination': 'Ký túc xá',
      'startedAt': (now).toUtc().toIso8601String(),
      'dueAt': (now.add(const Duration(minutes: 15))).toUtc().toIso8601String(),
      'status': 'active',
      'lastLatitude': 10.76,
      'lastLongitude': 106.68,
    });
    expect(w.status, WalkStatus.active);
    expect(w.hasLocation, isTrue);
    expect(w.remaining(now.add(const Duration(minutes: 5))), const Duration(minutes: 10));
    expect(w.remaining(now.add(const Duration(minutes: 16))).isNegative, isTrue);
    expect(WalkStatus.fromWire('overdue').label, contains('báo bảo vệ'));
  });
}
