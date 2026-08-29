import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { tr, en, ru, zh }

/// Kartların ortasındaki baskın sembolün teması.
enum CardTheme { classic, fruit, figure }

/// Tüm uygulamada paylaşılan, kalıcı (SharedPreferences ile diske
/// kaydedilen) ayarlar. Herhangi bir ekran değiştirdiğinde, buna
/// abone olan (AnimatedBuilder ile dinleyen) tüm ekranlar anında
/// güncellenir.
class AppSettings extends ChangeNotifier {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  double cardScale = 1.5; // 0.7 - 2.2 (varsayılan %150)
  double fontScale = 1.0; // 0.8 - 1.6
  Color themeColor = const Color(0xFF0B6E4F);
  Color cardBackColor = const Color(0xFF1E4D8C);
  double animationSpeed = 1.0; // 0.5 hızlı, 1.0 normal, 1.6 yavaş
  bool highContrast = true; // varsayılan açık
  AppLanguage language = AppLanguage.tr;
  CardTheme cardTheme = CardTheme.classic; // varsayılan iskambil

  static const List<Color> presetColors = [
    Color(0xFF0B6E4F), // yeşil (varsayılan)
    Color(0xFF1E4D8C), // mavi
    Color(0xFF7B1E3A), // bordo
    Color(0xFF4A148C), // mor
    Color(0xFF263238), // antrasit
    Color(0xFFB35A00), // turuncu-kahve
  ];

  static const List<Color> cardBackPresets = [
    Color(0xFF1E4D8C), // mavi
    Color(0xFF5D1049), // bordo-mor
    Color(0xFF1B5E20), // koyu yeşil
    Color(0xFF212121), // siyah
    Color(0xFFB71C1C), // kırmızı
  ];

  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      cardScale = prefs.getDouble('cardScale') ?? 1.5;
      fontScale = prefs.getDouble('fontScale') ?? 1.0;
      animationSpeed = prefs.getDouble('animationSpeed') ?? 1.0;
      highContrast = prefs.getBool('highContrast') ?? true;
      final colorValue = prefs.getInt('themeColor');
      if (colorValue != null) themeColor = Color(colorValue);
      final backValue = prefs.getInt('cardBackColor');
      if (backValue != null) cardBackColor = Color(backValue);
      final lang = prefs.getString('language');
      switch (lang) {
        case 'en':
          language = AppLanguage.en;
          break;
        case 'ru':
          language = AppLanguage.ru;
          break;
        case 'zh':
          language = AppLanguage.zh;
          break;
        case 'tr':
          language = AppLanguage.tr;
          break;
        // null ya da bilinmeyen değer: varsayılan (tr) kalır.
      }
      final themeIndex = prefs.getInt('cardTheme');
      if (themeIndex != null &&
          themeIndex >= 0 &&
          themeIndex < CardTheme.values.length) {
        cardTheme = CardTheme.values[themeIndex];
      }
    } catch (_) {
      // SharedPreferences kullanılamıyorsa varsayılanlarla devam et.
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('cardScale', cardScale);
      await prefs.setDouble('fontScale', fontScale);
      await prefs.setDouble('animationSpeed', animationSpeed);
      await prefs.setBool('highContrast', highContrast);
      await prefs.setInt('themeColor', themeColor.value);
      await prefs.setInt('cardBackColor', cardBackColor.value);
      await prefs.setString('language', switch (language) {
        AppLanguage.en => 'en',
        AppLanguage.ru => 'ru',
        AppLanguage.zh => 'zh',
        AppLanguage.tr => 'tr',
      });
      await prefs.setInt('cardTheme', cardTheme.index);
    } catch (_) {}
  }

  void setCardTheme(CardTheme t) {
    cardTheme = t;
    notifyListeners();
    _persist();
  }

  void setCardScale(double v) {
    cardScale = v;
    notifyListeners();
    _persist();
  }

  void setFontScale(double v) {
    fontScale = v;
    notifyListeners();
    _persist();
  }

  void setThemeColor(Color c) {
    themeColor = c;
    notifyListeners();
    _persist();
  }

  void setCardBackColor(Color c) {
    cardBackColor = c;
    notifyListeners();
    _persist();
  }

  void setAnimationSpeed(double v) {
    animationSpeed = v;
    notifyListeners();
    _persist();
  }

  void setHighContrast(bool v) {
    highContrast = v;
    notifyListeners();
    _persist();
  }

  void setLanguage(AppLanguage l) {
    language = l;
    notifyListeners();
    _persist();
  }
}
