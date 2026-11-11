import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reflex2/screens/quick_match_session.dart';

void main() {
  group('quickMatchRoomNeedsReplacement', () {
    final now = DateTime(2026, 11, 11, 12);

    test('keeps a fresh waiting room', () {
      expect(
        quickMatchRoomNeedsReplacement(
          exists: true,
          data: {
            'roomStatus': 'waiting',
            'expiresAt': Timestamp.fromDate(now.add(const Duration(minutes: 2))),
          },
          now: now,
        ),
        isFalse,
      );
    });

    test('replaces a waiting room after its expiry', () {
      expect(
        quickMatchRoomNeedsReplacement(
          exists: true,
          data: {
            'roomStatus': 'waiting',
            'expiresAt': Timestamp.fromDate(now.subtract(const Duration(seconds: 1))),
          },
          now: now,
        ),
        isTrue,
      );
    });

    test('uses the five-minute fallback when expiresAt is absent', () {
      expect(
        quickMatchRoomNeedsReplacement(
          exists: true,
          data: {
            'roomStatus': 'waiting',
            'createdAt': Timestamp.fromDate(now.subtract(const Duration(minutes: 6))),
          },
          now: now,
        ),
        isTrue,
      );
    });

    test('replaces a cancelled room', () {
      expect(
        quickMatchRoomNeedsReplacement(
          exists: true,
          data: {'roomStatus': 'cancelled'},
          now: now,
        ),
        isTrue,
      );
    });

    test('does not replace a room that already has an opponent', () {
      expect(
        quickMatchRoomNeedsReplacement(
          exists: true,
          data: {'roomStatus': 'ready', 'guestDeviceId': 'opponent'},
          now: now,
        ),
        isFalse,
      );
    });

    test('replaces a missing room document', () {
      expect(
        quickMatchRoomNeedsReplacement(
          exists: false,
          data: null,
          now: now,
        ),
        isTrue,
      );
    });
  });
}
