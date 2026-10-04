import 'dart:math';
import '../models/playing_card.dart';

enum PlayerSide { player1, player2 }

enum GameStatus { playing, player1Wins, player2Wins }

/// STRES / REFLEKS oyun motoru.
///
/// - 52 kağıt, 2 oyuncuya 26'şar dağıtılır.
/// - Her oyuncunun 4 kağıdı oyun alanına yerleştirilir: toplam 8 kolon.
///   Kolon 0-3: Oyuncu 1'in önünde. Kolon 4-7: Oyuncu 2'nin önünde.
/// - Kalan 22'şer kağıt oyuncuların kapalı destesi (stock) olur.
///
/// AKTİFLİK KURALI ("yapışkan" mantık):
/// Üst kartı aynı değere sahip en az 2 kolon oluştuğunda, o kolonların
/// TAMAMI "aktif" (tıklanabilir) olarak işaretlenir. Bir kolon aktif
/// olduktan sonra, EŞLEŞTİĞİ diğer kolon kapatılmış olsa bile, KENDİSİ
/// kapatılana kadar aktif kalmaya devam eder. Yani 3 kolon aynı değere
/// sahipse ve biri kapatılırsa, diğer ikisi (birbirleriyle hâlâ eşit
/// olsun ya da olmasın) aktif kalır; sadece kapatılan kolon aktifliğini
/// kaybeder (ve üstüne gelen yeni kart başka bir eşleşme yaratırsa
/// yeniden aktif olabilir).
///
/// - Aktif kolon kalmayınca (kilitlenme): her oyuncu kendi 4 kolonundaki
///   TÜM kartları toplayıp kendi kapalı destesine ekler (toplanan kartlar
///   yeniden karılır), ardından kapalı destesinden yeniden 4'er kart
///   açarak kolonlar yenilenir.
/// - Kapalı destesini ilk tamamen bitiren oyuncu kazanır.
///
/// ART ARDA HAMLE AVANTAJI:
/// Bir oyuncu, RAKİBİ ARADA HİÇ HAMLE YAPMADAN art arda 3 hamle yaparsa
/// 1 kart, 5 hamle yaparsa 2 kart, 8 hamle yaparsa 3 kart avantaj
/// kazanır — bu kartlar kendi kapalı destesinden düşürülür (hiç
/// oynamadan "bitmiş" sayılır), kazanmaya bir adım yaklaştırır. Rakip
/// herhangi bir hamle yaptığı an sayaç sıfırlanır.
class GameEngine {
  static const int columnCount = 8;
  static const int columnsPerPlayer = 4;

  /// Eşik -> avantaj kartı sayısı.
  static const Map<int, int> streakBonusThresholds = {3: 1, 5: 2, 8: 3};

  final List<PlayingCard> player1Stock = [];
  final List<PlayingCard> player2Stock = [];
  final List<List<PlayingCard>> columns =
      List.generate(columnCount, (_) => <PlayingCard>[]);

  /// "Yapışkan" aktif kolon kümesi — bkz. sınıf yorumu.
  final Set<int> _unlocked = {};

  int _p1Streak = 0;
  int _p2Streak = 0;
  final Set<int> _p1TriggeredThresholds = {};
  final Set<int> _p2TriggeredThresholds = {};

  /// Sadece BU CİHAZDA, hemen callback ile bildirim almak için (yerel ve
  /// bota karşı modlarda kullanılır). Online modda bunun yerine
  /// [streakEventId] ile senkronize edilen alanlar kullanılıyor.
  void Function(PlayerSide side, int bonusCards)? onStreakBonus;

  /// Her yeni avantaj tetiklendiğinde artan sayaç — online modda
  /// istemcilerin "bu olayı daha önce gördüm mü" diye kontrol edebilmesi
  /// için Firestore'a da yazılıyor.
  int streakEventId = 0;
  int? lastStreakBonusAmount;
  String? lastStreakBonusSide; // 'player1' | 'player2'

  GameStatus status = GameStatus.playing;
  final Random _random;

  GameEngine({int? seed}) : _random = seed != null ? Random(seed) : Random();

  bool _ownedByPlayer1(int columnIndex) => columnIndex < columnsPerPlayer;

  List<PlayingCard> stockOf(PlayerSide side) =>
      side == PlayerSide.player1 ? player1Stock : player2Stock;

