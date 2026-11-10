import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'strings.dart';
import 'telemetry.dart';

/// Uygulama genelinde SnackBar gösterebilmek için (görev tamamlanınca).
final GlobalKey<ScaffoldMessengerState> rootMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class Mission {
  final String titleKey;
  final int target;
  const Mission(this.titleKey, this.target);
}

/// Günlük seri (art arda kaç gün oynandı), günlük görevler ve toplanan
/// yıldızlar. Tamamen cihazda tutulur.
class Progress extends ChangeNotifier {
  Progress._();
  static final Progress instance = Progress._();

  static const List<Mission> missions = [
    Mission('mission_play3', 3),
    Mission('mission_win1', 1),
    Mission('mission_bonus1', 1),
  ];

  int streakDays = 0;
  String lastPlayDay = '';
  String missionDay = '';
  int todayGames = 0;
  int todayWins = 0;
  int todayBonuses = 0;
  int stars = 0;
  int starsEarned = 0;
  int starsSpent = 0;
  int totalWins = 0;
  bool reviewAsked = false;
  final Set<int> claimed = {};
  final Set<int> unlockedCardThemes = {}; // eski sürümlerle uyumluluk
  final Set<String> unlockedCardThemeIds = {}; // dinamik katalog temaları

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  static String _today() => _fmt(DateTime.now());
  static String _yesterday() =>
      _fmt(DateTime.now().subtract(const Duration(days: 1)));

  /// Serinin şu an ekranda gösterilecek değeri (dün de oynanmadıysa 0).
  int get activeStreak =>
      (lastPlayDay == _today() || lastPlayDay == _yesterday()) ? streakDays : 0;

  bool get _isToday => missionDay == _today();

  int get doneToday => _isToday ? claimed.length : 0;

  bool isClaimed(int i) => _isToday && claimed.contains(i);

