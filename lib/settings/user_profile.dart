import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../online/persistent_device_id.dart';

/// Avatar olarak seçilebilecek sabit ikon listesi — profil fotoğrafı
/// yoksa (ya da rakibin fotoğrafı yüklenemezse) bu ikon+renk kombinasyonu
/// yedek olarak gösterilir.
const List<IconData> kAvatarIcons = [
  Icons.person,
  Icons.face,
  Icons.emoji_emotions,
  Icons.pets,
  Icons.sports_esports,
  Icons.sports_soccer,
  Icons.music_note,
  Icons.rocket_launch,
  Icons.star,
  Icons.favorite,
  Icons.bolt,
  Icons.anchor,
];

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
  int avatarIconIndex = 0;
  Color avatarColor = const Color(0xFF0B6E4F);

  /// Galeriden seçilen gerçek fotoğrafın cihazdaki kalıcı dosya yolu —
  /// bu cihazda hızlı/yüksek kaliteli gösterim için kullanılır.
  String? photoPath;

  /// Aynı fotoğrafın küçük, sıkıştırılmış base64 hâli — Firestore'a
  /// (profil dokümanına) senkronize edilir, böylece profili olan diğer
  /// oyuncular da (lobide, online oyun ekranında) bu fotoğrafı görebilir.
  String? photoBase64;

  bool get hasProfile => displayName != null && displayName!.trim().isNotEmpty;

  int get onlineGamesPlayed => onlineWins + onlineLosses;

  /// 0-100 arası yüzde. Hiç oyun oynanmadıysa null.
  double? get onlineWinRate {
    if (onlineGamesPlayed == 0) return null;
    return onlineWins / onlineGamesPlayed * 100;
  }

  bool _loaded = false;
  String? _activeUid;
  int _activationGeneration = 0;

  String _key(String name, [String? uid]) =>
      uid == null ? name : 'account_${uid}_$name';

  Future<void> _readLocal({String? uid, bool preserveCurrentIfMissing = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString(_key('displayName', uid));
      if (name != null || !preserveCurrentIfMissing) {
        displayName = name;
        onlineWins = prefs.getInt(_key('onlineWins', uid)) ?? 0;
        onlineLosses = prefs.getInt(_key('onlineLosses', uid)) ?? 0;
        avatarIconIndex = prefs.getInt(_key('avatarIconIndex', uid)) ?? 0;
        final color = prefs.getInt(_key('avatarColor', uid));
        avatarColor = color == null ? const Color(0xFF0B6E4F) : Color(color);
        photoPath = prefs.getString(_key('photoPath', uid));
        photoBase64 = prefs.getString(_key('photoBase64', uid));
      }
    } catch (_) {}
  }

  Future<void> load() async {
    if (_loaded) return;
    deviceId = await getPersistentDeviceId();
    _activeUid = FirebaseAuth.instance.currentUser?.uid;
    await _readLocal(uid: _activeUid);
    _loaded = true;
    notifyListeners();
  }

  /// Firebase hesabına ait oyuncu profilini yükler. İlk girişte cihazdaki
  /// misafir takma adı başlangıç önerisi olarak hesaba kopyalanır; sonraki
  /// cihazlarda hesabın bulut profili esas alınır.
  Future<void> activateAccountProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final generation = ++_activationGeneration;
    deviceId ??= await getPersistentDeviceId();
    final cameFromGuest = _activeUid == null;
    final prefs = await SharedPreferences.getInstance();
    final hasAccountLocal = prefs.containsKey(_key('displayName', user.uid)) ||
        prefs.containsKey(_key('onlineWins', user.uid));
    // Uygulamanın önceki sürümünde kullanıcı zaten oturum açmış olabilir;
    // hesap-özel anahtarlar yoksa eski yerel profilini bir defaya mahsus taşı.
    final migrateLegacyGuest = cameFromGuest ||
        (_activeUid == user.uid && !hasAccountLocal);
    final guestName = migrateLegacyGuest
        ? (cameFromGuest ? displayName : prefs.getString('displayName'))
        : null;
    final guestWins = migrateLegacyGuest
        ? (cameFromGuest ? onlineWins : (prefs.getInt('onlineWins') ?? 0))
        : 0;
    final guestLosses = migrateLegacyGuest
        ? (cameFromGuest ? onlineLosses : (prefs.getInt('onlineLosses') ?? 0))
        : 0;
    await _readLocal(uid: user.uid, preserveCurrentIfMissing: migrateLegacyGuest);
    try {
      final ref = FirebaseFirestore.instance
          .collection('users').doc(user.uid)
          .collection('private').doc('profile');
      final snap = await ref.get().timeout(const Duration(seconds: 6));
      if (generation != _activationGeneration ||
          FirebaseAuth.instance.currentUser?.uid != user.uid) return;
      if (snap.exists) {
        final data = snap.data()!;
        displayName = data['displayName'] as String?;
        onlineWins = (data['onlineWins'] as num?)?.toInt() ?? 0;
        onlineLosses = (data['onlineLosses'] as num?)?.toInt() ?? 0;
        avatarIconIndex = (data['avatarIconIndex'] as num?)?.toInt() ?? 0;
        avatarColor = Color((data['avatarColor'] as num?)?.toInt() ?? 0xFF0B6E4F);
        // Older account documents may predate photoBase64. Retain the
        // account-scoped local image in that case; explicit null still clears it.
        if (data.containsKey('photoBase64')) {
          photoBase64 = data['photoBase64'] as String?;
          if (photoBase64 == null) photoPath = null;
        }
      } else {
        displayName ??= guestName;
        if (onlineWins == 0 && onlineLosses == 0) {
          onlineWins = guestWins;
          onlineLosses = guestLosses;
        }
        await ref.set(_accountProfileMap()).timeout(const Duration(seconds: 6));
      }
      if (generation != _activationGeneration ||
          FirebaseAuth.instance.currentUser?.uid != user.uid) return;
      await _persistLocal(accountUid: user.uid);
      if (generation != _activationGeneration ||
          FirebaseAuth.instance.currentUser?.uid != user.uid) return;
      await _syncPublicProfile().timeout(const Duration(seconds: 4));
    } catch (_) {
      // Oturum açma başarılı kalır; yerel hesap profili kullanılmaya devam eder.
      if (generation == _activationGeneration &&
          FirebaseAuth.instance.currentUser?.uid == user.uid) {
        await _persistLocal(accountUid: user.uid);
      }
    }
    if (generation != _activationGeneration ||
        FirebaseAuth.instance.currentUser?.uid != user.uid) return;
    _activeUid = user.uid;
    notifyListeners();
  }

  /// Çıkışta hesaba ait profil cihazın misafir profilinin üzerine yazılmaz.
  Future<void> activateGuestProfile() async {
    ++_activationGeneration;
    _activeUid = null;
    await _readLocal();
    try {
      await _syncPublicProfile().timeout(const Duration(seconds: 2));
    } catch (_) {}
    notifyListeners();
  }

  Map<String, dynamic> _accountProfileMap() => {
    'displayName': displayName,
    'onlineWins': onlineWins,
    'onlineLosses': onlineLosses,
    'avatarIconIndex': avatarIconIndex,
    'avatarColor': avatarColor.value,
    'photoBase64': photoBase64,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  Future<void> _persistLocal({String? accountUid}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = accountUid ?? FirebaseAuth.instance.currentUser?.uid;
      if (displayName != null) {
        await prefs.setString(_key('displayName', uid), displayName!);
      } else {
        await prefs.remove(_key('displayName', uid));
      }
      await prefs.setInt(_key('onlineWins', uid), onlineWins);
      await prefs.setInt(_key('onlineLosses', uid), onlineLosses);
      await prefs.setInt(_key('avatarIconIndex', uid), avatarIconIndex);
      await prefs.setInt(_key('avatarColor', uid), avatarColor.value);
      if (photoPath != null) {
        await prefs.setString(_key('photoPath', uid), photoPath!);
      } else {
        await prefs.remove(_key('photoPath', uid));
      }
      if (photoBase64 != null) {
        await prefs.setString(_key('photoBase64', uid), photoBase64!);
      } else {
        await prefs.remove(_key('photoBase64', uid));
      }
    } catch (_) {}
  }

  Future<void> _syncPublicProfile() async {
    if (!hasProfile || deviceId == null) return;
    await FirebaseFirestore.instance.collection('profiles').doc(deviceId).set(
      {
        'displayName': displayName,
        'onlineWins': onlineWins,
        'onlineLosses': onlineLosses,
        'avatarIconIndex': avatarIconIndex,
        'avatarColor': avatarColor.value,
        'photoBase64': photoBase64,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> _syncToFirestore() async {
    if (!hasProfile || deviceId == null) return;
    try {
      await _syncPublicProfile().timeout(const Duration(seconds: 5));
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid)
            .collection('private').doc('profile').set(_accountProfileMap())
            .timeout(const Duration(seconds: 5));
      }
    } catch (_) {
      // Yerel profil korunur; sonraki profil güncellemesinde tekrar denenir.
    }
  }

  Future<void> createProfile(String name) async {
    displayName = name.trim();
    notifyListeners();
    await _persistLocal();
    await _syncToFirestore();
  }

  Future<void> setAvatar(int iconIndex, Color color) async {
    avatarIconIndex = iconIndex;
    avatarColor = color;
    photoPath = null; // ikon seçilince önceki foto iptal olur
    photoBase64 = null;
    notifyListeners();
    await _persistLocal();
    await _syncToFirestore();
  }

  /// [path] cihazdaki kalıcı dosya yolu, [base64Data] ise Firestore'a
  /// gönderilecek küçük/sıkıştırılmış hâli.
  Future<void> setPhoto(String path, String base64Data) async {
    photoPath = path;
    photoBase64 = base64Data;
    notifyListeners();
    await _persistLocal();
    await _syncToFirestore();
  }

  Future<void> clearPhoto() async {
    photoPath = null;
    photoBase64 = null;
    notifyListeners();
    await _persistLocal();
    await _syncToFirestore();
  }

  Future<void> restoreAccountData({
    required String? displayName,
    required int onlineWins,
    required int onlineLosses,
    required int avatarIconIndex,
    required int avatarColorValue,
    required String? photoBase64,
  }) async {
    this.displayName = displayName;
    this.onlineWins = onlineWins;
    this.onlineLosses = onlineLosses;
    this.avatarIconIndex = avatarIconIndex;
    avatarColor = Color(avatarColorValue);
    this.photoBase64 = photoBase64;
    photoPath = null;
    notifyListeners();
    await _persistLocal();
    await _syncToFirestore();
  }

  Future<void> deleteProfile() async {
    final oldId = deviceId;
    displayName = null;
    photoPath = null;
    photoBase64 = null;
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
