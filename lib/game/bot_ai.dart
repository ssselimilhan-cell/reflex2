import 'dart:async';
import 'dart:math';
import 'bot_profile.dart';
import 'game_engine.dart';

/// Refleks botu: periyodik olarak aktif kolon olup olmadığına bakar,
/// varsa bir tanesini seçip insansı bir gecikmeyle oynar.
///
/// İki çalışma biçimi var:
///  - [profile] verilmezse: eski davranış ([difficulty] 0.0-1.0, rastgele
///    kolon seçimi). Hızlı eşleşme yedeği ve ilk açılış eğitimi bunu kullanır.
///  - [profile] verilirse: Bot Yolu seviyesi (bkz. [BotProfile]).
class BotAi {
  final GameEngine engine;
  final PlayerSide side;
  final void Function() onMove;
  final BotProfile? profile;
  Timer? _timer;
  final Random _random = Random();

  /// difficulty: 0.0 (çok yavaş/kaçırır) - 1.0 (çok hızlı/kusursuz)
  double difficulty;

  BotAi(this.engine, this.side, this.onMove,
      {this.difficulty = 0.5, this.profile});

  void start() => _scheduleNextCheck();

  void stop() => _timer?.cancel();

  void _scheduleNextCheck() {
    final p = profile;
    final int ms;
    if (p != null) {
      ms = p.baseMs + _random.nextInt(p.jitterMs + 1);
    } else {
      final baseMs = 900 - (difficulty * 700);
      ms = baseMs.toInt() + _random.nextInt(300);
    }
    _timer = Timer(Duration(milliseconds: ms), _tick);
  }

  void _tick() {
    if (engine.status != GameStatus.playing) return;
    if (engine.locked) {
      // Açılış animasyonu (8 kart açılırken) sürüyor — bot da beklemeli.
      _scheduleNextCheck();
      return;
    }

    final p = profile;
    final missChance = p != null ? p.missChance : (1.0 - difficulty) * 0.4;
    if (_random.nextDouble() >= missChance) {
      final active = engine.activeColumns.toList();
      if (active.isNotEmpty && engine.stockOf(side).isNotEmpty) {
        final col = p != null
            ? _choose(active, p)
            : active[_random.nextInt(active.length)];
        if (col != null && engine.attemptPlay(side, col)) onMove();
      }
    }
    _scheduleNextCheck();
  }

  /// Rakibin kolonu mu? (El yenilenince o kolondaki kartlar rakibe geçer.)
  bool _isOpponentColumn(int c) => side == PlayerSide.player2
      ? c < GameEngine.columnsPerPlayer
      : c >= GameEngine.columnsPerPlayer;

  int? _choose(List<int> active, BotProfile p) {
    // Akıllı seçim yapmadığı anlarda rastgele oynar (seviye 1-40 arası
    // giderek azalır).
    if (_random.nextDouble() >= p.smartness) {
      return active[_random.nextInt(active.length)];
    }
    final opp = active.where(_isOpponentColumn).toList();
    List<int> pool;
    if (opp.isNotEmpty) {
      pool = opp;
    } else {
      // Sadece kendi tarafında aktif kolon var: kartını heba etmemek için
      // çoğu zaman bekler, ama sonsuza kadar da kilitlenmez.
      if (_random.nextDouble() >= p.ownSidePlay) return null;
      pool = active;
    }
    if (pool.length > 1 && _random.nextDouble() < p.chainSkill) {
      final c = _chainColumn(pool);
      if (c != null) return c;
    }
    return pool[_random.nextInt(pool.length)];
  }

  /// Oynayacağı kart, havuzdaki hangi kolona konunca başka bir kolonun
  /// üst kartıyla eşleşir (yeni bir aktif kolon doğurur)?
  int? _chainColumn(List<int> pool) {
    final stock = engine.stockOf(side);
    if (stock.isEmpty) return null;
    final next = stock.last;
    final candidates = <int>[];
    for (final c in pool) {
      for (var j = 0; j < GameEngine.columnCount; j++) {
        if (j == c) continue;
        final top = engine.topOf(j);
        if (top != null && top.rank == next.rank) {
          candidates.add(c);
          break;
        }
      }
    }
    if (candidates.isEmpty) return null;
    return candidates[_random.nextInt(candidates.length)];
  }
}
