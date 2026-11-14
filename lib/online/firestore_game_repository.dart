import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../settings/guest_progress_snapshot.dart';
import '../game/game_engine.dart';
import 'swiss_tournament.dart';

/// Bekleme odaları için tek süre hesabı: yeni kayıtlarda expiresAt,
/// eski kayıtlarda createdAt + 5 dakika kullanılır.
DateTime? waitingRoomDeadline(Map<String, dynamic> data) {
  final storedExpiry = data['expiresAt'];
  if (storedExpiry is Timestamp) return storedExpiry.toDate();
  final createdAt = data['createdAt'];
  if (createdAt is Timestamp) {
    return createdAt.toDate().add(const Duration(minutes: 5));
  }
  return null;
}

/// Bir online oyun odasının Firestore üzerindeki temsili.
/// Koleksiyon: "rooms", döküman id'si 4 haneli okunabilir bir kod (örn "AB12").
class OnlineRoomRepository {
  final _rooms = FirebaseFirestore.instance.collection('rooms');

  String _generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // I,O,0,1 çıkarıldı
    final rnd = Random();
    return List.generate(4, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  /// Yeni oda oluşturur, oyunu deler ama "waiting" durumda tutar;
  /// ikinci oyuncu katılınca "ready" olur. Ev sahibinin profil bilgisi
  /// (varsa) odaya damgalanır — lobide diğer oyuncular bunu görüp ona
  /// göre karşısına oturabilsin diye.
  Future<String> createRoom(
    String hostDeviceId, {
    String? hostDisplayName,
    double? hostWinRate,
    int? hostAvatarIconIndex,
    int? hostAvatarColorValue,
    String? hostPhotoBase64,
    bool quickMatch = false,
    String? inviteToDeviceId,
    String? tournamentChannelId,
    String? tournamentId,
    String? tournamentMatchId,
  }) async {
    final engine = GameEngine()..startNewGame();
    String code = _generateRoomCode();

    var attempts = 0;
    while ((await _rooms.doc(code).get()).exists && attempts < 5) {
      code = _generateRoomCode();
      attempts++;
    }

    await _rooms.doc(code).set({
      'hostDeviceId': hostDeviceId,
      'guestDeviceId': null,
      'roomStatus': 'waiting', // waiting | ready | start_requested | active | finished
      'hostDisplayName': hostDisplayName,
      'hostWinRate': hostWinRate,
      'hostAvatarIconIndex': hostAvatarIconIndex,
      'hostAvatarColorValue': hostAvatarColorValue,
      'hostPhotoBase64': hostPhotoBase64,
      'quickMatch': quickMatch,
      'inviteToDeviceId': inviteToDeviceId,
      'inviteJoinRewarded': false,
      if (tournamentChannelId != null) 'tournamentChannelId': tournamentChannelId,
      if (tournamentId != null) 'tournamentId': tournamentId,
      if (tournamentMatchId != null) 'tournamentMatchId': tournamentMatchId,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 5))),
      ...engine.toMap(),
    });

    return code;
  }

  /// Davet edilen kişi bu masaya ilk kez katıldığında davet sahibine
  /// 30 yıldız verir. Firestore transaction aynı ödülün iki kez yazılmasını önler.
  Future<bool> claimInviteJoinReward(String code, String hostDeviceId) async {
    final ref = _rooms.doc(code);
    return FirebaseFirestore.instance.runTransaction<bool>((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return false;
      final data = snap.data()!;
      final invitee = data['inviteToDeviceId'] as String?;
      if (data['hostDeviceId'] != hostDeviceId ||
          invitee == null ||
          invitee.isEmpty ||
          data['guestDeviceId'] != invitee ||
          data['inviteJoinRewarded'] == true) {
        return false;
      }
      tx.update(ref, {
        'inviteJoinRewarded': true,
        'inviteJoinRewardedAt': FieldValue.serverTimestamp(),
      });
      return true;
    });
  }

  /// Lobide gösterilecek, henüz ikinci oyuncu beklemeyen açık masalar.
  /// Sıralama (kazanma oranına göre) İSTEMCİ tarafında yapılır — bu
  /// sayede misafirlerin (oran=null) sona düşmesi kolayca kontrol
  /// edilebiliyor ve fazladan bir composite index gerekmiyor.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchOpenTables() {
    return _rooms
        .where('roomStatus', isEqualTo: 'waiting')
        // Avoid a composite-index dependency; lobby sorts the returned docs locally.
        .limit(100)
        .snapshots()
        .map((snapshot) {
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final deadline = waitingRoomDeadline(data);
            if (deadline != null && !DateTime.now().isBefore(deadline)) {
              unawaited(expireWaitingRoom(doc.id));
            }
          }
          return snapshot;
        });
  }

  /// Five minutes without an opponent closes a waiting table. Safe to call
  /// repeatedly from the lobby and the room screen; the transaction is idempotent.
  Future<bool> expireWaitingRoom(String code) async {
    final ref = _rooms.doc(code);
    return FirebaseFirestore.instance.runTransaction<bool>((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return false;
      final data = snap.data()!;
      final deadline = waitingRoomDeadline(data);
      if (data['roomStatus'] != 'waiting' || deadline == null ||
          DateTime.now().isBefore(deadline)) {
        return false;
      }
      tx.update(ref, {
        'roomStatus': 'cancelled',
        'cancelledBy': 'system_timeout',
        'cancelledReason': 'waiting_timeout',
        'cancelledAt': FieldValue.serverTimestamp(),
      });
      return true;
    });
  }

  Future<bool> joinRoom(
    String code,
    String guestDeviceId, {
    String? guestDisplayName,
    double? guestWinRate,
    int? guestAvatarIconIndex,
    int? guestAvatarColorValue,
    String? guestPhotoBase64,
  }) async {
    final ref = _rooms.doc(code);
    return FirebaseFirestore.instance.runTransaction<bool>((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return false;
      final data = snap.data()!;
      if (data['roomStatus'] != 'waiting') return false;

      // Süresi dolmuş oda, lobideki temizlik zamanlayıcısından önce de
      // katılıma kapalı olmalı. Kontrol ve iptal aynı transaction içindedir.
      final deadline = waitingRoomDeadline(data);
      if (deadline != null && !DateTime.now().isBefore(deadline)) {
        tx.update(ref, {
          'roomStatus': 'cancelled',
          'cancelledBy': 'system_timeout',
          'cancelledReason': 'waiting_timeout',
          'cancelledAt': FieldValue.serverTimestamp(),
        });
        return false;
      }
      if (data['guestDeviceId'] != null) return false;
      // Name-invited tables are private: only the exact invited device may
      // take the guest seat, even if another player discovers the room code.
      final invitedDeviceId = data['inviteToDeviceId'] as String?;
      if (invitedDeviceId != null && invitedDeviceId != guestDeviceId) {
        return false;
      }
      if (data['tournamentMatchId'] is String &&
          invitedDeviceId != guestDeviceId) return false;

      // NOT: Katılan oyuncu direkt oyunu başlatmaz — "ready" durumuna
      // geçer, oyun ancak taraflardan biri başlatıp diğeri kabul edince
      // ("start_requested" -> "active") başlar.
      tx.update(ref, {
        'guestDeviceId': guestDeviceId,
        'expiresAt': null,
        // Joining a room only reserves the seat. Every mode uses the same
        // two-player confirmation: ready -> start_requested -> active.
        'roomStatus': data['tournamentMatchId'] is String ? 'active' : 'ready',
        'guestDisplayName': guestDisplayName,
        'guestWinRate': guestWinRate,
        'guestAvatarIconIndex': guestAvatarIconIndex,
        'guestAvatarColorValue': guestAvatarColorValue,
        'guestPhotoBase64': guestPhotoBase64,
      });
      return true;
    });
  }

  /// Bir taraf oyunu başlatmak ister. Sadece "ready" durumunda geçerlidir.
  Future<bool> requestStart(String code, PlayerSide side, String deviceId) async {
    final ref = _rooms.doc(code);
    return FirebaseFirestore.instance.runTransaction<bool>((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return false;
      final data = snap.data()!;
      final seatedDevice = side == PlayerSide.player1
          ? data['hostDeviceId'] as String?
          : data['guestDeviceId'] as String?;
      if (data['roomStatus'] != 'ready' || seatedDevice != deviceId ||
          data['hostDeviceId'] == null || data['guestDeviceId'] == null) return false;

      tx.update(ref, {
        'roomStatus': 'start_requested',
        'startRequestedBy': side.name,
      });
      return true;
    });
  }

  /// Karşı taraf başlatma isteğini kabul eder — oyun gerçekten başlar.
  Future<bool> acceptStart(String code, PlayerSide acceptingSide, String deviceId) async {
    final ref = _rooms.doc(code);
    return FirebaseFirestore.instance.runTransaction<bool>((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return false;
      final data = snap.data()!;
      final acceptingDevice = acceptingSide == PlayerSide.player1
          ? data['hostDeviceId'] as String?
          : data['guestDeviceId'] as String?;
      if (data['roomStatus'] != 'start_requested' || acceptingDevice != deviceId ||
          data['startRequestedBy'] == acceptingSide.name ||
          data['hostDeviceId'] == null || data['guestDeviceId'] == null) return false;

      tx.update(ref, {'roomStatus': 'active'});
      return true;
    });
  }

  /// Başlatma isteği reddedilir ya da istekte bulunan iptal eder —
  /// "ready" durumuna geri döner.
  Future<void> cancelStart(String code) async {
    final ref = _rooms.doc(code);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data()!;
      if (data['roomStatus'] != 'start_requested') return;
      tx.update(ref, {'roomStatus': 'ready', 'startRequestedBy': null});
    });
  }

  /// Hızlı eşleşme kuyruğunu doğrudan sunucudan okur. Stream.first eski
  /// yerel önbelleği döndürüp uzak cihazın bekleme odasını kaçırabilir.
  Future<QuerySnapshot<Map<String, dynamic>>> fetchQuickMatchQueue() {
    return _rooms
        .where('quickMatch', isEqualTo: true)
        .get(const GetOptions(source: Source.server));
  }

  /// Bekleme odasının sunucudaki güncel durumunu okur.
  Future<DocumentSnapshot<Map<String, dynamic>>> getRoomFromServer(String code) {
    return _rooms.doc(code).get(const GetOptions(source: Source.server));
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchRoom(String code) {
    return _rooms.doc(code).snapshots();
  }

  /// Bir kolona tıklama isteğini transaction içinde uygular: başka bir
  /// cihaz aynı anda hamle yapmışsa en güncel durumu okuyup kurallara göre
  /// tekrar doğrular, böylece çakışma oluşmaz.
  Future<bool> attemptPlay({
    required String code,
    required PlayerSide side,
    required int columnIndex,
  }) async {
    final ref = _rooms.doc(code);
    return FirebaseFirestore.instance.runTransaction<bool>((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return false;
      final data = snap.data()!;
      if (data['roomStatus'] != 'active') return false;

      final engine = GameEngine()..loadFromMap(data);
      final ok = engine.attemptPlay(side, columnIndex);
      if (!ok) return false;

      final gameUpdate = engine.toMap();
      if (engine.status != GameStatus.playing) {
        final retentionDays = data['tournamentMatchId'] is String ? 30 : 1;
        gameUpdate['expiresAt'] = Timestamp.fromDate(
          DateTime.now().add(Duration(days: retentionDays)),
        );
      }
      tx.update(ref, gameUpdate);
      return true;
    });
  }

  /// Kilitlenme (aktif kolon kalmadığında) sonrası toplama + yeniden
  /// dağıtımı uygular. Sadece host (Oyuncu 1 tarafı) tetikler, böylece
  /// iki cihaz aynı anda çift toplama yapmaz.
  Future<void> attemptCollectAndRedeal(String code) async {
    final ref = _rooms.doc(code);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data()!;
      if (data['roomStatus'] != 'active') return;

      final engine = GameEngine()..loadFromMap(data);
      if (!engine.isDeadlocked) return;
      engine.collectAndRedeal();
      tx.update(ref, engine.toMap());
    });
  }

  /// Oyun bittikten sonra bir taraf tekrar oynamak ister — bu doğrudan
  /// başlamaz, karşı tarafın kabul etmesi gerekir (bkz. acceptRematch).
  /// Sadece oyun gerçekten bitmişken ve zaten bekleyen bir istek yokken
  /// çalışır.
  Future<bool> requestRematch(String code, PlayerSide side) async {
    final ref = _rooms.doc(code);
    return FirebaseFirestore.instance.runTransaction<bool>((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return false;
      final data = snap.data()!;
      if (data['roomStatus'] != 'active') return false;
      if (data['rematchRequestedBy'] != null) return false;

      final engine = GameEngine()..loadFromMap(data);
      if (engine.status == GameStatus.playing) return false; // henüz bitmemiş

      tx.update(ref, {'rematchRequestedBy': side.name});
      return true;
    });
  }

  /// Karşı taraf tekrar oynama isteğini kabul eder — yeni deste karılıp
  /// dağıtılır, oda "active" durumda kalır (odadan çıkılmadan devam eder).
  Future<bool> acceptRematch(String code) async {
    final ref = _rooms.doc(code);
    return FirebaseFirestore.instance.runTransaction<bool>((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return false;
      final data = snap.data()!;
      if (data['rematchRequestedBy'] == null) return false;

      final engine = GameEngine()..loadFromMap(data);
      engine.startNewGame();
      final map = engine.toMap();
      map['rematchRequestedBy'] = null;
      map['expiresAt'] = null;
      tx.update(ref, map);
      return true;
    });
  }

  /// İstek reddedilir ya da isteği yapan kendisi iptal eder.
  Future<void> declineRematch(String code) async {
    final ref = _rooms.doc(code);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data()!;
      if (data['rematchRequestedBy'] == null) return;
      tx.update(ref, {'rematchRequestedBy': null});
    });
  }

  /// Odadan açıkça ayrılma işlemi. Ev sahibi odayı iptal eder;
  /// misafir oyun başlamadan ayrılırsa masa yeniden beklemeye açılır.
  /// Ekranın dispose edilmesi veya geri tuşu bu metodu çağırmaz.
  Future<void> leaveRoom(
    String code,
    String deviceId, {
    required bool isHost,
  }) async {
    final ref = _rooms.doc(code);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data()!;
      final status = data['roomStatus'] as String? ?? 'finished';

      if (isHost) {
        if (data['hostDeviceId'] != deviceId) return;
        final gameFinished = (data['status'] as String? ?? 'playing') != 'playing';
        final retentionDays = data['tournamentMatchId'] is String ? 30 : 1;
        tx.update(ref, {
          'roomStatus': gameFinished ? 'finished' : 'cancelled',
          if (gameFinished) 'hostLeftAt': FieldValue.serverTimestamp(),
          if (!gameFinished) 'cancelledBy': deviceId,
          if (!gameFinished) 'cancelledAt': FieldValue.serverTimestamp(),
          'startRequestedBy': null,
          'rematchRequestedBy': null,
          'expiresAt': Timestamp.fromDate(DateTime.now().add(Duration(days: gameFinished ? retentionDays : 1))),
        });
        return;
      }

      if (data['guestDeviceId'] != deviceId) return;
      final gameHasStarted = status == 'active' || status == 'finished';
      if (gameHasStarted) {
        tx.update(ref, {
          'roomStatus': 'finished',
          'guestLeftAt': FieldValue.serverTimestamp(),
          'expiresAt': Timestamp.fromDate(DateTime.now().add(Duration(
            days: data['tournamentMatchId'] is String ? 30 : 1,
          ))),
        });
      } else {
        tx.update(ref, {
          'guestDeviceId': null,
          'guestDisplayName': null,
          'guestWinRate': null,
          'guestAvatarIconIndex': null,
          'guestAvatarColorValue': null,
          'guestPhotoBase64': null,
          'roomStatus': 'waiting',
          'startRequestedBy': null,
          'rematchRequestedBy': null,
          'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 5))),
        });
      }
    });
  }

  // ---- Sohbet ----

  CollectionReference<Map<String, dynamic>> _messagesRef(String code) =>
      _rooms.doc(code).collection('room_messages');

  Future<void> sendMessage(String code, PlayerSide side, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    await _messagesRef(code).add({
      'sender': side.name,
      'text': trimmed,
      'sentAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 7))),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchMessages(String code) {
    return _messagesRef(code).orderBy('sentAt').snapshots();
  }

  /// Oyundan çıkılınca sohbet geçmişini siler.
  Future<void> clearMessages(String code) async {
    try {
      final snap = await _messagesRef(code).get();
      if (snap.docs.isEmpty) return;
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (_) {
      // Ağ hatası vb. olursa sessizce geç — mesajlar bir sonraki oda
      // oluşturulduğunda zaten yeni bir alt koleksiyonda başlar.
    }
  }

  // ---- Doğrudan oyuncu davetleri (lobideki oyuncu listesinden) ----

  CollectionReference<Map<String, dynamic>> get _invites =>
      FirebaseFirestore.instance.collection('invites');

  /// [toDeviceId]'ye, [roomCode] odasına gelmesi için bir davet gönderir.
  /// Gönderenin profil bilgisi davetin içine gömülür ki alıcı, kimin
  /// davet ettiğini (ismi, avatarı, kazanma oranı) görebilsin.
  Future<String> sendInvite({
    required String toDeviceId,
    required String fromDeviceId,
    required String roomCode,
    String? fromDisplayName,
    int? fromAvatarIconIndex,
    int? fromAvatarColorValue,
    String? fromPhotoBase64,
    double? fromWinRate,
    String? inviteType,
    String? tournamentChannelId,
    String? tournamentId,
    String? tournamentMatchId,
  }) async {
    final inviteRef = await _invites.add({
      'toDeviceId': toDeviceId,
      'fromDeviceId': fromDeviceId,
      'roomCode': roomCode,
      'fromDisplayName': fromDisplayName,
      'fromAvatarIconIndex': fromAvatarIconIndex,
      'fromAvatarColorValue': fromAvatarColorValue,
      'fromPhotoBase64': fromPhotoBase64,
      'fromWinRate': fromWinRate,
      if (inviteType != null) 'inviteType': inviteType,
      if (tournamentChannelId != null) 'tournamentChannelId': tournamentChannelId,
      if (tournamentId != null) 'tournamentId': tournamentId,
      if (tournamentMatchId != null) 'tournamentMatchId': tournamentMatchId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 5))),
    });
    return inviteRef.id;
  }

  /// Bu cihaza gelen, henüz kapatılmamış davetleri dinler.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchIncomingInvites(
      String myDeviceId) {
    return _invites
        .where('toDeviceId', isEqualTo: myDeviceId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
          for (final doc in snapshot.docs) {
            final createdAt = doc.data()['createdAt'];
            if (createdAt is Timestamp &&
                DateTime.now().difference(createdAt.toDate()) >= const Duration(minutes: 5)) {
              unawaited(closeInvite(doc.id));
            }
          }
          return snapshot;
        });
  }

  /// Davet kabul edilsin ya da reddedilsin/kapatılsın, listeden kalkması
  /// için siliniyor.
  Future<void> closeInvite(String inviteId) async {
    try {
      await _invites.doc(inviteId).delete();
    } catch (_) {}
  }


  // ---- Kalıcı oyuncu kanalları: tüm kimlikler Firebase Auth UID'sidir ----

  CollectionReference<Map<String, dynamic>> get _channels =>
      FirebaseFirestore.instance.collection('channels');
  CollectionReference<Map<String, dynamic>> get _channelInvites =>
      FirebaseFirestore.instance.collection('channel_invites');

  String _requireChannelUid(String suppliedUid) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid != suppliedUid) {
      throw StateError('Kanalları kullanmak için giriş yapmalısın.');
    }
    return uid;
  }

  // Public channel discovery must not silently hide newer channels behind
  // an arbitrary first-50 document window. Keep the query aligned with the
  // public-only Firestore rule and stream the complete discoverable set.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchChannels() =>
      _channels.snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> watchChannelTournaments(String channelId) =>
      _channels.doc(channelId).collection('tournaments')
          .orderBy('createdAt', descending: true).snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> watchChannelTournamentStats(String channelId) =>
      _channels.doc(channelId).collection('tournament_stats').snapshots();

  /// A match participant links the official game room to their bracket match.
  /// Only player 1 may open the room, preventing duplicate simultaneous rooms.
  Future<void> linkTournamentMatchRoom({
    required String channelId,
    required String tournamentId,
    required String matchId,
    required String deviceId,
    required String roomCode,
  }) async {
    final uid = _requireChannelUid(deviceId);
    final tournament = _channels.doc(channelId).collection('tournaments').doc(tournamentId);
    final match = tournament.collection('matches').doc(matchId);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final tournamentSnap = await tx.get(tournament);
      final matchSnap = await tx.get(match);
      if (!tournamentSnap.exists || !matchSnap.exists ||
          tournamentSnap.data()?['status'] != 'in_progress') {
        throw StateError('Turnuva maçı artık başlatılamıyor.');
      }
      final data = matchSnap.data()!;
      if (data['status'] != 'ready' || data['player1Uid'] != uid ||
          data['player2Uid'] == null || data['roomCode'] != null) {
        throw StateError('Bu maçı yalnızca ilk oyuncu, bir kez başlatabilir.');
      }
      tx.update(match, {
        'roomCode': roomCode,
        'roomCreatedBy': uid,
        'roomLinkedAt': FieldValue.serverTimestamp(),
        'joinDeadline': Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 3))),
      });
    });
  }

  /// Oda iptal edilmişse aynı fikstür maçı için yeni oda açılmasına izin verir.
  /// Yalnızca eşleşmenin ilk oyuncusu, eşleşmeye bağlı mevcut oda gerçekten
  /// cancelled durumundaysa bağlantıyı kaldırabilir.
  Future<void> resetCancelledTournamentMatchRoom({
    required String channelId,
    required String tournamentId,
    required String matchId,
    required String deviceId,
    required String roomCode,
  }) async {
    final uid = _requireChannelUid(deviceId);
    final tournament = _channels.doc(channelId).collection('tournaments').doc(tournamentId);
    final match = tournament.collection('matches').doc(matchId);
    final room = _rooms.doc(roomCode);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final matchSnap = await tx.get(match);
      final roomSnap = await tx.get(room);
      if (!matchSnap.exists) {
        throw StateError('Turnuva eşleşmesi bulunamadı.');
      }
      final matchData = matchSnap.data()!;
      final roomData = roomSnap.data();
      if (matchData['status'] != 'ready' ||
          matchData['player1Uid'] != uid ||
          matchData['roomCode'] != roomCode ||
          (roomSnap.exists &&
            (roomData?['roomStatus'] != 'cancelled' ||
             roomData?['tournamentChannelId'] != channelId ||
             roomData?['tournamentId'] != tournamentId ||
             roomData?['tournamentMatchId'] != matchId))) {
        throw StateError('Yalnızca iptal edilmiş veya süresi dolmuş bu maç odası yeniden açılabilir.');
      }
      tx.update(match, {
        'roomCode': FieldValue.delete(),
        'roomCreatedBy': FieldValue.delete(),
        'roomLinkedAt': FieldValue.delete(),
      });
    });
  }

  Future<String> createChannelTournament({
    required String channelId,
    required String creatorDeviceId,
    required String title,
    required String format,
    required int maxPlayers,
  }) async {
    final uid = _requireChannelUid(creatorDeviceId);
    if (title.trim().length < 2 || title.trim().length > 40 ||
        format != 'swiss' ||
        maxPlayers < 2 || maxPlayers > 256) {
      throw ArgumentError('Turnuva adı veya oyuncu sınırı geçersiz. Katılımcı sınırı 2–256 arasında olmalı.');
    }
    final channel = _channels.doc(channelId);
    final snapshot = await channel.get();
    if (!snapshot.exists || snapshot.data()?['ownerDeviceId'] != uid) {
      throw StateError('Yalnızca kanal kurucusu turnuva oluşturabilir.');
    }
    final ref = channel.collection('tournaments').doc();
    await ref.set({
      'title': title.trim(),
      'format': format,
      'maxPlayers': maxPlayers,
      'status': 'registration',
      'creatorDeviceId': uid,
      'participantIds': <String>[],
      'prizeStars': {'1': 100, '2': 60, '3': 30},
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<bool> joinChannelTournament({
    required String channelId,
    required String tournamentId,
    required String deviceId,
  }) async {
    final uid = _requireChannelUid(deviceId);
    final ref = _channels.doc(channelId).collection('tournaments').doc(tournamentId);
    return FirebaseFirestore.instance.runTransaction<bool>((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return false;
      final data = snap.data()!;
      if (data['status'] != 'registration') return false;
      final ids = List<String>.from(data['participantIds'] ?? const <String>[]);
      if (ids.contains(uid)) return true;
      final max = (data['maxPlayers'] as num?)?.toInt() ?? 32;
      if (ids.length >= max) return false;
      tx.update(ref, {'participantIds': FieldValue.arrayUnion([uid])});
      return true;
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchTournamentMatches(
      String channelId, String tournamentId) =>
      _channels.doc(channelId).collection('tournaments').doc(tournamentId)
          .collection('matches').snapshots();

  Future<void> startChannelTournament({
    required String channelId,
    required String tournamentId,
    required String creatorDeviceId,
  }) async {
    final uid = _requireChannelUid(creatorDeviceId);
    final tournament = _channels.doc(channelId).collection('tournaments').doc(tournamentId);
    final pairingSeed = Random.secure().nextInt(0x7fffffff);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final tournamentSnap = await tx.get(tournament);
      if (!tournamentSnap.exists ||
          tournamentSnap.data()?['creatorDeviceId'] != uid ||
          tournamentSnap.data()?['status'] != 'registration') {
        throw StateError('Turnuva başlatılamadı.');
      }
      final data = tournamentSnap.data()!;
      final participantIds = List<String>.from(data['participantIds'] ?? const <String>[]);
      if (participantIds.length < 2) {
        throw StateError('Turnuvayı başlatmak için en az 2 oyuncu kayıt olmalı.');
      }
      final players = <SwissPlayer>[];
      final playerInfo = <String, dynamic>{};
      for (final playerUid in participantIds) {
        final memberRef = _channels.doc(channelId).collection('members').doc(playerUid);
        final memberSnap = await tx.get(memberRef);
        if (!memberSnap.exists) continue;
        final member = memberSnap.data()!;
        final playerDeviceId = member['playerDeviceId'] as String? ?? '';
        if (playerDeviceId.trim().isEmpty) {
          throw StateError('Bir oyuncunun cihaz kimliği eksik. Her oyuncu kanalı yeniden açıp tekrar denemeli.');
        }
        final name = member['displayName'] as String? ?? 'Oyuncu';
        players.add(SwissPlayer(uid: playerUid, name: name));
        playerInfo[playerUid] = {'name': name, 'deviceId': playerDeviceId};
      }
      if (players.length < 2) {
        throw StateError('Turnuvaya kayıtlı en az iki kanal üyesi bulunmalı.');
      }
      final deviceIds = players.map((p) => playerInfo[p.uid]['deviceId']).toSet();
      if (deviceIds.length != players.length) {
        throw StateError('İki oyuncuda aynı cihaz kimliği kayıtlı. Oyuncular kanalı kendi telefonlarında yeniden açmalı.');
      }

      final roundCount = swissRoundCount(players.length);
      final pairings = createSwissPairings(players, seed: pairingSeed);
      final matches = tournament.collection('matches');
      final scoresHalf = <String, int>{for (final player in players) player.uid: 0};
      final opponents = <String, dynamic>{for (final player in players) player.uid: <String>[]};
      final byeCounts = <String, int>{for (final player in players) player.uid: 0};
      var matchIndex = 0;
      for (final pairing in pairings) {
        matchIndex++;
        final p1 = pairing.player1;
        final p2 = pairing.player2;
        if (pairing.isBye) {
          scoresHalf[p1.uid] = 2; // Standard Swiss bye: one full point.
          byeCounts[p1.uid] = 1;
        } else {
          opponents[p1.uid] = [p2!.uid];
          opponents[p2.uid] = [p1.uid];
        }
        final p1Info = Map<String, dynamic>.from(playerInfo[p1.uid] as Map);
        final p2Info = p2 == null ? null : Map<String, dynamic>.from(playerInfo[p2.uid] as Map);
        tx.set(matches.doc('r1_m$matchIndex'), {
          'round': 1,
          'matchIndex': matchIndex,
          'player1Uid': p1.uid,
          'player1DeviceId': p1Info['deviceId'],
          'player1Name': p1.name,
          'player2Uid': p2?.uid,
          'player2DeviceId': p2Info?['deviceId'],
          'player2Name': p2?.name,
          'winnerUid': pairing.isBye ? p1.uid : null,
          'result': pairing.isBye ? 'bye' : null,
          'status': pairing.isBye ? 'completed' : 'ready',
          'isBye': pairing.isBye,
          'pointsAwarded': pairing.isBye ? 2 : 0,
          'scoreApplied': pairing.isBye,
          'joinDeadline': Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 5))),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      tx.update(tournament, {
        'format': 'swiss',
        'status': 'in_progress',
        'startedAt': FieldValue.serverTimestamp(),
        'currentRound': 1,
        'roundsTotal': roundCount,
        'matchCount': matchIndex,
        'playerInfo': playerInfo,
        'scoresHalf': scoresHalf,
        'opponents': opponents,
        'byeCounts': byeCounts,
      });
    });
  }


  /// Owner-client reconciliation: no Cloud Function required. Repeated calls
  /// are safe; match scores are applied once and round advancement is atomic.
  Future<void> reconcileSwissTournament({
    required String channelId, required String tournamentId,
    required String creatorDeviceId,
  }) async {
    final uid = _requireChannelUid(creatorDeviceId);
    final tournament = _channels.doc(channelId).collection('tournaments').doc(tournamentId);
    final initial = await tournament.get();
    final td = initial.data();
    if (!initial.exists || td?['creatorDeviceId'] != uid ||
        td?['status'] != 'in_progress' || td?['format'] != 'swiss') return;
    final round = (td?['currentRound'] as num?)?.toInt() ?? 0;
    final query = await tournament.collection('matches').where('round', isEqualTo: round).get();
    if (query.docs.isEmpty) return;
    final refs = query.docs.map((d) => d.reference).toList();

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final ts = await tx.get(tournament);
      if (!ts.exists) return;
      final t = ts.data()!;
      if (t['creatorDeviceId'] != uid || t['status'] != 'in_progress' ||
          (t['currentRound'] as num?)?.toInt() != round || t['format'] != 'swiss') return;
      final snaps = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final ref in refs) { snaps.add(await tx.get(ref)); }
      final roomRefs = <int, DocumentReference<Map<String, dynamic>>>{};
      for (var i = 0; i < snaps.length; i++) {
        final code = snaps[i].data()?['roomCode'];
        if (snaps[i].exists && code is String && code.isNotEmpty) roomRefs[i] = _rooms.doc(code);
      }
      final rooms = <int, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final e in roomRefs.entries) { rooms[e.key] = await tx.get(e.value); }

      final scores = <String, int>{
        for (final e in Map<String, dynamic>.from(t['scoresHalf'] as Map? ?? const {}).entries)
          e.key: (e.value as num).toInt(),
      };
      final opponents = <String, List<String>>{
        for (final e in Map<String, dynamic>.from(t['opponents'] as Map? ?? const {}).entries)
          e.key: List<String>.from(e.value as List? ?? const []),
      };
      final byes = <String, int>{
        for (final e in Map<String, dynamic>.from(t['byeCounts'] as Map? ?? const {}).entries)
          e.key: (e.value as num).toInt(),
      };
      final info = Map<String, dynamic>.from(t['playerInfo'] as Map? ?? const {});
      final data = <Map<String, dynamic>>[];
      final now = DateTime.now();

      for (var i = 0; i < snaps.length; i++) {
        if (!snaps[i].exists) continue;
        final m = Map<String, dynamic>.from(snaps[i].data()!);
        if (m['status'] != 'completed') {
          final p1 = m['player1Uid'] as String?;
          final p2 = m['player2Uid'] as String?;
          final room = rooms[i]?.data();
          final gameStatus = room?['status'];
          String? winner;
          String? result;
          if (gameStatus == 'player1Wins') { winner = p1; result = 'played'; }
          if (gameStatus == 'player2Wins') { winner = p2; result = 'played'; }
          final deadlineValue = m['joinDeadline'];
          final deadline = deadlineValue is Timestamp ? deadlineValue.toDate() : null;
          if (result == null && deadline != null && !now.isBefore(deadline)) {
            final one = info[p1] is Map ? Map<String, dynamic>.from(info[p1] as Map) : const <String, dynamic>{};
            final two = info[p2] is Map ? Map<String, dynamic>.from(info[p2] as Map) : const <String, dynamic>{};
            final roomOpen = room != null && room['roomStatus'] != 'cancelled';
            final host = roomOpen && room['hostDeviceId'] == one['deviceId'] && room['hostLeftAt'] == null;
            final guest = roomOpen && room['guestDeviceId'] == two['deviceId'] && room['guestLeftAt'] == null;
            if (!host && !guest) result = 'both_absent';
            if (host && !guest) { winner = p1; result = 'player2_absent'; }
            if (!host && guest) { winner = p2; result = 'player1_absent'; }
          }
          if (result != null) {
            final p1Half = winner == p1 ? 2 : 0;
            final p2Half = winner == p2 ? 2 : 0;
            m['status'] = 'completed';
            m['winnerUid'] = winner;
            m['result'] = result;
            m['p1PointsHalf'] = p1Half;
            m['p2PointsHalf'] = p2Half;
            tx.update(refs[i], {
              'status': 'completed', 'winnerUid': winner, 'result': result,
              'p1PointsHalf': p1Half, 'p2PointsHalf': p2Half,
              'resultAt': FieldValue.serverTimestamp(),
            });
          }
        }
        data.add(m);
      }
      if (data.isEmpty || data.any((m) => m['status'] != 'completed')) return;

      for (var i = 0; i < data.length; i++) {
        final m = data[i];
        if (m['isBye'] == true || m['scoreApplied'] == true) continue;
        final a = m['player1Uid'] as String?;
        final b = m['player2Uid'] as String?;
        if (a == null || b == null) continue;
        scores[a] = (scores[a] ?? 0) + ((m['p1PointsHalf'] as num?)?.toInt() ?? 0);
        scores[b] = (scores[b] ?? 0) + ((m['p2PointsHalf'] as num?)?.toInt() ?? 0);
        if (!opponents.putIfAbsent(a, () => []).contains(b)) opponents[a]!.add(b);
        if (!opponents.putIfAbsent(b, () => []).contains(a)) opponents[b]!.add(a);
        tx.update(refs[i], {'scoreApplied': true});
      }

      final total = (t['roundsTotal'] as num?)?.toInt() ?? round;
      if (round >= total) {
        final ordered = scores.keys.toList()..sort((a, b) {
          final p = (scores[b] ?? 0).compareTo(scores[a] ?? 0);
          if (p != 0) return p;
          final bh = swissBuchholz(b, scores, opponents).compareTo(swissBuchholz(a, scores, opponents));
          return bh != 0 ? bh : a.compareTo(b);
        });
        final prizes = Map<String, dynamic>.from(t['prizeStars'] as Map? ?? const {'1':100,'2':60,'3':30});
        final placements = <String, dynamic>{};
        for (var i = 0; i < ordered.length; i++) {
          final player = ordered[i];
          final rank = i + 1;
          if (rank <= 3) placements[player] = {
            'rank': rank, 'pointsHalf': scores[player],
            'buchholzHalf': swissBuchholz(player, scores, opponents),
            'stars': (prizes['$rank'] as num?)?.toInt() ?? 0,
          };
        }
        final winners = placements.entries.where((e) => e.value['rank'] == 1).map((e) => e.key).toList();
        tx.update(tournament, {
          'scoresHalf': scores, 'opponents': opponents, 'byeCounts': byes,
          'status': 'completed', 'placements': placements,
          'winnerUid': winners.length == 1 ? winners.first : null,
          'tiedWinnerUids': winners.length > 1 ? winners : <String>[],
          'completedAt': FieldValue.serverTimestamp(),
        });
        return;
      }

      final players = scores.keys.map((id) {
        final p = info[id] is Map ? Map<String, dynamic>.from(info[id] as Map) : const <String, dynamic>{};
        return SwissPlayer(uid: id, name: p['name'] as String? ?? 'Oyuncu',
          points: scores[id] ?? 0, opponents: opponents[id] ?? const [], byeCount: byes[id] ?? 0);
      }).toList();
      final pairings = createSwissPairings(players, seed: round * 7919);
      var index = 0;
      for (final pairing in pairings) {
        index++;
        final a = pairing.player1;
        final b = pairing.player2;
        if (pairing.isBye) {
          scores[a.uid] = (scores[a.uid] ?? 0) + 2;
          byes[a.uid] = (byes[a.uid] ?? 0) + 1;
        } else {
          opponents.putIfAbsent(a.uid, () => []).add(b!.uid);
          opponents.putIfAbsent(b.uid, () => []).add(a.uid);
        }
        final one = Map<String, dynamic>.from(info[a.uid] as Map);
        final two = b == null ? null : Map<String, dynamic>.from(info[b.uid] as Map);
        tx.set(tournament.collection('matches').doc('r${round + 1}_m$index'), {
          'round': round + 1, 'matchIndex': index,
          'player1Uid': a.uid, 'player1DeviceId': one['deviceId'], 'player1Name': a.name,
          'player2Uid': b?.uid, 'player2DeviceId': two?['deviceId'], 'player2Name': b?.name,
          'winnerUid': pairing.isBye ? a.uid : null,
          'result': pairing.isBye ? 'bye' : null,
          'status': pairing.isBye ? 'completed' : 'ready',
          'isBye': pairing.isBye, 'pointsAwarded': pairing.isBye ? 2 : 0,
          'scoreApplied': pairing.isBye,
          'joinDeadline': Timestamp.fromDate(now.add(const Duration(minutes: 5))),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      tx.update(tournament, {
        'scoresHalf': scores, 'opponents': opponents, 'byeCounts': byes,
        'currentRound': round + 1, 'matchCount': FieldValue.increment(index),
      });
    });
  }

  /// A participant can claim only their own published podium reward.
  /// Existing claims return zero: the same account must never be credited
  /// again from another device. The winner syncs the local balance immediately.
  Future<int> claimTournamentReward({
    required String channelId,
    required String tournamentId,
    required String deviceId,
  }) async {
    final uid = _requireChannelUid(deviceId);
    final tournament = _channels.doc(channelId).collection('tournaments').doc(tournamentId);
    final claim = tournament.collection('reward_claims').doc(uid);
    final accountProgress = FirebaseFirestore.instance
        .collection('users').doc(uid).collection('private').doc('progress');
    return FirebaseFirestore.instance.runTransaction<int>((tx) async {
      final tournamentSnap = await tx.get(tournament);
      final claimSnap = await tx.get(claim);
      final progressSnap = await tx.get(accountProgress);
      if (claimSnap.exists) return 0; // Claimed on this or another device; never credit twice.
      final data = tournamentSnap.data();
      if (!tournamentSnap.exists || data?['status'] != 'completed') return 0;
      final placements = Map<String, dynamic>.from(data?['placements'] as Map? ?? const {});
      final placement = placements[uid];
      if (placement is! Map) return 0;
      final rank = (placement['rank'] as num?)?.toInt() ?? 0;
      final stars = (placement['stars'] as num?)?.toInt() ?? 0;
      if (rank < 1 || rank > 3 || stars <= 0) return 0;

      // Credit the cloud account and create the unique claim in one atomic
      // transaction. A process crash cannot consume a prize without saving it.
      final progressData = progressSnap.exists
          ? Map<String, dynamic>.from(progressSnap.data()!)
          : GuestProgressSnapshot.empty().toMap();
      final earned = (progressData['starsEarned'] as num?)?.toInt()
          ?? (progressData['stars'] as num?)?.toInt() ?? 0;
      final spent = (progressData['starsSpent'] as num?)?.toInt() ?? 0;
      final claimed = List<String>.from(
          progressData['claimedTournamentRewardIds'] ?? const <String>[]);
      if (!claimed.contains(tournamentId)) claimed.add(tournamentId);
      final newEarned = earned + stars;
      tx.set(accountProgress, {
        ...progressData,
        'starsEarned': newEarned,
        'starsSpent': spent,
        'stars': newEarned > spent ? newEarned - spent : 0,
        'claimedTournamentRewardIds': claimed,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.set(claim, {
        'uid': uid,
        'rank': rank,
        'stars': stars,
        'claimedAt': FieldValue.serverTimestamp(),
      });
      return stars;
    });
  }

  Future<String?> findChannelByInviteCode(String code) async {
    if (FirebaseAuth.instance.currentUser == null) {
      throw StateError('Davet koduyla katılmak için giriş yapmalısın.');
    }
    final normalized = code.trim().toUpperCase();
    if (normalized.length != 8) return null;
    final invite = await _channelInvites.doc(normalized).get();
    if (!invite.exists) return null;
    return invite.data()?['channelId'] as String?;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchChannelMembers(String channelId) =>
      _channels.doc(channelId).collection('members').orderBy('joinedAt').snapshots();

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchChannelMembership(
      String channelId, String deviceId) {
    _requireChannelUid(deviceId);
    return _channels.doc(channelId).collection('members').doc(deviceId).snapshots();
  }

  Future<String> createChannel({
    required String ownerDeviceId,
    required String ownerPlayerDeviceId,
    required String ownerDisplayName,
    required String name,
    required String description,
    bool inviteOnly = false,
  }) async {
    final uid = _requireChannelUid(ownerDeviceId);
    final ref = _channels.doc();
    const inviteChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final inviteRandom = Random.secure();
    final inviteCode = List.generate(8, (_) => inviteChars[inviteRandom.nextInt(inviteChars.length)]).join();
    final now = FieldValue.serverTimestamp();
    final batch = FirebaseFirestore.instance.batch();
    batch.set(ref, {
      'name': name.trim(),
      'description': description.trim(),
      'ownerDeviceId': uid,
      'creatorUid': uid,
      'ownerDisplayName': ownerDisplayName,
      'memberCount': 1,
      'createdAt': now,
      'updatedAt': now,
      'status': 'open',
      'visibility': inviteOnly ? 'invite_only' : 'public',
    });
    batch.set(ref.collection('members').doc(uid), {
      'deviceId': uid,
      'playerDeviceId': ownerPlayerDeviceId,
      'displayName': ownerDisplayName,
      'joinedAt': now,
      'role': 'owner',
    });
    if (inviteOnly) {
      batch.set(ref.collection('private').doc('invite'), {
        'inviteCode': inviteCode,
        'updatedAt': now,
      });
      batch.set(_channelInvites.doc(inviteCode), {
        'channelId': ref.id,
        'ownerUid': uid,
        'createdAt': now,
      });
    }
    await batch.commit();
    return ref.id;
  }

  Future<bool> joinChannel({
    required String channelId,
    required String deviceId,
    required String playerDeviceId,
    required String displayName,
    String? inviteCode,
  }) async {
    final uid = _requireChannelUid(deviceId);
    final channel = _channels.doc(channelId);
    final member = channel.collection('members').doc(uid);
    return FirebaseFirestore.instance.runTransaction<bool>((tx) async {
      final channelSnap = await tx.get(channel);
      if (!channelSnap.exists || channelSnap.data()?['status'] != 'open' ||
          channelSnap.data()?['visibility'] != 'public') return false;
      final memberSnap = await tx.get(member);
      if (memberSnap.exists) {
        tx.update(member, {
          'playerDeviceId': playerDeviceId,
          'displayName': displayName,
          'identityUpdatedAt': FieldValue.serverTimestamp(),
        });
        return true;
      }
      final data = channelSnap.data()!;
      tx.set(member, {
        'deviceId': uid,
        'playerDeviceId': playerDeviceId,
        'displayName': displayName,
        'joinedAt': FieldValue.serverTimestamp(),
        'role': 'member',
      });
      tx.update(channel, {
        'memberCount': ((data['memberCount'] as num?) ?? 0).toInt() + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    });
  }

  CollectionReference<Map<String, dynamic>> _channelJoinRequests(String channelId) =>
      _channels.doc(channelId).collection('join_requests');

  Stream<QuerySnapshot<Map<String, dynamic>>> watchChannelJoinRequests(String channelId) =>
      _channelJoinRequests(channelId).orderBy('requestedAt').snapshots();

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchMyChannelJoinRequest(
      String channelId, String uid) =>
      _channelJoinRequests(channelId).doc(uid).snapshots();

  Future<void> requestChannelJoin({
    required String channelId,
    required String uid,
    required String playerDeviceId,
    required String displayName,
  }) async {
    _requireChannelUid(uid);
    final channel = _channels.doc(channelId);
    final request = _channelJoinRequests(channelId).doc(uid);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final channelSnap = await tx.get(channel);
      final memberSnap = await tx.get(channel.collection('members').doc(uid));
      final requestSnap = await tx.get(request);
      if (!channelSnap.exists || channelSnap.data()?['status'] != 'open' ||
          channelSnap.data()?['visibility'] != 'invite_only') {
        throw StateError('Bu kanal şu anda katılma talebi kabul etmiyor.');
      }
      if (memberSnap.exists) throw StateError('Zaten bu kanalın üyesisin.');
      if (requestSnap.exists) return; // One active request per user.
      tx.set(request, {
        'uid': uid,
        'displayName': displayName.trim().isEmpty ? 'Oyuncu' : displayName.trim(),
        'playerDeviceId': playerDeviceId,
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> respondToChannelJoinRequest({
    required String channelId,
    required String requesterUid,
    required bool accept,
  }) async {
    final ownerUid = _requireChannelUid(FirebaseAuth.instance.currentUser?.uid ?? '');
    final channel = _channels.doc(channelId);
    final request = _channelJoinRequests(channelId).doc(requesterUid);
    final member = channel.collection('members').doc(requesterUid);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final channelSnap = await tx.get(channel);
      final requestSnap = await tx.get(request);
      final memberSnap = await tx.get(member);
      if (!channelSnap.exists || channelSnap.data()?['ownerDeviceId'] != ownerUid) {
        throw StateError('Bu talebi yalnızca kanal kurucusu yanıtlayabilir.');
      }
      if (!requestSnap.exists || requestSnap.data()?['status'] != 'pending') return;
      if (accept && !memberSnap.exists) {
        final data = requestSnap.data()!;
        tx.set(member, {
          'deviceId': requesterUid,
          'playerDeviceId': data['playerDeviceId'] ?? requesterUid,
          'displayName': data['displayName'] ?? 'Oyuncu',
          'joinedAt': FieldValue.serverTimestamp(),
          'role': 'member',
        });
        tx.update(channel, {
          'memberCount': ((channelSnap.data()?['memberCount'] as num?) ?? 0).toInt() + 1,
          'lastApprovedUid': requesterUid,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      tx.update(request, {
        'status': accept ? 'accepted' : 'rejected',
        'respondedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<String?> getChannelInviteCode(String channelId, String uid) async {
    _requireChannelUid(uid);
    final channel = _channels.doc(channelId);
    final snap = await channel.collection('private').doc('invite').get();
    if (snap.data()?['inviteCode'] is String) return snap.data()!['inviteCode'] as String;
    return null;
  }

  /// Refreshes an existing member's persistent game-device identity.
  Future<void> refreshChannelMemberIdentity({
    required String channelId,
    required String deviceId,
    required String playerDeviceId,
    required String displayName,
  }) async {
    final uid = _requireChannelUid(deviceId);
    final member = _channels.doc(channelId).collection('members').doc(uid);
    final snap = await member.get();
    if (!snap.exists) return;
    await member.update({
      'playerDeviceId': playerDeviceId,
      'displayName': displayName,
      'identityUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<bool> joinPrivateChannelByCode({
    required String code,
    required String deviceId,
    required String playerDeviceId,
    required String displayName,
  }) async {
    final uid = _requireChannelUid(deviceId);
    final normalized = code.trim().toUpperCase();
    if (normalized.length != 8) return false;
    final invite = await _channelInvites.doc(normalized).get();
    if (!invite.exists) return false;
    final channelId = invite.data()?['channelId'] as String?;
    if (channelId == null || channelId.isEmpty) return false;
    final channel = _channels.doc(channelId);
    final member = channel.collection('members').doc(uid);
    if ((await member.get()).exists) {
      await member.update({
        'playerDeviceId': playerDeviceId,
        'displayName': displayName,
        'identityUpdatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    }
    final batch = FirebaseFirestore.instance.batch();
    batch.set(member, {
      'deviceId': uid,
      'playerDeviceId': playerDeviceId,
      'displayName': displayName,
      'joinedAt': FieldValue.serverTimestamp(),
      'role': 'member',
      'inviteCode': normalized,
    });
    batch.update(channel, {
      'memberCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return true;
  }

  /// Kanalı ve ona bağlı tüm verileri kalıcı olarak siler.
  /// Firestore alt koleksiyonları üst belge silinince otomatik silinmediği
  /// için her alt koleksiyon açıkça temizlenir; büyük listeler 400'lük
  /// batch'lere bölünür. Kanal belgesi en son silinir.
  Future<void> _deleteChannelDocuments(
      Iterable<DocumentReference<Map<String, dynamic>>> references) async {
    final docs = references.toList(growable: false);
    for (var start = 0; start < docs.length; start += 400) {
      final batch = FirebaseFirestore.instance.batch();
      final end = (start + 400 < docs.length) ? start + 400 : docs.length;
      for (final ref in docs.sublist(start, end)) {
        batch.delete(ref);
      }
      await batch.commit();
    }
  }

  Future<void> deleteChannel(String channelId, String deviceId) async {
    final uid = _requireChannelUid(deviceId);
    final channel = _channels.doc(channelId);
    final channelSnap = await channel.get();
    if (!channelSnap.exists || channelSnap.data()?['ownerDeviceId'] != uid) {
      throw StateError('Yalnızca kanal kurucusu kanalı silebilir.');
    }

    // Invite-code collection deliberately forbids listing. Read the single
    // owner-only private invite record, then delete its known global document.
    final privateInvite = await channel.collection('private').doc('invite').get();
    final inviteCode = privateInvite.data()?['inviteCode'] as String?;
    if (inviteCode != null && inviteCode.isNotEmpty) {
      final inviteRef = _channelInvites.doc(inviteCode);
      final inviteSnapshot = await inviteRef.get();
      if (inviteSnapshot.exists) await inviteRef.delete();
    }

    // Remove nested tournament records before deleting their parent documents.
    final tournaments = await channel.collection('tournaments').get();
    for (final tournamentDoc in tournaments.docs) {
      final tournament = tournamentDoc.reference;
      final matches = await tournament.collection('matches').get();
      await _deleteChannelDocuments(matches.docs.map((doc) => doc.reference));
      final claims = await tournament.collection('reward_claims').get();
      await _deleteChannelDocuments(claims.docs.map((doc) => doc.reference));
    }

    // Delete the known private invite document directly; listing this
    // security-sensitive collection is intentionally forbidden by rules.
    if (privateInvite.exists) {
      await channel.collection('private').doc('invite').delete();
    }

    // Keep the owner's membership until the very last atomic operation:
    // subsequent subcollection reads are authorized through that membership.
    const directCollections = [
      'join_requests',
      'messages',
      'tournament_stats',
      'tournaments',
    ];
    for (final name in directCollections) {
      final snapshot = await channel.collection(name).get();
      await _deleteChannelDocuments(snapshot.docs.map((doc) => doc.reference));
    }

    // Remove other members in chunks, but retain the owner record until the
    // final batch. The owner membership and channel document are deleted
    // together, so a retry remains possible if an earlier step fails.
    final memberSnapshot = await channel.collection('members').get();
    final otherMembers = memberSnapshot.docs
        .where((doc) => doc.id != uid)
        .map((doc) => doc.reference);
    await _deleteChannelDocuments(otherMembers);
    final ownerMember = channel.collection('members').doc(uid);
    final finalBatch = FirebaseFirestore.instance.batch();
    if (memberSnapshot.docs.any((doc) => doc.id == uid)) {
      finalBatch.delete(ownerMember);
    }
    finalBatch.delete(channel);
    await finalBatch.commit();
  }

  Future<void> leaveChannel(String channelId, String deviceId) async {
    final uid = _requireChannelUid(deviceId);
    final channel = _channels.doc(channelId);
    final member = channel.collection('members').doc(uid);
    final memberDocs = await channel.collection('members').get();
    final replacement = memberDocs.docs.where((d) => d.id != uid).toList();
    final nextOwner = replacement.isEmpty ? null : replacement.first;

    // If the owner is the final member, leaving means deleting the channel
    // and all of its data; never leave an unreachable closed channel behind.
    final channelSnapshot = await channel.get();
    if (channelSnapshot.data()?['ownerDeviceId'] == uid && nextOwner == null) {
      await deleteChannel(channelId, uid);
      return;
    }

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final channelSnap = await tx.get(channel);
      final memberSnap = await tx.get(member);
      final nextOwnerRef = nextOwner == null
          ? null
          : channel.collection('members').doc(nextOwner.id);
      final nextOwnerSnap = nextOwnerRef == null ? null : await tx.get(nextOwnerRef);
      if (!channelSnap.exists || !memberSnap.exists) return;
      final data = channelSnap.data()!;
      final isOwner = data['ownerDeviceId'] == uid;
      tx.delete(member);
      if (isOwner && nextOwnerRef != null && nextOwnerSnap?.exists == true) {
        tx.update(nextOwnerRef, {'role': 'owner'});
      }
      tx.update(channel, {
        'memberCount': (((data['memberCount'] as num?) ?? 1).toInt() - 1).clamp(0, 999999),
        if (isOwner && nextOwner != null) ...{
          'ownerDeviceId': nextOwner.id,
          'ownerDisplayName': nextOwner.data()['displayName'],
        },
        if (isOwner && nextOwner == null) ...{
          'ownerDeviceId': uid,
          'ownerDisplayName': data['ownerDisplayName'],
          'status': 'closed',
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // ---- Kanal sohbeti ve kurucu duyuruları ----
  CollectionReference<Map<String, dynamic>> _channelMessages(String channelId) =>
      _channels.doc(channelId).collection('messages');

  Stream<QuerySnapshot<Map<String, dynamic>>> watchChannelMessages(String channelId) =>
      _channelMessages(channelId).orderBy('sentAt', descending: true).limit(100).snapshots();

  Future<void> sendChannelMessage({
    required String channelId,
    required String senderUid,
    required String senderName,
    required String text,
    bool announcement = false,
  }) async {
    final uid = _requireChannelUid(senderUid);
    final message = text.trim();
    if (message.isEmpty) return;
    if (message.length > 500) throw ArgumentError('Mesaj en fazla 500 karakter olabilir.');
    final name = senderName.trim();
    await _channelMessages(channelId).add({
      'senderUid': uid,
      'senderName': name.isEmpty ? 'Oyuncu' : name.substring(0, name.length > 32 ? 32 : name.length),
      'text': message,
      'isAnnouncement': announcement,
      'sentAt': FieldValue.serverTimestamp(),
    });
  }

  // ---- Liderlik tablosu ----

  CollectionReference<Map<String, dynamic>> get _gameResults =>
      FirebaseFirestore.instance.collection('game_results');

  /// Bir online oyun bittiğinde HER İKİ taraf da kendi sonucunu (kazandı
  /// mı) buraya kaydeder. Liderlik tablosu bu kayıtları zaman aralığına
  /// göre filtreleyip istemci tarafında sayarak oluşturuluyor (ayrı bir
  /// sunucu/Cloud Function olmadığı için).
  /// Başarılıysa null, başarısızsa hata metnini döndürür (ekranda gösterilir).
  Future<String?> recordGameResult({
    required String deviceId,
    required bool won,
    String? displayName,
    int? avatarIconIndex,
    int? avatarColorValue,
    String? photoBase64,
  }) async {
    try {
      await _gameResults.add({
        'deviceId': deviceId,
        'won': won,
        'displayName': displayName,
        'avatarIconIndex': avatarIconIndex,
        'avatarColorValue': avatarColorValue,
        'photoBase64': photoBase64,
        'playedAt': FieldValue.serverTimestamp(),
      });
      return null;
    } catch (e) {
      return '$e';
    }
  }

  /// [since] tarihinden itibaren kazanılmış tüm oyunları dinler —
  /// kazanan bazında gruplanıp sayılması ekranda (istemci tarafında)
  /// yapılıyor.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchWinsSince(DateTime since) {
    // NOT: "won" filtresi sorguda DEĞİL, ekranda (istemci tarafında)
    // uygulanıyor — iki alanlı sorgu Firestore'dan özel (bileşik) dizin
    // isterdi. Tek alanlı aralık sorgusu otomatik dizinle çalışır.
    return _gameResults
        .where('playedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .snapshots();
  }

  // ---- Şikayet (Google Play kullanıcı içeriği politikası için) ----

  /// Rakibi uygunsuz davranış/içerik nedeniyle bildirir. Kayıtlar yalnızca
  /// geliştirici tarafından Firebase Console'dan okunabilir.
  Future<void> reportUser({
    required String roomCode,
    required String reporterDeviceId,
    required String? reportedDeviceId,
    required String reason,
  }) async {
    await FirebaseFirestore.instance.collection('reports').add({
      'roomCode': roomCode,
      'reporterDeviceId': reporterDeviceId,
      'reportedDeviceId': reportedDeviceId,
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ---- Arkadaşlar ----

  CollectionReference<Map<String, dynamic>> get _friendRequests =>
      FirebaseFirestore.instance.collection('friend_requests');
  CollectionReference<Map<String, dynamic>> get _friendships =>
      FirebaseFirestore.instance.collection('friendships');

  /// İki oyuncu için sıradan bağımsız, tek bir kimlik.
  String _pairId(String a, String b) =>
      a.compareTo(b) <= 0 ? '${a}_$b' : '${b}_$a';

  /// Dönüş: 'sent' | 'already' | 'accepted' | 'error'
  /// Karşı taraf zaten bana istek göndermişse otomatik kabul edilir.
  Future<String> sendFriendRequest({
    required String fromDeviceId,
    required String toDeviceId,
    String? fromDisplayName,
    int? fromAvatarIconIndex,
    int? fromAvatarColorValue,
    String? fromPhotoBase64,
  }) async {
    if (fromDeviceId == toDeviceId) return 'error';
    try {
      if ((await _friendships.doc(_pairId(fromDeviceId, toDeviceId)).get())
          .exists) {
        return 'already';
      }
      final reverse = _friendRequests.doc('${toDeviceId}_$fromDeviceId');
      if ((await reverse.get()).exists) {
        await acceptFriendRequest(
            requestId: reverse.id,
            fromDeviceId: toDeviceId,
            toDeviceId: fromDeviceId);
        return 'accepted';
      }
      final mine = _friendRequests.doc('${fromDeviceId}_$toDeviceId');
      if ((await mine.get()).exists) return 'sent';
      await mine.set({
        'fromDeviceId': fromDeviceId,
        'toDeviceId': toDeviceId,
        'fromDisplayName': fromDisplayName,
        'fromAvatarIconIndex': fromAvatarIconIndex,
        'fromAvatarColorValue': fromAvatarColorValue,
        'fromPhotoBase64': fromPhotoBase64,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return 'sent';
    } catch (_) {
      return 'error';
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchIncomingFriendRequests(
      String myDeviceId) {
    return _friendRequests
        .where('toDeviceId', isEqualTo: myDeviceId)
        .snapshots();
  }

  Future<void> acceptFriendRequest({
    required String requestId,
    required String fromDeviceId,
    required String toDeviceId,
  }) async {
    try {
      final ref = _friendships.doc(_pairId(fromDeviceId, toDeviceId));
      if (!(await ref.get()).exists) {
        final ids = [fromDeviceId, toDeviceId]..sort();
        await ref.set({'users': ids, 'createdAt': FieldValue.serverTimestamp()});
      }
      await _friendRequests.doc(requestId).delete();
    } catch (_) {}
  }

  Future<void> declineFriendRequest(String requestId) async {
    try {
      await _friendRequests.doc(requestId).delete();
    } catch (_) {}
  }

  /// Bu cihazın tüm arkadaşlık kayıtları (her kayıtta 'users' listesi var).
  Stream<QuerySnapshot<Map<String, dynamic>>> watchFriendships(
      String myDeviceId) {
    return _friendships.where('users', arrayContains: myDeviceId).snapshots();
  }

  Future<void> removeFriend(String myDeviceId, String otherDeviceId) async {
    try {
      await _friendships.doc(_pairId(myDeviceId, otherDeviceId)).delete();
    } catch (_) {}
  }
}
