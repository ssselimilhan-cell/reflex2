import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../online/persistent_device_id.dart';

/// Profil tamamen isteğe bağlıdır — oluşturulmasa da tüm modlar
/// (online dahil) misafir olarak sorunsuz oynanabilir. Profil sadece
/// bir görünen ad ekler ve online kazanma oranını Firestore'da (diğer
/// oyuncuların da görebileceği şekilde) saklar. Misafirken de kazanma
/// oranı YEREL olarak sayılmaya devam eder; profil sonradan oluşturulursa
/// o ana kadarki misafir istatistikleri de profile aktarılır.
class UserProfile extends ChangeNotifier {
  UserProfile._();
  static final UserProfile instance = UserProfile._();

  String? displayName;
  int onlineWins = 0;
  int onlineLosses = 0;
  String? deviceId;

  bool get hasProfile => displayName != null && displayName!.trim().isNotEmpty;

  int get onlineGamesPlayed => onlineWins + onlineLosses;

  /// 0-100 arası yüzde. Hiç oyun oynanmadıysa null.
  double? get onlineWinRate {
    if (onlineGamesPlayed == 0) return null;
    return onlineWins / onlineGamesPlayed * 100;
  }

  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    deviceId = await getPersistentDeviceId();
    try {
      final prefs = await SharedPreferences.getInstance();
      displayName = prefs.getString('displayName');
      onlineWins = prefs.getInt('onlineWins') ?? 0;
      onlineLosses = prefs.getInt('onlineLosses') ?? 0;
    } catch (_) {
      // SharedPreferences kullanılamıyorsa varsayılanlarla devam et.
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persistLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (displayName != null) {
        await prefs.setString('displayName', displayName!);
      } else {
        await prefs.remove('displayName');
      }
      await prefs.setInt('onlineWins', onlineWins);
      await prefs.setInt('onlineLosses', onlineLosses);
    } catch (_) {}
  }

  Future<void> _syncToFirestore() async {
    if (!hasProfile || deviceId == null) return;
    try {
      await FirebaseFirestore.instance.collection('profiles').doc(deviceId).set(
        {
          'displayName': displayName,
          'onlineWins': onlineWins,
          'onlineLosses': onlineLosses,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // Firebase kurulu değilse ya da ağ hatası varsa sessizce yut;
      // yerel istatistikler zaten güvende, bir dahaki senkronizasyonda
      // (bir sonraki sonuç kaydında) tekrar denenir.
    }
  }

  Future<void> createProfile(String name) async {
    displayName = name.trim();
    notifyListeners();
    await _persistLocal();
    await _syncToFirestore();
  }

  Future<void> deleteProfile() async {
    final oldId = deviceId;
    displayName = null;
    notifyListeners();
    await _persistLocal();
    if (oldId != null) {
      try {
        await FirebaseFirestore.instance
            .collection('profiles')
            .doc(oldId)
            .delete();
      } catch (_) {}
    }
  }

  Future<void> recordOnlineResult(bool won) async {
    if (won) {
      onlineWins++;
    } else {
      onlineLosses++;
    }
    notifyListeners();
    await _persistLocal();
    await _syncToFirestore();
  }
}
