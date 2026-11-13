import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stres_kart/online/firestore_game_repository.dart';

void main() {
  group('waitingRoomDeadline', () {
    test('uses expiresAt when present', () {
      final expiry = DateTime(2026, 11, 13, 12);
      final deadline = waitingRoomDeadline({
        'expiresAt': Timestamp.fromDate(expiry),
        'createdAt': Timestamp.fromDate(DateTime(2026, 11, 13, 10)),
      });
      expect(deadline, expiry);
    });

    test('falls back to createdAt plus five minutes for older rooms', () {
      final created = DateTime(2026, 11, 13, 12);
      expect(
        waitingRoomDeadline({'createdAt': Timestamp.fromDate(created)}),
        created.add(const Duration(minutes: 5)),
      );
    });

    test('returns null when legacy room has no usable timestamps', () {
      expect(waitingRoomDeadline({'createdAt': null, 'expiresAt': null}), isNull);
    });
  });
}