  int missionValue(int i) {
    if (!_isToday) return 0;
    final v = switch (i) {
      0 => todayGames,
      1 => todayWins,
      _ => todayBonuses,
    };
    return v > missions[i].target ? missions[i].target : v;
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      streakDays = prefs.getInt('pg_streak') ?? 0;
      lastPlayDay = prefs.getString('pg_lastDay') ?? '';
      missionDay = prefs.getString('pg_missionDay') ?? '';
      todayGames = prefs.getInt('pg_games') ?? 0;
      todayWins = prefs.getInt('pg_wins') ?? 0;
      todayBonuses = prefs.getInt('pg_bonuses') ?? 0;
      stars = prefs.getInt('pg_stars') ?? 0;
      starsEarned = prefs.getInt('pg_starsEarned') ?? stars;
      starsSpent = prefs.getInt('pg_starsSpent') ?? 0;
      stars = (starsEarned > starsSpent) ? starsEarned - starsSpent : 0;
      totalWins = prefs.getInt('pg_totalWins') ?? 0;
      reviewAsked = prefs.getBool('pg_reviewAsked') ?? false;
      unlockedCardThemes
        ..clear()
        ..addAll((prefs.getStringList('pg_unlockedCardThemes') ?? const <String>[])
            .map(int.tryParse).whereType<int>().where((i) => i >= 3 && i < 16));
      unlockedCardThemeIds
        ..clear()
        ..addAll(prefs.getStringList('pg_unlockedCardThemeIds') ?? const <String>[]);
      claimed
        ..clear()
        ..addAll((prefs.getStringList('pg_claimed') ?? const <String>[])
            .map(int.tryParse)
            .whereType<int>());
    } catch (_) {}
    notifyListeners();
  }

  Future<void> restoreAccountData({
    required int streakDays,
    required String lastPlayDay,
    required String missionDay,
    required int todayGames,
    required int todayWins,
    required int todayBonuses,
    required int stars,
    int? starsEarned,
    int starsSpent = 0,
    required int totalWins,
    required bool reviewAsked,
    required List<int> claimedMissionIndexes,
    List<int> unlockedCardThemeIndexes = const [],
    List<String> unlockedCardThemeIds = const [],
  }) async {
    this.streakDays = streakDays;
    this.lastPlayDay = lastPlayDay;
    this.missionDay = missionDay;
    this.todayGames = todayGames;
    this.todayWins = todayWins;
    this.todayBonuses = todayBonuses;
    this.starsEarned = starsEarned ?? stars;
    this.starsSpent = starsSpent;
    this.stars = this.starsEarned > this.starsSpent
        ? this.starsEarned - this.starsSpent : 0;
    this.totalWins = totalWins;
    this.reviewAsked = reviewAsked;
    claimed
      ..clear()
      ..addAll(claimedMissionIndexes);
    unlockedCardThemes
      ..clear()
      ..addAll(unlockedCardThemeIndexes.where((i) => i >= 3 && i < 16));
    this.unlockedCardThemeIds
      ..clear()
      ..addAll(unlockedCardThemeIds);
    await _persist();
    notifyListeners();
  }

  bool isCardThemeUnlocked(int index) => index < 3 || unlockedCardThemes.contains(index);

  bool isCatalogThemeUnlocked(String id, int legacyStyleIndex) =>
      unlockedCardThemeIds.contains(id) ||
      (id == 'card_theme_$legacyStyleIndex' && isCardThemeUnlocked(legacyStyleIndex));

  bool purchaseCatalogTheme(String id, int legacyStyleIndex, int price) {
    if (id.isEmpty || price <= 0 || isCatalogThemeUnlocked(id, legacyStyleIndex) || stars < price) return false;
    starsSpent += price;
    stars = starsEarned > starsSpent ? starsEarned - starsSpent : 0;
    unlockedCardThemeIds.add(id);
    _persist();
    notifyListeners();
    Telemetry.log('star_shop_purchase', {'item': id, 'price': price});
    return true;
  }

  bool purchaseCardTheme(int index, int price) {
    if (price <= 0 || index < 3 || index >= 16 || isCardThemeUnlocked(index) || stars < price) return false;
    starsSpent += price;
    stars = starsEarned > starsSpent ? starsEarned - starsSpent : 0;
    unlockedCardThemes.add(index);
    _persist();
    notifyListeners();
    Telemetry.log('star_shop_purchase', {'item': 'card_theme_$index', 'price': price});
    return true;
  }

  /// Dışarıdan (ör. Bot Yolu) yıldız eklemek için.
  void addStars(int n) {
    if (n <= 0) return;
    stars += n;
    starsEarned += n;
    _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('pg_streak', streakDays);
      await prefs.setString('pg_lastDay', lastPlayDay);
      await prefs.setString('pg_missionDay', missionDay);
      await prefs.setInt('pg_games', todayGames);
      await prefs.setInt('pg_wins', todayWins);
      await prefs.setInt('pg_bonuses', todayBonuses);
      await prefs.setInt('pg_stars', stars);
      await prefs.setInt('pg_starsEarned', starsEarned);
      await prefs.setInt('pg_starsSpent', starsSpent);
      await prefs.setInt('pg_totalWins', totalWins);
      await prefs.setBool('pg_reviewAsked', reviewAsked);
      await prefs.setStringList('pg_unlockedCardThemes',
          unlockedCardThemes.map((e) => '$e').toList()..sort());
      await prefs.setStringList('pg_unlockedCardThemeIds', unlockedCardThemeIds.toList()..sort());
      await prefs.setStringList(
          'pg_claimed', claimed.map((e) => '$e').toList());
    } catch (_) {}
  }

  /// Gün değiştiyse günlük sayaçları sıfırlar.
  void _rollover() {
    final today = _today();
    if (missionDay != today) {
      missionDay = today;
      todayGames = 0;
      todayWins = 0;
      todayBonuses = 0;
      claimed.clear();
    }
  }

  /// Bir oyun bittiğinde çağrılır.
  void recordGame({required bool won, String mode = 'other'}) {
    _rollover();
    final today = _today();
    if (lastPlayDay != today) {
      streakDays = (lastPlayDay == _yesterday()) ? streakDays + 1 : 1;
      lastPlayDay = today;
    }
    todayGames++;
    if (won) {
      todayWins++;
      totalWins++;
    }
    Telemetry.log('game_end', {'mode': mode, 'won': won});
    _checkMissions();
    _maybeAskReview();
    _persist();
    notifyListeners();
  }

  /// 3. galibiyette (yalnızca bir kez) Play Store yorum penceresini açar.
  void _maybeAskReview() {
    if (reviewAsked || totalWins < 3) return;
    reviewAsked = true;
    Telemetry.log('review_prompt');
    Future.delayed(const Duration(seconds: 3), () async {
      try {
        final review = InAppReview.instance;
        if (await review.isAvailable()) await review.requestReview();
      } catch (_) {}
    });
  }

  /// Oyuncu bir art arda hamle avantajı kazandığında çağrılır.
  void recordStreakBonus() {
    _rollover();
    todayBonuses++;
    Telemetry.log('streak_bonus');
    _checkMissions();
    _persist();
    notifyListeners();
  }

  void _checkMissions() {
    for (var i = 0; i < missions.length; i++) {
      if (claimed.contains(i)) continue;
      final v = switch (i) {
        0 => todayGames,
        1 => todayWins,
        _ => todayBonuses,
      };
      if (v >= missions[i].target) {
        claimed.add(i);
        stars++;
        starsEarned++;
        rootMessengerKey.currentState?.showSnackBar(SnackBar(
          content:
              Text('⭐ ${t('mission_done')}: ${t(missions[i].titleKey)}'),
        ));
      }
    }
  }
}
