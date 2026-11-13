import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../game/game_engine.dart';
import '../online/firestore_game_repository.dart';
import '../online/persistent_device_id.dart';
import '../settings/moderation.dart';
import '../settings/user_profile.dart';

class QuickMatchResult {
  final String roomCode;
  final String deviceId;
  final bool isHost;
  const QuickMatchResult(this.roomCode, this.deviceId, this.isHost);
}

/// A quick-match queue room must be replaced if it disappeared, was closed,
/// or reached its expiry time. Occupied rooms are handled as matches instead.
bool quickMatchRoomNeedsReplacement({
  required bool exists,
  required Map<String, dynamic>? data,
  required DateTime now,
}) {
  if (!exists) return true;
  if (data?['guestDeviceId'] != null) return false;
  if (data?['roomStatus'] != 'waiting') return true;
  final expiry = data?['expiresAt'];
  final createdAt = data?['createdAt'];
  final deadline = expiry is Timestamp
      ? expiry.toDate()
      : createdAt is Timestamp
          ? createdAt.toDate().add(const Duration(minutes: 5))
          : null;
  return deadline != null && !now.isBefore(deadline);
}


/// Eşzamanlı aramalarda yalnızca büyük oda koduna sahip cihaz küçük kodlu
/// odaya katılır. Böylece iki cihaz birbirinin odasına aynı anda misafir olmaz.
bool quickMatchRoomCanBeJoined({
  required String roomCode,
  required String ownRoomCode,
  required String deviceId,
  required Map<String, dynamic> data,
  required DateTime now,
}) {
  final host = data['hostDeviceId'];
  return host is String &&
      host != deviceId &&
      data['quickMatch'] == true &&
      data['roomStatus'] == 'waiting' &&
      data['guestDeviceId'] == null &&
      roomCode.compareTo(ownRoomCode) < 0 &&
      !quickMatchRoomNeedsReplacement(exists: true, data: data, now: now);
}

/// Eşleşmeyi bot maçı boyunca arka planda sürdürür. Bot maçı bitince
/// bulunan rakip döndürülür; bulunamadıysa kendi bekleme odası kapatılır.
class QuickMatchSession {
  final _repo = OnlineRoomRepository();
  String? _deviceId;
  String? _roomCode;
  QuickMatchResult? _match;
  bool _finished = false;
  final Completer<QuickMatchResult?> _matchCompleter = Completer<QuickMatchResult?>();
  Future<void>? _running;

  Future<QuickMatchResult?> get matchFound => _matchCompleter.future;

  void _publishMatch(QuickMatchResult result) {
    _match = result;
    if (!_matchCompleter.isCompleted) _matchCompleter.complete(result);
  }

  Future<void> start() {
    return _running ??= _run();
  }

  Future<void> _run() async {
    try {
      final id = UserProfile.instance.deviceId ?? await getPersistentDeviceId();
      _deviceId = id;
      if (_finished) return;
      // Önce kendi kuyruğumuzu aç. Eşzamanlı aramalarda oda kodu sıralaması
      // yalnızca tek cihazın diğerinin odasına katılmasını sağlar.
      var code = await _createWaitingRoom(id);
      _roomCode = code;
      while (!_finished && _match == null) {
        final room = await _repo.getRoomFromServer(code);
        final data = room.data();
        if (room.exists && data?['guestDeviceId'] != null) {
          _publishMatch(QuickMatchResult(code, id, true));
          break;
        }

        if (quickMatchRoomNeedsReplacement(
          exists: room.exists,
          data: data,
          now: DateTime.now(),
        )) {
          // Bot maçı 5 dakikadan uzun sürerse eski bekleme odası kapanabilir.
          // Eski oda yerine yeni bir kuyruk odası açarak eşleşmeyi sürdür.
          _roomCode = null;
          code = await _createWaitingRoom(id);
          _roomCode = code;
          continue;
        }

        await _tryJoinExisting(id, code);
        if (!_finished && _match == null) {
          await Future<void>.delayed(const Duration(seconds: 2));
        }
      }
    } catch (_) {
      // Ağ hatasında ekranın sonsuza kadar beklemesi yerine kullanıcıya
      // yeniden deneme fırsatı verilir.
      if (!_matchCompleter.isCompleted) _matchCompleter.complete(null);
    }
  }

  Future<String> _createWaitingRoom(String id) {
    final p = UserProfile.instance;
    return _repo.createRoom(
      id,
      hostDisplayName: p.hasProfile ? p.displayName : null,
      hostWinRate: p.hasProfile ? p.onlineWinRate : null,
      hostAvatarIconIndex: p.hasProfile ? p.avatarIconIndex : null,
      hostAvatarColorValue: p.hasProfile ? p.avatarColor.value : null,
      hostPhotoBase64: p.hasProfile ? p.photoBase64 : null,
      quickMatch: true,
    );
  }

  Future<bool> _tryJoinExisting(String id, String ownCode) async {
    // Stream.first can return a stale local cache snapshot. Always query the
    // server so two phones see the same live queue.
    final snap = await _repo.fetchQuickMatchQueue();
    for (final d in snap.docs) {
      final data = d.data();
      final host = data['hostDeviceId'] as String?;
      if (!quickMatchRoomCanBeJoined(
        roomCode: d.id,
        ownRoomCode: ownCode,
        deviceId: id,
        data: data,
        now: DateTime.now(),
      )) continue;
      if (Moderation.instance.isBlocked(host!)) continue;
      final p = UserProfile.instance;
      final joined = await _repo.joinRoom(
        d.id,
        id,
        guestDisplayName: p.hasProfile ? p.displayName : null,
        guestWinRate: p.hasProfile ? p.onlineWinRate : null,
        guestAvatarIconIndex: p.hasProfile ? p.avatarIconIndex : null,
        guestAvatarColorValue: p.hasProfile ? p.avatarColor.value : null,
        guestPhotoBase64: p.hasProfile ? p.photoBase64 : null,
      );
      if (!joined) continue;
      // The match is paired, not started. Both players must explicitly
      // request/accept the start in the shared ready-room UI.
      _publishMatch(QuickMatchResult(d.id, id, false));
      try {
        await _repo.leaveRoom(ownCode, id, isHost: true);
      } catch (_) {}
      _roomCode = null;
      return true;
    }
    return false;
  }

  Future<QuickMatchResult?> finish() async {
    _finished = true;
    if (!_matchCompleter.isCompleted) _matchCompleter.complete(null);
    try { await _running; } catch (_) {}
    final code = _roomCode;
    if (_match == null && code != null && _deviceId != null) {
      try {
        final snap = await _repo.getRoomFromServer(code);
        if (snap.data()?['guestDeviceId'] != null) {
          _publishMatch(QuickMatchResult(code, _deviceId!, true));
        }
      } catch (_) {}
    }
    if (_match == null && code != null) {
      try { await _repo.leaveRoom(code, _deviceId!, isHost: true); } catch (_) {}
    }
    return _match;
  }

  Future<void> cancel() async {
    _finished = true;
    if (!_matchCompleter.isCompleted) _matchCompleter.complete(null);
    try { await _running; } catch (_) {}
    final code = _roomCode;
    if (code != null && _match == null) {
      try { await _repo.leaveRoom(code, _deviceId!, isHost: true); } catch (_) {}
    }
  }
}

/// Quick-match queue rooms are discoverable by other quick-match clients,
/// but are not advertised as ordinary public tables in the manual lobby.
bool quickMatchRoomVisibleInPublicLobby(Map<String, dynamic> data) =>
    data['quickMatch'] != true;
