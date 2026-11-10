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
  final int totalWins;
  final bool reviewAsked;
  final List<int> claimedMissionIndexes;
  final int highestClearedLevel;

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
    required this.totalWins,
    required this.reviewAsked,
    required this.claimedMissionIndexes,
    required this.highestClearedLevel,
  });

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
        'totalWins': totalWins,
        'reviewAsked': reviewAsked,
        'claimedMissionIndexes': List<int>.from(claimedMissionIndexes),
        'highestClearedLevel': highestClearedLevel,
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
    if (photo != null && (photo is! String || photo.length > 500000)) {
      throw const FormatException('Invalid snapshot avatar data');
    }

    String day(String key) {
      final value = string(key);
      if (value.isNotEmpty &&
          !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
        throw FormatException('Invalid snapshot date: $key');
      }
      return value;
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
    if (wins > games) {
      throw const FormatException('Daily wins cannot exceed daily games');
    }

    return GuestProgressSnapshot(
      schemaVersion: version,
      exportedAtUtc: exportedAt,
      displayName: name as String?,
      onlineWins: integer('onlineWins'),
      onlineLosses: integer('onlineLosses'),
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
      totalWins: integer('totalWins'),
      reviewAsked: map['reviewAsked'] is bool
          ? map['reviewAsked'] as bool
          : throw const FormatException('Invalid snapshot field: reviewAsked'),
      claimedMissionIndexes: List<int>.unmodifiable(claimed),
      highestClearedLevel: integer('highestClearedLevel', max: 100),
    );
  }
}