  void startNewGame() {
    player1Stock.clear();
    player2Stock.clear();
    for (final c in columns) {
      c.clear();
    }
    _unlocked.clear();
    status = GameStatus.playing;
    locked = true; // açılış animasyonu bitene kadar hamle yok
    _p1Streak = 0;
    _p2Streak = 0;
    _p1TriggeredThresholds.clear();
    _p2TriggeredThresholds.clear();
    streakEventId = 0;
    lastStreakBonusAmount = null;
    lastStreakBonusSide = null;

    final deck = buildStandardDeck()..shuffle(_random);
    final p1 = deck.sublist(0, 26);
    final p2 = deck.sublist(26, 52);

    for (var i = 0; i < columnsPerPlayer; i++) {
      columns[i].add(p1[i]);
    }
    player1Stock.addAll(p1.sublist(columnsPerPlayer));

    for (var i = 0; i < columnsPerPlayer; i++) {
      columns[columnsPerPlayer + i].add(p2[i]);
    }
    player2Stock.addAll(p2.sublist(columnsPerPlayer));

    _refreshMatches();
  }

  PlayingCard? topOf(int columnIndex) =>
      columns[columnIndex].isEmpty ? null : columns[columnIndex].last;

  /// Şu anki üst kartlara bakarak YENİ eşleşmeleri bulur ve mevcut
  /// "yapışkan" kümeye ekler (var olanları ASLA çıkarmaz).
  void _refreshMatches() {
    final byRank = <int, List<int>>{};
    for (var i = 0; i < columnCount; i++) {
      final top = topOf(i);
      if (top == null) continue;
      byRank.putIfAbsent(top.rank, () => []).add(i);
    }
    for (final group in byRank.values) {
      if (group.length >= 2) _unlocked.addAll(group);
    }
  }

  /// Açılış animasyonu (8 kartın 0.5 saniye aralıklarla açılması) devam
  /// ederken true yapılır. Bu true iken HİÇBİR taraf (bot dahil) hamle
  /// yapamaz — bkz. attemptPlay ve BotAi._tick.
  bool locked = false;

  /// Aktif (tıklanabilir) kolonların indeksleri.
  Set<int> get activeColumns => Set.unmodifiable(_unlocked);

  bool isColumnActive(int columnIndex) => _unlocked.contains(columnIndex);

  /// [side] oyuncusu [columnIndex] kolonuna tıklar: kendi kapalı
  /// destesinden bir kart çeker, o kolonun üzerine açık koyar.
  /// Başarılıysa true döner.
  bool attemptPlay(PlayerSide side, int columnIndex) {
    if (locked) return false;
    if (status != GameStatus.playing) return false;
    if (!isColumnActive(columnIndex)) return false;

    final stock = stockOf(side);
    if (stock.isEmpty) return false;

    // Bu kolon artık kapatılıyor: aktiflik kaybolur (yeni değeriyle
    // başka bir eşleşme oluşursa _refreshMatches onu yeniden ekleyecek).
    _unlocked.remove(columnIndex);

    final card = stock.removeLast();
    columns[columnIndex].add(card);

    _registerMove(side);
    if (status != GameStatus.playing) return true; // avantajla kazanmış olabilir

    if (stock.isEmpty) {
      status = side == PlayerSide.player1
          ? GameStatus.player1Wins
          : GameStatus.player2Wins;
      return true;
    }

    _refreshMatches();
    // NOT: Kilitlenme (activeColumns.isEmpty) burada OTOMATİK toplanmaz.
    // Arayüz (UI) önce "Benzer Kalmadı" uyarısını göstermeli, 1 saniye
    // beklemeli, sonra collectAndRedeal() çağırmalıdır.
    return true;
  }

  /// Art arda hamle sayaçlarını günceller; eşik aşıldıysa avantajı
  /// uygular. [side] hamle yapan taraf; karşı tarafın sayacı sıfırlanır.
  void _registerMove(PlayerSide side) {
    if (side == PlayerSide.player1) {
      _p1Streak++;
      _p2Streak = 0;
      _p2TriggeredThresholds.clear();
      _checkStreakBonus(PlayerSide.player1, _p1Streak, _p1TriggeredThresholds);
    } else {
      _p2Streak++;
      _p1Streak = 0;
      _p1TriggeredThresholds.clear();
      _checkStreakBonus(PlayerSide.player2, _p2Streak, _p2TriggeredThresholds);
    }
  }

