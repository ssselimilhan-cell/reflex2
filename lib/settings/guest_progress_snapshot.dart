import 'dart:convert';

import 'ladder.dart';
import 'progress.dart';
import 'user_profile.dart';

/// Versioned, device-independent representation of guest progression.
///
/// This model deliberately contains no device ID or local photo path. It is
/// an export/import boundary only; persistence and account linking are kept
/// separate so a future migration can be transactional and idempotent.
class GuestProgressSnapshot {
  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final String exportedAtUtc;
  final String? displayName;
  final int onlineWins;
  final int onlineLosses;
  final int avatarIconIndex;
  final int avatarColorValue;
  final String? photoBase64;
  final int streakDays;
  final String lastPlayDay;
  final String missionDay;
  final int todayGames;
  final int todayWins;
  final int todayBonuses;
  final int stars;
  final int starsEarned;
  final int starsSpent;
  final int totalWins;
  final bool reviewAsked;
  final List<int> claimedMissionIndexes;
  final int highestClearedLevel;
  final List<int> unlockedCardThemeIndexes;

  const GuestProgressSnapshot({
    this.schemaVersion = currentSchemaVersion,
    required this.exportedAtUtc,
    required this.displayName,
    required this.onlineWins,
    required this.onlineLosses,
    required this.avatarIconIndex,
    required this.avatarColorValue,
    required this.photoBase64,
    required this.streakDays,
    required this.lastPlayDay,
    required this.missionDay,
    required this.todayGames,
    required this.todayWins,
    required this.todayBonuses,
    required this.stars,
    this.starsEarned = 0,
    this.starsSpent = 0,
    required this.totalWins,
    required this.reviewAsked,
    required this.claimedMissionIndexes,
    required this.highestClearedLevel,
    this.unlockedCardThemeIndexes = const [],
  });

  /// Captures the current local profile and progression after app startup has
  /// loaded UserProfile, Progress and LadderProgress.
  factory GuestProgressSnapshot.capture({DateTime? exportedAt}) {
    final profile = UserProfile.instance;
    final progress = Progress.instance;
    final ladder = LadderProgress.instance;
    return GuestProgressSnapshot(
      exportedAtUtc: (exportedAt ?? DateTime.now()).toUtc().toIso8601String(),
      displayName: profile.displayName,
      onlineWins: profile.onlineWins,
      onlineLosses: profile.onlineLosses,
      avatarIconIndex: profile.avatarIconIndex,
      avatarColorValue: profile.avatarColor.value,
      photoBase64: profile.photoBase64,
      streakDays: progress.streakDays,
      lastPlayDay: progress.lastPlayDay,
      missionDay: progress.missionDay,
      todayGames: progress.todayGames,
      todayWins: progress.todayWins,
      todayBonuses: progress.todayBonuses,
      stars: progress.stars,
      starsEarned: progress.starsEarned,
      starsSpent: progress.starsSpent,
      totalWins: progress.totalWins,
      reviewAsked: progress.reviewAsked,
      claimedMissionIndexes: progress.claimed.toList()..sort(),
      highestClearedLevel: ladder.highestCleared,
      unlockedCardThemeIndexes: progress.unlockedCardThemes.toList()..sort(),
    );
  }

  factory GuestProgressSnapshot.empty({DateTime? exportedAt}) {
    return GuestProgressSnapshot(
      exportedAtUtc: (exportedAt ?? DateTime.now()).toUtc().toIso8601String(),
      displayName: null,
      onlineWins: 0,
      onlineLosses: 0,
      avatarIconIndex: 0,
      avatarColorValue: 0xFF0B6E4F,
      photoBase64: null,
      streakDays: 0,
      lastPlayDay: '',
      missionDay: '',
      todayGames: 0,
      todayWins: 0,
      todayBonuses: 0,
      stars: 0,
      starsEarned: 0,
      starsSpent: 0,
      totalWins: 0,
      reviewAsked: false,
      claimedMissionIndexes: const [],
      highestClearedLevel: 0,
      unlockedCardThemeIndexes: const [],
    );
  }

