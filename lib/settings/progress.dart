import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'strings.dart';

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
  final Set<int> claimed = {};

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
      claimed
        ..clear()
        ..addAll((prefs.getStringList('pg_claimed') ?? const <String>[])
            .map(int.tryParse)
            .whereType<int>());
    } catch (_) {}
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
  void recordGame({required bool won}) {
    _rollover();
    final today = _today();
    if (lastPlayDay != today) {
      streakDays = (lastPlayDay == _yesterday()) ? streakDays + 1 : 1;
      lastPlayDay = today;
    }
    todayGames++;
    if (won) todayWins++;
    _checkMissions();
    _persist();
    notifyListeners();
  }

  /// Oyuncu bir art arda hamle avantajı kazandığında çağrılır.
  void recordStreakBonus() {
    _rollover();
    todayBonuses++;
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
        rootMessengerKey.currentState?.showSnackBar(SnackBar(
          content:
              Text('⭐ ${t('mission_done')}: ${t(missions[i].titleKey)}'),
        ));
      }
    }
  }
}
