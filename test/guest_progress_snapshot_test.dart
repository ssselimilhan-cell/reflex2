import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stres_kart/settings/guest_progress_snapshot.dart';
import 'package:stres_kart/settings/ladder.dart';
import 'package:stres_kart/settings/progress.dart';
import 'package:stres_kart/settings/user_profile.dart';

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
      unlockedCardThemeIds: ['theme_ottoman_2026', 'theme_egypt_alt'],
    );

void main() {
  group('GuestProgressSnapshot', () {
    test('round-trips every transferable progression field', () {
      final original = sampleSnapshot();
      final restored = GuestProgressSnapshot.fromMap(original.toMap());

      expect(restored.toMap(), original.toMap());
    });

    test('round-trips through JSON for portable backup transport', () {
      final original = sampleSnapshot();

      final restored = GuestProgressSnapshot.fromJson(original.toJson());

      expect(restored.toMap(), original.toMap());
    });

    test('rejects JSON that is not a snapshot object', () {
      expect(
        () => GuestProgressSnapshot.fromJson('[1, 2, 3]'),
        throwsA(isA<FormatException>()),
      );
    });

    test('captures all local guest progression after startup', () {
      final profile = UserProfile.instance
        ..displayName = 'Local Player'
        ..onlineWins = 8
        ..onlineLosses = 2
        ..avatarIconIndex = 4
        ..avatarColor = const Color(0xFF3B82F6)
        ..photoBase64 = 'YWJj';
      final progress = Progress.instance;
      progress
        ..streakDays = 6
        ..lastPlayDay = '2026-11-10'
        ..missionDay = '2026-11-10'
        ..todayGames = 4
        ..todayWins = 2
        ..todayBonuses = 1
        ..stars = 31
        ..totalWins = 50
        ..reviewAsked = true;
      progress.claimed
        ..clear()
        ..addAll([0, 2]);
      LadderProgress.instance.highestCleared = 21;

      final snapshot = GuestProgressSnapshot.capture(
        exportedAt: DateTime.utc(2026, 11, 10),
      );

      expect(snapshot.displayName, 'Local Player');
      expect(snapshot.onlineWins, 8);
      expect(snapshot.onlineLosses, 2);
      expect(snapshot.avatarIconIndex, 4);
      expect(snapshot.photoBase64, 'YWJj');
      expect(snapshot.streakDays, 6);
      expect(snapshot.todayGames, 4);
      expect(snapshot.todayWins, 2);
      expect(snapshot.todayBonuses, 1);
      expect(snapshot.stars, 31);
      expect(snapshot.totalWins, 50);
      expect(snapshot.claimedMissionIndexes, [0, 2]);
      expect(snapshot.highestClearedLevel, 21);
      expect(snapshot.toMap()['exportedAtUtc'], '2026-11-10T00:00:00.000Z');

      // Keep the analyzer aware that the singleton is intentionally mutated
      // here as a test fixture rather than a persistence operation.
      expect(profile.hasProfile, isTrue);
      expect(progress.claimed, containsAll([0, 2]));
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

    test('rejects malformed dates and avatar image encoding', () {
      final impossibleDate = sampleSnapshot().toMap()
        ..['lastPlayDay'] = '2026-02-30';
      final invalidPhoto = sampleSnapshot().toMap()
        ..['photoBase64'] = 'not-base64!';

      expect(
        () => GuestProgressSnapshot.fromMap(impossibleDate),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => GuestProgressSnapshot.fromMap(invalidPhoto),
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

    test('merges account and guest progress without double-counting', () {
      final local = sampleSnapshot().toMap()
        ..['onlineWins'] = 8
        ..['stars'] = 12
        ..['highestClearedLevel'] = 18;
      final remote = sampleSnapshot().toMap()
        ..['onlineWins'] = 5
        ..['stars'] = 20
        ..['highestClearedLevel'] = 25
        ..['unlockedCardThemeIds'] = ['theme_persia'];
      final merged = GuestProgressSnapshot.merge(
        GuestProgressSnapshot.fromMap(local),
        GuestProgressSnapshot.fromMap(remote),
      );
      expect(merged.onlineWins, 8);
      expect(merged.stars, 20);
      expect(merged.highestClearedLevel, 25);
      expect(merged.unlockedCardThemeIds, containsAll(['theme_ottoman_2026', 'theme_egypt_alt', 'theme_persia']));
    });

    test('creates an empty snapshot for a different account', () {
      final empty = GuestProgressSnapshot.empty();
      expect(empty.onlineWins, 0);
      expect(empty.stars, 0);
      expect(empty.highestClearedLevel, 0);
      expect(empty.displayName, isNull);
    });
  });
}
