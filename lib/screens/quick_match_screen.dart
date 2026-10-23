import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../game/game_engine.dart';
import '../online/firestore_game_repository.dart';
import '../online/persistent_device_id.dart';
import '../settings/app_settings.dart';
import '../settings/moderation.dart';
import '../settings/strings.dart';
import '../settings/user_profile.dart';
import 'online_game_screen.dart';
import 'vs_bot_screen.dart';

/// Hızlı Eşleş: taze bir hızlı-eşleş masası varsa ona oturur, yoksa kendi
/// masasını açıp birkaç saniye bekler. Rakip çıkmazsa otomatik olarak bota
/// karşı oyun başlar — lobi boş olsa bile oyuncu hep oynayabilir.
class QuickMatchScreen extends StatefulWidget {
  const QuickMatchScreen({super.key});

  @override
  State<QuickMatchScreen> createState() => _QuickMatchScreenState();
}

class _QuickMatchScreenState extends State<QuickMatchScreen> {
  static const int _searchSeconds = 12;
  static const int _freshSeconds = 90; // saat farkı toleransı dahil

  final _repo = OnlineRoomRepository();
  Timer? _tick;
  Timer? _poll;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _roomSub;
  int _remaining = _searchSeconds;
  String? _myCode;
  bool _done = false;
  bool _polling = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<String> _id() async =>
      UserProfile.instance.deviceId ?? await getPersistentDeviceId();

  void _cancelTimers() {
    _tick?.cancel();
    _poll?.cancel();
    _roomSub?.cancel();
  }

  Future<void> _start() async {
    try {
      final id = await _id();
      if (await _tryJoinExisting(id, null)) return;
      if (_done || !mounted) return;

      final p = UserProfile.instance;
      final code = await _repo.createRoom(
        id,
        hostDisplayName: p.hasProfile ? p.displayName : null,
        hostWinRate: p.hasProfile ? p.onlineWinRate : null,
        hostAvatarIconIndex: p.hasProfile ? p.avatarIconIndex : null,
        hostAvatarColorValue: p.hasProfile ? p.avatarColor.value : null,
        hostPhotoBase64: p.hasProfile ? p.photoBase64 : null,
        quickMatch: true,
      );
      _myCode = code;
      if (_done || !mounted) return;

      _roomSub = _repo.watchRoom(code).listen((snap) {
        final data = snap.data();
        if (data == null || _done) return;
        if (data['guestDeviceId'] != null) _goOnline(code, id, isHost: true);
      }, onError: (_) {});

      // İki oyuncu aynı anda masa açarsa birbirini bulabilsin diye bekleme
      // sırasında da düzenli olarak başkalarının masalarına bakılır.
      _poll = Timer.periodic(const Duration(seconds: 2), (_) async {
        if (_polling || _done) return;
        _polling = true;
        await _tryJoinExisting(id, code);
        _polling = false;
      });

      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || _done) return;
        setState(() => _remaining--);
        if (_remaining <= 0) _fallbackToBot();
      });
    } catch (_) {
      _fallbackToBot();
    }
  }

  /// Taze bir hızlı-eşleş masasına oturmayı dener. [myCode] doluysa (kendi
  /// masamı açıp beklerken) yalnızca KÜÇÜK kodlu masalara katılınır; böylece
  /// iki taraf aynı anda birbirine girmeye çalışmaz.
  Future<bool> _tryJoinExisting(String id, String? myCode) async {
    if (_done) return true;
    try {
      final snap = await _repo.watchOpenTables().first;
      QueryDocumentSnapshot<Map<String, dynamic>>? pick;
      for (final d in snap.docs) {
        final data = d.data();
        final host = data['hostDeviceId'] as String?;
        if (host == null || host == id) continue;
        if (data['quickMatch'] != true) continue;
        if (Moderation.instance.isBlocked(host)) continue;
        final created = data['createdAt'];
        if (created is Timestamp &&
            DateTime.now().difference(created.toDate()).inSeconds >
                _freshSeconds) {
          continue;
        }
        if (myCode != null && d.id.compareTo(myCode) >= 0) continue;
        pick = d;
        break;
      }
      if (pick == null || _done) return false;

      final p = UserProfile.instance;
      final ok = await _repo.joinRoom(
        pick.id,
        id,
        guestDisplayName: p.hasProfile ? p.displayName : null,
        guestWinRate: p.hasProfile ? p.onlineWinRate : null,
        guestAvatarIconIndex: p.hasProfile ? p.avatarIconIndex : null,
        guestAvatarColorValue: p.hasProfile ? p.avatarColor.value : null,
        guestPhotoBase64: p.hasProfile ? p.photoBase64 : null,
      );
      if (!ok || _done) return false;

      // Oyun kendiliğinden başlasın: katılan taraf başlatma isteği gönderir,
      // ev sahibi (hızlı eşleş odası olduğu için) otomatik kabul eder.
      await _repo.requestStart(pick.id, PlayerSide.player2);
      if (myCode != null) {
        try {
          await _repo.leaveRoom(myCode);
        } catch (_) {}
      }
      _goOnline(pick.id, id, isHost: false);
      return true;
    } catch (_) {
      return false;
    }
  }

  void _goOnline(String code, String id, {required bool isHost}) {
    if (_done || !mounted) return;
    _done = true;
    _cancelTimers();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            OnlineGameScreen(roomCode: code, deviceId: id, isHost: isHost),
      ),
    );
  }

  Future<void> _fallbackToBot() async {
    if (_done || !mounted) return;
    final code = _myCode;
    if (code != null) {
      // Son anda biri oturduysa onunla devam et.
      try {
        final snap = await _repo.watchRoom(code).first;
        if (snap.data()?['guestDeviceId'] != null && !_done && mounted) {
          _goOnline(code, await _id(), isHost: true);
          return;
        }
      } catch (_) {}
    }
    if (_done || !mounted) return;
    _done = true;
    _cancelTimers();
    if (code != null) {
      try {
        await _repo.leaveRoom(code);
      } catch (_) {}
    }
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (_) => const VsBotScreen(autoStart: true)),
    );
  }

  @override
  void dispose() {
    _cancelTimers();
    if (!_done && _myCode != null) {
      _repo.leaveRoom(_myCode!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final secs = _remaining < 0 ? 0 : _remaining;
    return Scaffold(
      backgroundColor: AppSettings.instance.themeColor,
      appBar: AppBar(title: Text(t('menu_quick_match'))),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 72,
                  height: 72,
                  child: CircularProgressIndicator(strokeWidth: 5),
                ),
                const SizedBox(height: 28),
                Text(t('qm_searching'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text(
                  t('qm_hint').replaceAll('{n}', '$secs'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _fallbackToBot,
                  icon: const Icon(Icons.smart_toy),
                  label: Text(t('qm_play_bot_now')),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 14),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(t('cancel_request'),
                      style: const TextStyle(color: Colors.white70)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
