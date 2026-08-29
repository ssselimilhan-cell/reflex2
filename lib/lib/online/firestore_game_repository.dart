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
      'createdAt': FieldValue.serverTimestamp(),
      ...engine.toMap(),
    });

    return code;
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

  Future<bool> joinRoom(String code, String guestDeviceId) async {
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

  /// Oyun bittikten sonra "Tekrar Oyna" için: yeni bir deste karıp
  /// dağıtır, oda "active" durumda kalır (oyuncular odadan ayrılmadan
  /// devam eder). Sadece oyun gerçekten bitmişken çalışır; iki oyuncu da
  /// aynı anda basarsa transaction sayesinde çift sıfırlama olmaz.
  Future<void> restartGame(String code) async {
    final ref = _rooms.doc(code);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data()!;
      if (data['roomStatus'] != 'active') return;

      final engine = GameEngine()..loadFromMap(data);
      if (engine.status == GameStatus.playing) return; // henüz bitmemiş
      engine.startNewGame();
      tx.update(ref, engine.toMap());
    });
  }

  Future<void> leaveRoom(String code) async {
    await _rooms.doc(code).update({'roomStatus': 'finished'});
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
}
