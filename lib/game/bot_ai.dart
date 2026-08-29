import 'dart:async';
import 'dart:math';
import 'game_engine.dart';

/// Basit refleks botu: periyodik olarak aktif kolon olup olmadığına bakar,
/// varsa rastgele birini seçip insansı bir gecikmeyle oynar.
class BotAi {
  final GameEngine engine;
  final PlayerSide side;
  final void Function() onMove;
  Timer? _timer;
  final Random _random = Random();

  /// difficulty: 0.0 (çok yavaş/kaçırır) - 1.0 (çok hızlı/kusursuz)
  double difficulty;

  BotAi(this.engine, this.side, this.onMove, {this.difficulty = 0.5});

  void start() => _scheduleNextCheck();

  void stop() => _timer?.cancel();

  void _scheduleNextCheck() {
    final baseMs = 900 - (difficulty * 700);
    final jitter = _random.nextInt(300);
    _timer = Timer(Duration(milliseconds: baseMs.toInt() + jitter), _tick);
  }

  void _tick() {
    if (engine.status != GameStatus.playing) return;
    if (engine.locked) {
      // Açılış animasyonu (8 kart açılırken) sürüyor — bot da beklemeli.
      _scheduleNextCheck();
      return;
    }

    final missChance = (1.0 - difficulty) * 0.4;
    if (_random.nextDouble() > missChance) {
      final active = engine.activeColumns.toList();
      if (active.isNotEmpty && engine.stockOf(side).isNotEmpty) {
        final col = active[_random.nextInt(active.length)];
        if (engine.attemptPlay(side, col)) onMove();
      }
    }
    _scheduleNextCheck();
  }
}
