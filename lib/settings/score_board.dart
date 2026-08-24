import 'package:flutter/material.dart';

/// Oturum boyunca (uygulama kapanana kadar) kalan skor sayaçları.
/// Kalıcı diske kaydedilmez — "oturum boyunca" istendiği için bilerek
/// sadece bellekte tutulur.
class ScoreBoard extends ChangeNotifier {
  ScoreBoard._();
  static final ScoreBoard instance = ScoreBoard._();

  int localP1 = 0;
  int localP2 = 0;
  int youVsBot = 0;
  int botVsYou = 0;
  int onlineYou = 0;
  int onlineOpp = 0;

  void addLocal(bool p1Won) {
    if (p1Won) {
      localP1++;
    } else {
      localP2++;
    }
    notifyListeners();
  }

  void addBot(bool youWon) {
    if (youWon) {
      youVsBot++;
    } else {
      botVsYou++;
    }
    notifyListeners();
  }

  void addOnline(bool youWon) {
    if (youWon) {
      onlineYou++;
    } else {
      onlineOpp++;
    }
    notifyListeners();
  }

  void resetLocal() {
    localP1 = 0;
    localP2 = 0;
    notifyListeners();
  }

  void resetBot() {
    youVsBot = 0;
    botVsYou = 0;
    notifyListeners();
  }

  void resetOnline() {
    onlineYou = 0;
    onlineOpp = 0;
    notifyListeners();
  }
}