  /// Combines guest and account progress without blindly adding counters:
  /// max values avoid duplicating progress when the same device signs in again.
  static GuestProgressSnapshot merge(
    GuestProgressSnapshot local,
    GuestProgressSnapshot remote,
  ) {
    final localIsNewer = local.missionDay.compareTo(remote.missionDay) > 0;
    final sameDay = local.missionDay == remote.missionDay;
    final daily = localIsNewer ? local : remote;
    final claimed = sameDay
        ? {...local.claimedMissionIndexes, ...remote.claimedMissionIndexes}
        : daily.claimedMissionIndexes.toSet();
    return GuestProgressSnapshot(
      exportedAtUtc: DateTime.now().toUtc().toIso8601String(),
      displayName: (remote.displayName?.trim().isNotEmpty ?? false)
          ? remote.displayName
          : local.displayName,
      onlineWins: local.onlineWins > remote.onlineWins
          ? local.onlineWins : remote.onlineWins,
      onlineLosses: local.onlineLosses > remote.onlineLosses
          ? local.onlineLosses : remote.onlineLosses,
      avatarIconIndex: remote.avatarIconIndex,
      avatarColorValue: remote.avatarColorValue,
      photoBase64: remote.photoBase64 ?? local.photoBase64,
      streakDays: local.streakDays > remote.streakDays
          ? local.streakDays : remote.streakDays,
      lastPlayDay: local.lastPlayDay.compareTo(remote.lastPlayDay) > 0
          ? local.lastPlayDay : remote.lastPlayDay,
      missionDay: local.missionDay.compareTo(remote.missionDay) > 0
          ? local.missionDay : remote.missionDay,
      todayGames: sameDay
          ? (local.todayGames > remote.todayGames ? local.todayGames : remote.todayGames)
          : daily.todayGames,
      todayWins: sameDay
          ? (local.todayWins > remote.todayWins ? local.todayWins : remote.todayWins)
          : daily.todayWins,
      todayBonuses: sameDay
          ? (local.todayBonuses > remote.todayBonuses ? local.todayBonuses : remote.todayBonuses)
          : daily.todayBonuses,
      stars: 0,
      starsEarned: local.starsEarned > remote.starsEarned ? local.starsEarned : remote.starsEarned,
      starsSpent: local.starsSpent > remote.starsSpent ? local.starsSpent : remote.starsSpent,
      totalWins: local.totalWins > remote.totalWins
          ? local.totalWins : remote.totalWins,
      reviewAsked: local.reviewAsked || remote.reviewAsked,
      claimedMissionIndexes: claimed.toList()..sort(),
      highestClearedLevel: local.highestClearedLevel > remote.highestClearedLevel
          ? local.highestClearedLevel : remote.highestClearedLevel,
      unlockedCardThemeIndexes: {...local.unlockedCardThemeIndexes, ...remote.unlockedCardThemeIndexes}.toList()..sort(),
    );
  }

  Future<void> applyToLocal() async {
    await UserProfile.instance.restoreAccountData(
      displayName: displayName,
      onlineWins: onlineWins,
      onlineLosses: onlineLosses,
      avatarIconIndex: avatarIconIndex,
      avatarColorValue: avatarColorValue,
      photoBase64: photoBase64,
    );
    await Progress.instance.restoreAccountData(
      streakDays: streakDays,
      lastPlayDay: lastPlayDay,
      missionDay: missionDay,
      todayGames: todayGames,
      todayWins: todayWins,
      todayBonuses: todayBonuses,
      stars: stars,
      starsEarned: starsEarned,
      starsSpent: starsSpent,
      totalWins: totalWins,
      reviewAsked: reviewAsked,
      claimedMissionIndexes: claimedMissionIndexes,
      unlockedCardThemeIndexes: unlockedCardThemeIndexes,
    );
    await LadderProgress.instance.restoreAccountData(highestClearedLevel);
  }

  String toJson() => jsonEncode(toMap());

