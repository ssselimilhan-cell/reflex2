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

/// Eşleşmeyi bot maçı boyunca arka planda sürdürür. Bot maçı bitince
/// bulunan rakip döndürülür; bulunamadıysa kendi bekleme odası kapatılır.
class QuickMatchSession {
  static const _freshSeconds = 90;
  final _repo = OnlineRoomRepository();
  String? _deviceId;
  String? _roomCode;
  QuickMatchResult? _match;
  bool _finished = false;
  Future<void>? _running;

  Future<void> start() {
    return _running ??= _run();
  }

  Future<void> _run() async {
    try {
      final id = UserProfile.instance.deviceId ?? await getPersistentDeviceId();
      _deviceId = id;
      if (_finished) return;
      if (await _tryJoinExisting(id, null)) return;
      if (_finished) return;

      var code = await _createWaitingRoom(id);
      _roomCode = code;
      while (!_finished && _match == null) {
        final room = await _repo.watchRoom(code).first;
        final data = room.data();
        if (room.exists && data?['guestDeviceId'] != null) {
          _match = QuickMatchResult(code, id, true);
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
          if (await _tryJoinExisting(id, null)) return;
          if (_finished) return;
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
      // Ağ sorunu bot maçını engellemez; sadece çevrim içi eşleşme kapanır.
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

  Future<bool> _tryJoinExisting(String id, String? ownCode) async {
    try {
      final snap = await _repo.watchOpenTables().first;
      for (final d in snap.docs) {
        final data = d.data();
        final host = data['hostDeviceId'] as String?;
        if (host == null || host == id || data['quickMatch'] != true) continue;
        if (Moderation.instance.isBlocked(host)) continue;
        final created = data['createdAt'];
        if (created is Timestamp &&
            DateTime.now().difference(created.toDate()).inSeconds > _freshSeconds) {
          continue;
        }
        if (ownCode != null && d.id.compareTo(ownCode) >= 0) continue;
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
        await _repo.requestStart(d.id, PlayerSide.player2);
        if (ownCode != null) {
          try { await _repo.leaveRoom(ownCode, id, isHost: true); } catch (_) {}
          _roomCode = null;
        }
        _match = QuickMatchResult(d.id, id, false);
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<QuickMatchResult?> finish() async {
    _finished = true;
    try { await _running; } catch (_) {}
    final code = _roomCode;
    if (_match == null && code != null && _deviceId != null) {
      try {
        final snap = await _repo.watchRoom(code).first;
        if (snap.data()?['guestDeviceId'] != null) {
          _match = QuickMatchResult(code, _deviceId!, true);
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
    try { await _running; } catch (_) {}
    final code = _roomCode;
    if (code != null && _match == null) {
      try { await _repo.leaveRoom(code, _deviceId!, isHost: true); } catch (_) {}
    }
  }
}
