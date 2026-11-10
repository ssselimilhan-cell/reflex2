import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
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
        .orderBy('createdAt', descending: true)
        .limit(30)
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


  // ---- Kalıcı oyuncu kanalları (geçici maç odalarından bağımsız) ----

  CollectionReference<Map<String, dynamic>> get _channels =>
      FirebaseFirestore.instance.collection('channels');

  Stream<QuerySnapshot<Map<String, dynamic>>> watchChannels() =>
      _channels.orderBy('updatedAt', descending: true).limit(50).snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> watchChannelTournaments(String channelId) =>
      _channels.doc(channelId).collection('tournaments')
          .orderBy('createdAt', descending: true).snapshots();

  Future<String> createChannelTournament({
    required String channelId,
    required String creatorDeviceId,
    required String title,
    required String format,
    required int maxPlayers,
  }) async {
    final channel = _channels.doc(channelId);
    final snapshot = await channel.get();
    if (!snapshot.exists || snapshot.data()?['ownerDeviceId'] != creatorDeviceId) {
      throw StateError('Yalnızca kanal kurucusu turnuva oluşturabilir.');
    }
    final ref = channel.collection('tournaments').doc();
    await ref.set({
      'title': title.trim(),
      'format': format,
      'maxPlayers': maxPlayers,
      'status': 'registration',
      'creatorDeviceId': creatorDeviceId,
      'participantIds': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<bool> joinChannelTournament({
    required String channelId,
    required String tournamentId,
    required String deviceId,
  }) async {
    final ref = _channels.doc(channelId).collection('tournaments').doc(tournamentId);
    return FirebaseFirestore.instance.runTransaction<bool>((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return false;
      final data = snap.data()!;
      if (data['status'] != 'registration') return false;
      final ids = List<String>.from(data['participantIds'] ?? const <String>[]);
      if (ids.contains(deviceId)) return true;
      final max = (data['maxPlayers'] as num?)?.toInt() ?? 32;
      if (ids.length >= max) return false;
      tx.update(ref, {'participantIds': FieldValue.arrayUnion([deviceId])});
      return true;
    });
  }

  Future<void> startChannelTournament({
    required String channelId,
    required String tournamentId,
    required String creatorDeviceId,
  }) async {
    final channel = _channels.doc(channelId);
    final tournament = channel.collection('tournaments').doc(tournamentId);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final channelSnap = await tx.get(channel);
      final tournamentSnap = await tx.get(tournament);
      if (!channelSnap.exists || !tournamentSnap.exists ||
          channelSnap.data()?['ownerDeviceId'] != creatorDeviceId ||
          tournamentSnap.data()?['status'] != 'registration') {
        throw StateError('Turnuva başlatılamadı.');
      }
      tx.update(tournament, {'status': 'in_progress', 'startedAt': FieldValue.serverTimestamp()});
    });
  }

  Future<String?> findChannelByInviteCode(String code) async {
    final result = await _channels.where('inviteCode', isEqualTo: code.trim().toUpperCase()).limit(1).get();
    if (result.docs.isEmpty || result.docs.first.data()['visibility'] != 'invite_only') return null;
    return result.docs.first.id;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchChannelMembers(String channelId) =>
      _channels.doc(channelId).collection('members').orderBy('joinedAt').snapshots();

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchChannelMembership(
      String channelId, String deviceId) =>
      _channels.doc(channelId).collection('members').doc(deviceId).snapshots();

  Future<String> createChannel({
    required String ownerDeviceId,
    required String ownerDisplayName,
    required String name,
    required String description,
    bool inviteOnly = false,
  }) async {
    final ref = _channels.doc();
    const inviteChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final inviteRandom = Random();
    final inviteCode = List.generate(8, (_) => inviteChars[inviteRandom.nextInt(inviteChars.length)]).join();
    final now = FieldValue.serverTimestamp();
    final batch = FirebaseFirestore.instance.batch();
    batch.set(ref, {
      'name': name.trim(),
      'description': description.trim(),
      'ownerDeviceId': ownerDeviceId,
      'ownerDisplayName': ownerDisplayName,
      'memberCount': 1,
      'createdAt': now,
      'updatedAt': now,
      'status': 'open',
      'visibility': inviteOnly ? 'invite_only' : 'public',
      'inviteCode': inviteCode,
    });
    batch.set(ref.collection('members').doc(ownerDeviceId), {
      'deviceId': ownerDeviceId,
      'displayName': ownerDisplayName,
      'joinedAt': now,
      'role': 'owner',
    });
    await batch.commit();
    return ref.id;
  }

  Future<bool> joinChannel({
    required String channelId,
    required String deviceId,
    required String displayName,
    String? inviteCode,
  }) async {
    final channel = _channels.doc(channelId);
    final member = channel.collection('members').doc(deviceId);
    return FirebaseFirestore.instance.runTransaction<bool>((tx) async {
      final channelSnap = await tx.get(channel);
      if (!channelSnap.exists || channelSnap.data()?['status'] != 'open') return false;
      final channelData = channelSnap.data()!;
      if (channelData['visibility'] == 'invite_only' &&
          (inviteCode == null || inviteCode.trim().toUpperCase() != channelData['inviteCode'])) return false;
      final memberSnap = await tx.get(member);
      if (memberSnap.exists) return true;
      final data = channelSnap.data()!;
      final becomesOwner = data['ownerDeviceId'] == null;
      tx.set(member, {
        'deviceId': deviceId,
        'displayName': displayName,
        'joinedAt': FieldValue.serverTimestamp(),
        'role': becomesOwner ? 'owner' : 'member',
      });
      tx.update(channel, {
        'memberCount': ((data['memberCount'] as num?) ?? 0).toInt() + 1,
        if (becomesOwner) ...{
          'ownerDeviceId': deviceId,
          'ownerDisplayName': displayName,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    });
  }

  Future<bool> joinPrivateChannelByCode({
    required String code,
    required String deviceId,
    required String displayName,
  }) async {
    final channelId = await findChannelByInviteCode(code);
    if (channelId == null) return false;
    return joinChannel(channelId: channelId, deviceId: deviceId,
        displayName: displayName, inviteCode: code);
  }

  Future<void> leaveChannel(String channelId, String deviceId) async {
    final channel = _channels.doc(channelId);
    final member = channel.collection('members').doc(deviceId);
    final memberDocs = await channel.collection('members').get();
    final replacement = memberDocs.docs.where((d) => d.id != deviceId).toList();
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
      final isOwner = data['ownerDeviceId'] == deviceId;
      tx.delete(member);
      if (isOwner && nextOwnerRef != null && nextOwnerSnap?.exists == true) {
        tx.update(nextOwnerRef, {'role': 'owner'});
      }
      tx.update(channel, {
        'memberCount': (((data['memberCount'] as num?) ?? 1).toInt() - 1).clamp(0, 999999),
        if (isOwner) ...{
          'ownerDeviceId': nextOwner?.id,
          'ownerDisplayName': nextOwner?.data()['displayName'],
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });
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
