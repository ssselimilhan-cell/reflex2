import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'progress.dart';

/// Bot Yolu ilerlemesi (1-100). Seviyeler sırayla açılır: bir seviyeyi
/// yenince bir sonrakinin kilidi kalkar. Cihazda tutulur.
class LadderProgress extends ChangeNotifier {
  LadderProgress._();
  static final LadderProgress instance = LadderProgress._();

  static const int maxLevel = 100;

  /// Yenilmiş en yüksek seviye (0 = henüz hiçbiri).
  int highestCleared = 0;

  /// Şu an oynanabilecek en yüksek seviye.
  int get unlockedLevel =>
      highestCleared >= maxLevel ? maxLevel : highestCleared + 1;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      highestCleared =
          (prefs.getInt('ld_cleared') ?? 0).clamp(0, maxLevel).toInt();
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('ld_cleared', highestCleared);
    } catch (_) {}
  }

  Future<void> restoreAccountData(int level) async {
    highestCleared = level.clamp(0, maxLevel).toInt();
    await _save();
    notifyListeners();
  }

  /// İlk geçişte kazanılan yıldız: seviye 1-30 → 1, 31-60 → 2, 61-100 → 3;
  /// her 10. seviye (patron) için +5 bonus.
  static int starsForLevel(int level) {
    final base = level <= 30 ? 1 : (level <= 60 ? 2 : 3);
    return base + (level % 10 == 0 ? 5 : 0);
  }

  /// Seviye kazanıldığında çağrılır. İLK KEZ geçildiyse kazanılan yıldız
  /// sayısını, daha önce geçilmiş bir seviyenin tekrarıysa 0 döner.
  int recordWin(int level) {
    var stars = 0;
    if (level == highestCleared + 1 && level <= maxLevel) {
      highestCleared = level;
      stars = starsForLevel(level);
      Progress.instance.addStars(stars);
    }
    _save();
    notifyListeners();
    return stars;
  }
}
