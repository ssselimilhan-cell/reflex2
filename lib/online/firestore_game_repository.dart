import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../settings/guest_progress_snapshot.dart';
import '../game/game_engine.dart';

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
        .snapshots();
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
      if (data['guestDeviceId'] != null) return false;

      // NOT: Katılan oyuncu direkt oyunu başlatmaz — "ready" durumuna
      // geçer, oyun ancak taraflardan biri başlatıp diğeri kabul edince
      // ("start_requested" -> "active") başlar.
      tx.update(ref, {
        'guestDeviceId': guestDeviceId,
        'roomStatus': 'ready',
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
  Future<bool> requestStart(String code, PlayerSide side) async {
    final ref = _rooms.doc(code);
    return FirebaseFirestore.instance.runTransaction<bool>((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return false;
      final data = snap.data()!;
      if (data['roomStatus'] != 'ready') return false;

      tx.update(ref, {
        'roomStatus': 'start_requested',
        'startRequestedBy': side.name,
      });
      return true;
    });
  }

  /// Karşı taraf başlatma isteğini kabul eder — oyun gerçekten başlar.
  Future<bool> acceptStart(String code) async {
    final ref = _rooms.doc(code);
    return FirebaseFirestore.instance.runTransaction<bool>((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return false;
      final data = snap.data()!;
      if (data['roomStatus'] != 'start_requested') return false;

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

      tx.update(ref, engine.toMap());
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
        tx.update(ref, {
          'roomStatus': 'cancelled',
          'cancelledBy': deviceId,
          'cancelledAt': FieldValue.serverTimestamp(),
          'startRequestedBy': null,
          'rematchRequestedBy': null,
        });
        return;
      }

      if (data['guestDeviceId'] != deviceId) return;
      final gameHasStarted = status == 'active' || status == 'finished';
      if (gameHasStarted) {
        tx.update(ref, {
          'roomStatus': 'finished',
          'guestLeftAt': FieldValue.serverTimestamp(),
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
        });
      }
    });
  }

  // ---- Sohbet ----

  CollectionReference<Map<String, dynamic>> _messagesRef(String code) =>
      _rooms.doc(code).collection('messages');

  Future<void> sendMessage(String code, PlayerSide side, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    await _messagesRef(code).add({
      'sender': side.name,
      'text': trimmed,
      'sentAt': FieldValue.serverTimestamp(),
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
  Future<void> sendInvite({
    required String toDeviceId,
    required String fromDeviceId,
    required String roomCode,
    String? fromDisplayName,
    int? fromAvatarIconIndex,
    int? fromAvatarColorValue,
    String? fromPhotoBase64,
    double? fromWinRate,
  }) async {
    await _invites.add({
      'toDeviceId': toDeviceId,
      'fromDeviceId': fromDeviceId,
      'roomCode': roomCode,
      'fromDisplayName': fromDisplayName,
      'fromAvatarIconIndex': fromAvatarIconIndex,
      'fromAvatarColorValue': fromAvatarColorValue,
      'fromPhotoBase64': fromPhotoBase64,
      'fromWinRate': fromWinRate,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Bu cihaza gelen, henüz kapatılmamış davetleri dinler.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchIncomingInvites(
      String myDeviceId) {
    return _invites
        .where('toDeviceId', isEqualTo: myDeviceId)
        .where('status', isEqualTo: 'pending')
        .snapshots();
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
      if (!matchSnap.exists || !roomSnap.exists) {
        throw StateError('Maç odası bulunamadı.');
      }
      final matchData = matchSnap.data()!;
      final roomData = roomSnap.data()!;
      if (matchData['status'] != 'ready' ||
          matchData['player1Uid'] != uid ||
          matchData['roomCode'] != roomCode ||
          roomData['roomStatus'] != 'cancelled' ||
          roomData['tournamentChannelId'] != channelId ||
          roomData['tournamentId'] != tournamentId ||
          roomData['tournamentMatchId'] != matchId) {
        throw StateError('Yalnızca iptal edilmiş bu maçın odası yeniden açılabilir.');
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
        !['single_elimination', 'round_robin'].contains(format) ||
        ![8, 16, 32, 64].contains(maxPlayers) ||
        (format == 'round_robin' && maxPlayers > 16)) {
      throw ArgumentError('Turnuva adı, formatı veya oyuncu sınırı geçersiz. Herkes birbiriyle formatında sınır en fazla 16 oyuncudur.');
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
      final players = <Map<String, String>>[];
      for (final playerUid in participantIds) {
        final memberRef = _channels.doc(channelId).collection('members').doc(playerUid);
        final memberSnap = await tx.get(memberRef);
        if (memberSnap.exists) {
          players.add({
            'uid': playerUid,
            'name': memberSnap.data()?['displayName'] as String? ?? 'Oyuncu',
          });
        }
      }
      if (players.length < 2) {
        throw StateError('Turnuvaya kayıtlı en az iki kanal üyesi bulunmalı.');
      }
      final matches = tournament.collection('matches');
      final format = data['format'] as String? ?? 'single_elimination';
      var matchIndex = 0;
      if (format == 'round_robin') {
        for (var i = 0; i < players.length; i++) {
          for (var j = i + 1; j < players.length; j++) {
            matchIndex++;
            tx.set(matches.doc('r1_m$matchIndex'), {
              'round': 1,
              'matchIndex': matchIndex,
              'player1Uid': players[i]['uid'],
              'player1Name': players[i]['name'],
              'player2Uid': players[j]['uid'],
              'player2Name': players[j]['name'],
              'winnerUid': null,
              'status': 'ready',
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
        }
      } else {
        // Draw a balanced power-of-two bracket. Randomized byes prevent an
        // arbitrary registration-order advantage when the field is uneven.
        var bracketSize = 1;
        while (bracketSize < players.length) {
          bracketSize *= 2;
        }
        players.shuffle(Random.secure());
        final byeCount = bracketSize - players.length;
        for (var i = 0; i < byeCount; i++) {
          matchIndex++;
          tx.set(matches.doc('r1_m$matchIndex'), {
            'round': 1,
            'matchIndex': matchIndex,
            'player1Uid': players[i]['uid'],
            'player1Name': players[i]['name'],
            'player2Uid': null,
            'player2Name': null,
            'winnerUid': players[i]['uid'],
            'status': 'completed',
            'isBye': true,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        for (var i = byeCount; i < players.length; i += 2) {
          matchIndex++;
          tx.set(matches.doc('r1_m$matchIndex'), {
            'round': 1,
            'matchIndex': matchIndex,
            'player1Uid': players[i]['uid'],
            'player1Name': players[i]['name'],
            'player2Uid': players[i + 1]['uid'],
            'player2Name': players[i + 1]['name'],
            'winnerUid': null,
            'status': 'ready',
            'isBye': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
      tx.update(tournament, {
        'status': 'in_progress',
        'startedAt': FieldValue.serverTimestamp(),
        'currentRound': 1,
        'matchCount': matchIndex,
      });
    });
  }

  Future<void> recordTournamentMatchWinner({
    required String channelId,
    required String tournamentId,
    required String matchId,
    required String creatorDeviceId,
    required String winnerUid,
  }) async {
    final uid = _requireChannelUid(creatorDeviceId);
    final tournament = _channels.doc(channelId).collection('tournaments').doc(tournamentId);
    final match = tournament.collection('matches').doc(matchId);
    final round = await FirebaseFirestore.instance.runTransaction<int>((tx) async {
      final tournamentSnap = await tx.get(tournament);
      final matchSnap = await tx.get(match);
      if (!tournamentSnap.exists || !matchSnap.exists ||
          tournamentSnap.data()?['creatorDeviceId'] != uid ||
          tournamentSnap.data()?['status'] != 'in_progress' ||
          matchSnap.data()?['status'] != 'ready') {
        throw StateError('Bu maçın sonucu şu anda işlenemiyor.');
      }
      final matchData = matchSnap.data()!;
      final player1 = matchData['player1Uid'] as String?;
      final player2 = matchData['player2Uid'] as String?;
      if (winnerUid != player1 && winnerUid != player2) {
        throw StateError('Kazanan bu maçın oyuncularından biri olmalı.');
      }
      final currentRound = (matchData['round'] as num).toInt();
      tx.update(match, {
        'winnerUid': winnerUid,
        'status': 'completed',
        'resultAt': FieldValue.serverTimestamp(),
      });
      return currentRound;
    });

    // Query reads are deliberately outside the transaction (the Flutter
    // Firestore Transaction API accepts document references only). The
    // tournament currentRound field below is the atomic advancement guard.
    final roundSnapshot = await tournament.collection('matches')
        .where('round', isEqualTo: round).get();
    final orderedRoundDocs = [...roundSnapshot.docs]
      ..sort((a, b) => ((a.data()['matchIndex'] as num?) ?? 0)
          .compareTo((b.data()['matchIndex'] as num?) ?? 0));
    final roundMatches = orderedRoundDocs.map((doc) => doc.data()).toList();
    if (roundMatches.isEmpty || roundMatches.any((item) => item['status'] != 'completed')) return;
    final allMatchesSnapshot = await tournament.collection('matches').get();

    final tournamentSnapshot = await tournament.get();
    final format = tournamentSnapshot.data()?['format'] as String? ?? 'single_elimination';
    final winners = roundMatches
        .map((item) => item['winnerUid'] as String?)
        .whereType<String>()
        .toList();

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final latest = await tx.get(tournament);
      if (!latest.exists || latest.data()?['status'] != 'in_progress' ||
          (latest.data()?['currentRound'] as num?)?.toInt() != round) {
        return; // Another completion already advanced this round.
      }
      final prizeStars = Map<String, dynamic>.from(
        latest.data()?['prizeStars'] as Map? ?? const {'1': 100, '2': 60, '3': 30});
      Map<String, dynamic> prize(String uid, int rank) => {
        'rank': rank,
        'stars': (prizeStars['$rank'] as num?)?.toInt() ?? 0,
      };

      // Store one immutable-in-practice contribution per completed tournament.
      // The tournamentIds list is the idempotency key for each player's stats.
      Future<void> publishFinalPlacements(
        Map<String, dynamic> placements, {
        String? winnerUid,
        List<String> tiedWinnerUids = const [],
      }) async {
        final participantIds = List<String>.from(
          latest.data()?['participantIds'] ?? const <String>[]);
        final statsCollection = _channels.doc(channelId).collection('tournament_stats');
        final refs = participantIds.map((playerUid) => statsCollection.doc(playerUid)).toList();
        final existing = <String, DocumentSnapshot<Map<String, dynamic>>>{};
        for (var i = 0; i < refs.length; i++) {
          existing[participantIds[i]] = await tx.get(refs[i]);
        }
        for (var i = 0; i < refs.length; i++) {
          final playerUid = participantIds[i];
          final ref = refs[i];
          final previous = existing[playerUid]?.data() ?? const <String, dynamic>{};
          final tournamentIds = List<String>.from(previous['tournamentIds'] ?? const <String>[]);
          if (tournamentIds.contains(tournamentId)) continue;
          tournamentIds.add(tournamentId);
          final placement = placements[playerUid] is Map
              ? Map<String, dynamic>.from(placements[playerUid] as Map)
              : const <String, dynamic>{};
          final rank = (placement['rank'] as num?)?.toInt() ?? 0;
          final stars = (placement['stars'] as num?)?.toInt() ?? 0;
          tx.set(ref, {
            'uid': playerUid,
            'tournamentIds': tournamentIds,
            'tournamentsPlayed': tournamentIds.length,
            'championships': ((previous['championships'] as num?)?.toInt() ?? 0) + (rank == 1 ? 1 : 0),
            'secondPlaces': ((previous['secondPlaces'] as num?)?.toInt() ?? 0) + (rank == 2 ? 1 : 0),
            'thirdPlaces': ((previous['thirdPlaces'] as num?)?.toInt() ?? 0) + (rank == 3 ? 1 : 0),
            'podiums': ((previous['podiums'] as num?)?.toInt() ?? 0) + (rank > 0 && rank <= 3 ? 1 : 0),
            'starsEarned': ((previous['starsEarned'] as num?)?.toInt() ?? 0) + stars,
            'lastTournamentId': tournamentId,
            'lastRank': rank,
            'lastStars': stars,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
        tx.update(tournament, {
          'status': 'completed',
          'winnerUid': winnerUid,
          'tiedWinnerUids': tiedWinnerUids,
          'placements': placements,
          'completedAt': FieldValue.serverTimestamp(),
        });
      }

      if (format == 'round_robin') {
        final wins = <String, int>{};
        final headToHead = <String, int>{};
        final participants = <String>{};
        for (final item in roundMatches) {
          final p1 = item['player1Uid'] as String?;
          final p2 = item['player2Uid'] as String?;
          final winner = item['winnerUid'] as String?;
          if (p1 != null) participants.add(p1);
          if (p2 != null) participants.add(p2);
          if (winner != null) {
            wins[winner] = (wins[winner] ?? 0) + 1;
            final loser = winner == p1 ? p2 : p1;
            if (loser != null) headToHead['$winner|$loser'] = 1;
          }
        }
        int headToHeadScore(String player) => participants
            .where((other) => other != player && wins[other] == wins[player])
            .where((other) => (headToHead['$player|$other'] ?? 0) > 0)
            .length;
        final ordered = participants.toList()
          ..sort((a, b) {
            final winCompare = (wins[b] ?? 0).compareTo(wins[a] ?? 0);
            if (winCompare != 0) return winCompare;
            final headToHeadCompare = headToHeadScore(b).compareTo(headToHeadScore(a));
            if (headToHeadCompare != 0) return headToHeadCompare;
            return a.compareTo(b);
          });
        final placements = <String, dynamic>{};
        var rank = 0;
        String? previousStanding;
        for (var i = 0; i < ordered.length; i++) {
          final player = ordered[i];
          final standing = '${wins[player] ?? 0}:${headToHeadScore(player)}';
          if (standing != previousStanding) rank = i + 1;
          if (rank <= 3) placements[player] = prize(player, rank);
          previousStanding = standing;
        }
        final leaders = placements.entries
            .where((entry) => (entry.value['rank'] as num?)?.toInt() == 1)
            .map((entry) => entry.key).toList();
        await publishFinalPlacements(
          placements,
          winnerUid: leaders.length == 1 ? leaders.first : null,
          tiedWinnerUids: leaders.length > 1 ? leaders : <String>[],
        );
        return;
      }

      // Final and third-place playoff are resolved together so the podium
      // cannot be published before both matches have a confirmed result.
      if (roundMatches.any((item) => item['isThirdPlace'] == true)) {
        final finalMatch = roundMatches.firstWhere((item) => item['isThirdPlace'] != true);
        final thirdMatch = roundMatches.firstWhere((item) => item['isThirdPlace'] == true);
        final champion = finalMatch['winnerUid'] as String?;
        final runnerUp = champion == finalMatch['player1Uid']
            ? finalMatch['player2Uid'] as String?
            : finalMatch['player1Uid'] as String?;
        final third = thirdMatch['winnerUid'] as String?;
        final placements = <String, dynamic>{};
        if (champion != null) placements[champion] = prize(champion, 1);
        if (runnerUp != null) placements[runnerUp] = prize(runnerUp, 2);
        if (third != null) placements[third] = prize(third, 3);
        await publishFinalPlacements(placements, winnerUid: champion);
        return;
      }

      if (winners.length == 1) {
        final finalMatch = roundMatches.first;
        final champion = winners.first;
        final runnerUp = champion == finalMatch['player1Uid']
            ? finalMatch['player2Uid'] as String?
            : finalMatch['player1Uid'] as String?;
        final placements = <String, dynamic>{champion: prize(champion, 1)};
        if (runnerUp != null) placements[runnerUp] = prize(runnerUp, 2);
        // In a three-player bracket the single first-round loser is third
        // automatically; larger brackets get a dedicated bronze match.
        final earlierLosers = <String>[];
        for (final doc in allMatchesSnapshot.docs) {
          final item = doc.data();
          if (((item['round'] as num?)?.toInt() ?? 0) >= round ||
              item['status'] != 'completed') continue;
          final winner = item['winnerUid'] as String?;
          final p1 = item['player1Uid'] as String?;
          final p2 = item['player2Uid'] as String?;
          final loser = winner == p1 ? p2 : (winner == p2 ? p1 : null);
          if (loser != null) earlierLosers.add(loser);
        }
        if (earlierLosers.length == 1) {
          placements[earlierLosers.single] = prize(earlierLosers.single, 3);
        }
        await publishFinalPlacements(placements, winnerUid: champion);
        return;
      }
      var nextMatchIndex = 0;
      final losers = <String>[];
      for (final item in roundMatches) {
        final winner = item['winnerUid'] as String?;
        final p1 = item['player1Uid'] as String?;
        final p2 = item['player2Uid'] as String?;
        final loser = winner == p1 ? p2 : (winner == p2 ? p1 : null);
        if (loser != null) losers.add(loser);
      }
      for (var i = 0; i < winners.length; i += 2) {
        nextMatchIndex++;
        final p1 = winners[i];
        final p2 = i + 1 < winners.length ? winners[i + 1] : null;
        String? name1;
        String? name2;
        for (final item in roundMatches) {
          if (item['player1Uid'] == p1) name1 = item['player1Name'] as String?;
          if (item['player2Uid'] == p1) name1 = item['player2Name'] as String?;
          if (p2 != null && item['player1Uid'] == p2) name2 = item['player1Name'] as String?;
          if (p2 != null && item['player2Uid'] == p2) name2 = item['player2Name'] as String?;
        }
        tx.set(tournament.collection('matches').doc('r${round + 1}_m$nextMatchIndex'), {
          'round': round + 1,
          'matchIndex': nextMatchIndex,
          'player1Uid': p1,
          'player1Name': name1 ?? 'Oyuncu',
          'player2Uid': p2,
          'player2Name': p2 == null ? null : (name2 ?? 'Oyuncu'),
          'winnerUid': p2 == null ? p1 : null,
          'status': p2 == null ? 'completed' : 'ready',
          'isBye': p2 == null,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      if (winners.length == 2 && losers.length >= 2) {
        nextMatchIndex++;
        final loser1 = losers[0];
        final loser2 = losers[1];
        String nameFor(String uid) {
          for (final item in roundMatches) {
            if (item['player1Uid'] == uid) return item['player1Name'] as String? ?? 'Oyuncu';
            if (item['player2Uid'] == uid) return item['player2Name'] as String? ?? 'Oyuncu';
          }
          return 'Oyuncu';
        }
        tx.set(tournament.collection('matches').doc('r${round + 1}_m$nextMatchIndex'), {
          'round': round + 1,
          'matchIndex': nextMatchIndex,
          'player1Uid': loser1,
          'player1Name': nameFor(loser1),
          'player2Uid': loser2,
          'player2Name': nameFor(loser2),
          'winnerUid': null,
          'status': 'ready',
          'isThirdPlace': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      tx.update(tournament, {
        'currentRound': round + 1,
        'matchCount': FieldValue.increment(nextMatchIndex),
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
      if (memberSnap.exists) return true;
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
          'playerDeviceId': '',
          'displayName': data['displayName'] ?? 'Oyuncu',
          'joinedAt': FieldValue.serverTimestamp(),
          'role': 'member',
        });
        tx.update(channel, {
          'memberCount': ((channelSnap.data()?['memberCount'] as num?) ?? 0).toInt() + 1,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      tx.delete(request);
    });
  }

  Future<String?> getChannelInviteCode(String channelId, String uid) async {
    _requireChannelUid(uid);
    final channel = _channels.doc(channelId);
    final snap = await channel.collection('private').doc('invite').get();
    if (snap.data()?['inviteCode'] is String) return snap.data()!['inviteCode'] as String;
    return null;
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
    if ((await member.get()).exists) return true;
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

  Future<void> leaveChannel(String channelId, String deviceId) async {
    final uid = _requireChannelUid(deviceId);
    final channel = _channels.doc(channelId);
    final member = channel.collection('members').doc(uid);
    final memberDocs = await channel.collection('members').get();
    final replacement = memberDocs.docs.where((d) => d.id != uid).toList();
    final nextOwner = replacement.isEmpty ? null : replacement.first;
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
        if (isOwner) ...{
          'ownerDeviceId': nextOwner?.id,
          'ownerDisplayName': nextOwner?.data()['displayName'],
          if (nextOwner == null) 'status': 'closed',
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
    try {
      await FirebaseFirestore.instance.collection('reports').add({
        'roomCode': roomCode,
        'reporterDeviceId': reporterDeviceId,
        'reportedDeviceId': reportedDeviceId,
        'reason': reason,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
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