  void _checkStreakBonus(PlayerSide side, int streak, Set<int> triggered) {
    final bonus = streakBonusThresholds[streak];
    if (bonus == null || triggered.contains(streak)) return;
    triggered.add(streak);

    final stock = stockOf(side);
    final removeCount = bonus > stock.length ? stock.length : bonus;
    for (var i = 0; i < removeCount; i++) {
      stock.removeLast();
    }

    streakEventId++;
    lastStreakBonusAmount = bonus;
    lastStreakBonusSide = side == PlayerSide.player1 ? 'player1' : 'player2';
    onStreakBonus?.call(side, bonus);

    if (stock.isEmpty && status == GameStatus.playing) {
      status = side == PlayerSide.player1
          ? GameStatus.player1Wins
          : GameStatus.player2Wins;
    }
  }

  /// Oyun devam ederken aktif kolon kalmadıysa true döner (kilitlenme).
  bool get isDeadlocked => status == GameStatus.playing && _unlocked.isEmpty;

  /// Kural 13-14: her oyuncu kendi 4 kolonundaki kartları toplar, karar,
  /// yeniden 4'er kart açar. UI, "Benzer Kalmadı" mesajını gösterip 1
  /// saniye bekledikten SONRA bu metodu çağırmalıdır.
  void collectAndRedeal() {
    locked = true; // yeni açılış animasyonu bitene kadar hamle yok
    for (var i = 0; i < columnCount; i++) {
      final target = _ownedByPlayer1(i) ? player1Stock : player2Stock;
      target.insertAll(0, columns[i]);
      columns[i].clear();
    }
    player1Stock.shuffle(_random);
    player2Stock.shuffle(_random);

    _unlocked.clear();
    _dealColumnsFor(PlayerSide.player1);
    _dealColumnsFor(PlayerSide.player2);
    _refreshMatches();
  }

  void _dealColumnsFor(PlayerSide side) {
    final stock = stockOf(side);
    final startCol = side == PlayerSide.player1 ? 0 : columnsPerPlayer;
    final dealCount = min(columnsPerPlayer, stock.length);
    for (var i = 0; i < dealCount; i++) {
      columns[startCol + i].add(stock.removeLast());
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'player1Stock': player1Stock.map((c) => c.toCode()).toList(),
      'player2Stock': player2Stock.map((c) => c.toCode()).toList(),
      // Firestore iç içe dizileri (array içinde array) desteklemediği için
      // her kolon, kartları virgülle ayrılmış TEK bir metin olarak saklanır.
      'columns': columns
          .map((col) => col.map((c) => c.toCode()).join(','))
          .toList(),
      'unlocked': _unlocked.toList(),
      'status': status.name,
      'streakEventId': streakEventId,
      'lastStreakBonusAmount': lastStreakBonusAmount,
      'lastStreakBonusSide': lastStreakBonusSide,
    };
  }

  void loadFromMap(Map<String, dynamic> map) {
    List<PlayingCard> decodeList(List raw) =>
        raw.map((e) => PlayingCard.fromCode(e as String)).toList();

    List<PlayingCard> decodeColumnString(String raw) => raw.isEmpty
        ? <PlayingCard>[]
        : raw.split(',').map(PlayingCard.fromCode).toList();

    player1Stock
      ..clear()
      ..addAll(decodeList(map['player1Stock'] as List));
    player2Stock
      ..clear()
      ..addAll(decodeList(map['player2Stock'] as List));

    final rawColumns = map['columns'] as List;
    for (var i = 0; i < columnCount; i++) {
      columns[i]
        ..clear()
        ..addAll(decodeColumnString(rawColumns[i] as String));
    }

    _unlocked
      ..clear()
      ..addAll((map['unlocked'] as List? ?? const [])
          .map((e) => e as int));

    status = GameStatus.values.firstWhere((s) => s.name == map['status']);
    streakEventId = (map['streakEventId'] as num?)?.toInt() ?? 0;
    lastStreakBonusAmount = (map['lastStreakBonusAmount'] as num?)?.toInt();
    lastStreakBonusSide = map['lastStreakBonusSide'] as String?;
  }
}
