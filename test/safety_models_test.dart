import 'package:campus_safety/features/safety/broadcasts.dart';
import 'package:campus_safety/features/safety/walks.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 25, 20);

  test('cảnh báo chỉ hiện khi còn hiệu lực và chưa bị gỡ', () {
    Broadcast make({required bool active, required Duration expiresIn}) => Broadcast.fromMap('b1', {
          'title': 'Mưa bão',
          'body': 'Nghỉ học chiều nay.',
          'level': 'warning',
          'active': active,
          'createdAt': Timestamp.fromDate(now.subtract(const Duration(hours: 1))),
          'expiresAt': Timestamp.fromDate(now.add(expiresIn)),
        });
    expect(make(active: true, expiresIn: const Duration(hours: 2)).isLive(now), isTrue);
    expect(make(active: false, expiresIn: const Duration(hours: 2)).isLive(now), isFalse);
    expect(make(active: true, expiresIn: -const Duration(minutes: 1)).isLive(now), isFalse);
    expect(make(active: true, expiresIn: const Duration(hours: 1)).level, BroadcastLevel.warning);
    expect(BroadcastLevel.fromWire('la'), BroadcastLevel.info);
  });

  test('lượt đi: đọc dữ liệu Firestore, tính thời gian còn lại', () {
    final w = Walk.fromMap('w1', {
      'uid': 'u1',
      'displayName': 'Trần Minh Khoa',
      'destination': 'Ký túc xá',
      'startedAt': Timestamp.fromDate(now),
      'dueAt': Timestamp.fromDate(now.add(const Duration(minutes: 15))),
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
