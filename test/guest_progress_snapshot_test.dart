import 'package:flutter_test/flutter_test.dart';
import 'package:stres_kart/settings/guest_progress_snapshot.dart';

GuestProgressSnapshot sampleSnapshot() => const GuestProgressSnapshot(
      exportedAtUtc: '2026-11-10T09:00:00.000Z',
      displayName: 'Guest Player',
      onlineWins: 12,
      onlineLosses: 4,
      avatarIconIndex: 3,
      avatarColorValue: 0xFF3B82F6,
      photoBase64: null,
      streakDays: 5,
      lastPlayDay: '2026-11-10',
      missionDay: '2026-11-10',
      todayGames: 3,
      todayWins: 2,
      todayBonuses: 1,
      stars: 27,
      totalWins: 42,
      reviewAsked: true,
      claimedMissionIndexes: [0, 1],
      highestClearedLevel: 18,
    );

void main() {
  group('GuestProgressSnapshot', () {
    test('round-trips every transferable progression field', () {
      final original = sampleSnapshot();
      final restored = GuestProgressSnapshot.fromMap(original.toMap());

      expect(restored.toMap(), original.toMap());
    });

    test('does not include device-specific identity or photo path', () {
      final map = sampleSnapshot().toMap();

      expect(map.containsKey('deviceId'), isFalse);
      expect(map.containsKey('persistentDeviceId'), isFalse);
      expect(map.containsKey('photoPath'), isFalse);
    });

    test('rejects unsupported schema versions', () {
      final map = sampleSnapshot().toMap()..['schemaVersion'] = 99;

      expect(
        () => GuestProgressSnapshot.fromMap(map),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects impossible daily counters', () {
      final map = sampleSnapshot().toMap()..['todayWins'] = 4;

      expect(
        () => GuestProgressSnapshot.fromMap(map),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects duplicate or unknown claimed mission indexes', () {
      final duplicate = sampleSnapshot().toMap()
        ..['claimedMissionIndexes'] = [1, 1];
      final unknown = sampleSnapshot().toMap()
        ..['claimedMissionIndexes'] = [3];

      expect(
        () => GuestProgressSnapshot.fromMap(duplicate),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => GuestProgressSnapshot.fromMap(unknown),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects negative counters and invalid avatar indexes', () {
      final negative = sampleSnapshot().toMap()..['stars'] = -1;
      final avatar = sampleSnapshot().toMap()..['avatarIconIndex'] = 12;

      expect(
        () => GuestProgressSnapshot.fromMap(negative),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => GuestProgressSnapshot.fromMap(avatar),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