  factory GuestProgressSnapshot.fromJson(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Snapshot JSON must contain an object');
    }
    return GuestProgressSnapshot.fromMap(decoded);
  }

  Map<String, dynamic> toMap() => {
        'schemaVersion': schemaVersion,
        'exportedAtUtc': exportedAtUtc,
        'displayName': displayName,
        'onlineWins': onlineWins,
        'onlineLosses': onlineLosses,
        'avatarIconIndex': avatarIconIndex,
        'avatarColorValue': avatarColorValue,
        'photoBase64': photoBase64,
        'streakDays': streakDays,
        'lastPlayDay': lastPlayDay,
        'missionDay': missionDay,
        'todayGames': todayGames,
        'todayWins': todayWins,
        'todayBonuses': todayBonuses,
        'stars': stars,
        'starsEarned': starsEarned,
        'starsSpent': starsSpent,
        'totalWins': totalWins,
        'reviewAsked': reviewAsked,
        'claimedMissionIndexes': List<int>.from(claimedMissionIndexes),
        'highestClearedLevel': highestClearedLevel,
        'unlockedCardThemeIndexes': List<int>.from(unlockedCardThemeIndexes),
      };

  factory GuestProgressSnapshot.fromMap(Map<String, dynamic> map) {
    int integer(String key, {int min = 0, int? max}) {
      final value = map[key];
      if (value is! int || value < min || (max != null && value > max)) {
        throw FormatException('Invalid snapshot field: $key');
      }
      return value;
    }

    String string(String key) {
      final value = map[key];
      if (value is! String) {
        throw FormatException('Invalid snapshot field: $key');
      }
      return value;
    }

    final version = integer('schemaVersion', min: 1);
    if (version != currentSchemaVersion) {
      throw FormatException('Unsupported snapshot version: $version');
    }

    final exportedAt = string('exportedAtUtc');
    if (DateTime.tryParse(exportedAt) == null) {
      throw const FormatException('Invalid snapshot export timestamp');
    }

    final name = map['displayName'];
    if (name != null && (name is! String || name.trim().length > 40)) {
      throw const FormatException('Invalid snapshot display name');
    }
    final photo = map['photoBase64'];
    if (photo != null) {
      if (photo is! String || photo.length > 500000) {
        throw const FormatException('Invalid snapshot avatar data');
      }
      try {
        base64Decode(photo);
      } on FormatException {
        throw const FormatException('Invalid snapshot avatar encoding');
      }
    }

    String day(String key) {
      final value = string(key);
      if (value.isEmpty) return value;
      if (value.length != 10 ||
          value[4] != '-' ||
          value[7] != '-') {
        throw FormatException('Invalid snapshot date: $key');
      }
      final parts = value.split('-');
      if (parts.any((part) => part.isEmpty || int.tryParse(part) == null)) {
        throw FormatException('Invalid snapshot date: $key');
      }
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final date = int.parse(parts[2]);
      final parsed = DateTime.utc(year, month, date);
      if (parsed.year != year ||
          parsed.month != month ||
          parsed.day != date) {
        throw FormatException('Invalid snapshot date: $key');
      }
      return value;
    }

    final rawUnlockedThemes = map['unlockedCardThemeIndexes'] ?? const <int>[];
    if (rawUnlockedThemes is! List || rawUnlockedThemes.any((value) => value is! int || value < 3 || value > 15) || rawUnlockedThemes.toSet().length != rawUnlockedThemes.length) {
      throw const FormatException('Invalid unlocked card themes');
    }
    final rawClaimed = map['claimedMissionIndexes'];
    if (rawClaimed is! List ||
        rawClaimed.any((value) => value is! int || value < 0 || value > 2)) {
      throw const FormatException('Invalid claimed mission indexes');
    }
    final claimed = rawClaimed.cast<int>();
    if (claimed.toSet().length != claimed.length) {
      throw const FormatException('Duplicate claimed mission indexes');
    }

    final wins = integer('todayWins');
    final games = integer('todayGames');
    final bonuses = integer('todayBonuses');
    final onlineWins = integer('onlineWins');
    final onlineLosses = integer('onlineLosses');
    final totalWins = integer('totalWins');
    if (wins > games || totalWins < wins) {
      throw const FormatException('Inconsistent snapshot counters');
    }

    return GuestProgressSnapshot(
      schemaVersion: version,
      exportedAtUtc: exportedAt,
      displayName: name as String?,
      onlineWins: onlineWins,
      onlineLosses: onlineLosses,
      avatarIconIndex: integer('avatarIconIndex', max: 11),
      avatarColorValue: integer('avatarColorValue', max: 0xFFFFFFFF),
      photoBase64: photo as String?,
      streakDays: integer('streakDays'),
      lastPlayDay: day('lastPlayDay'),
      missionDay: day('missionDay'),
      todayGames: games,
      todayWins: wins,
      todayBonuses: bonuses,
      stars: integer('stars'),
      starsEarned: map['starsEarned'] == null ? integer('stars') : integer('starsEarned'),
      starsSpent: map['starsSpent'] == null ? 0 : integer('starsSpent'),
      totalWins: totalWins,
      reviewAsked: map['reviewAsked'] is bool
          ? map['reviewAsked'] as bool
          : throw const FormatException('Invalid snapshot field: reviewAsked'),
      claimedMissionIndexes: List<int>.unmodifiable(claimed),
      highestClearedLevel: integer('highestClearedLevel', max: 100),
      unlockedCardThemeIndexes: List<int>.unmodifiable(rawUnlockedThemes.cast<int>()),
    );
  }
}

