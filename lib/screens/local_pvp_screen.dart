import 'dart:async';
import 'package:flutter/material.dart';
import '../game/game_engine.dart';
import '../widgets/card_widget.dart';

/// Aynı cihazda 2 kişilik mod. Kurallar gereği her iki oyuncu da TÜM aktif
/// kolonlara tıklayabildiği için, ekranın hem üst (Oyuncu 2, 180° döndürülmüş)
/// hem alt (Oyuncu 1) yarısında 8 kolonun TAMAMI gösterilir; her yarı kendi
/// oyuncusunun kapalı destesiyle oynar.
class LocalPvpScreen extends StatefulWidget {
  const LocalPvpScreen({super.key});

  @override
  State<LocalPvpScreen> createState() => _LocalPvpScreenState();
}

class _LocalPvpScreenState extends State<LocalPvpScreen> {
  late GameEngine engine;
  List<bool> revealed = List.filled(GameEngine.columnCount, true);
  bool _revealing = false;
  final List<Timer> _pendingTimers = [];

  @override
  void initState() {
    super.initState();
    engine = GameEngine();
    engine.onRedeal = _startReveal;
    engine.startNewGame();
    _startReveal();
  }

  @override
  void dispose() {
    for (final t in _pendingTimers) {
      t.cancel();
    }
    super.dispose();
  }

  /// Kural 5: 8 kart, ikişerli ve karşılıklı olacak şekilde 0.5 saniye
  /// aralıklarla açılır (toplam 2 saniye).
  void _startReveal() {
    for (final t in _pendingTimers) {
      t.cancel();
    }
    _pendingTimers.clear();
    setState(() {
      revealed = List.filled(GameEngine.columnCount, false);
      _revealing = true;
    });
    const pairs = [
      [0, 4],
      [1, 5],
      [2, 6],
      [3, 7],
    ];
    for (var i = 0; i < pairs.length; i++) {
      final timer = Timer(Duration(milliseconds: 500 * i), () {
        if (!mounted) return;
        setState(() {
          for (final idx in pairs[i]) {
            revealed[idx] = true;
          }
          if (i == pairs.length - 1) _revealing = false;
        });
      });
      _pendingTimers.add(timer);
    }
  }

  void _tap(PlayerSide side, int columnIndex) {
    if (_revealing) return;
    setState(() {
      engine.attemptPlay(side, columnIndex);
    });
  }

  void _restart() {
    for (final t in _pendingTimers) {
      t.cancel();
    }
    setState(() {
      engine.startNewGame();
    });
    _startReveal();
  }

  @override
  Widget build(BuildContext context) {
    final finished = engine.status != GameStatus.playing;
    final active = _revealing ? <int>{} : engine.activeColumns;

    return Scaffold(
      backgroundColor: const Color(0xFF0B6E4F),
      appBar: AppBar(
        title: const Text('2 Kişilik - Aynı Cihaz'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _restart),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: RotatedBox(
                quarterTurns: 2,
                child: _PlayerHalf(
                  engine: engine,
                  revealed: revealed,
                  active: active,
                  onTap: (i) => _tap(PlayerSide.player2, i),
                  stockCount: engine.player2Stock.length,
                  label: 'Oyuncu 2',
                ),
              ),
            ),
            if (finished)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  engine.status == GameStatus.player1Wins
                      ? 'Oyuncu 1 Kazandı!'
                      : 'Oyuncu 2 Kazandı!',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
              ),
            Expanded(
              child: _PlayerHalf(
                engine: engine,
                revealed: revealed,
                active: active,
                onTap: (i) => _tap(PlayerSide.player1, i),
                stockCount: engine.player1Stock.length,
                label: 'Oyuncu 1',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerHalf extends StatelessWidget {
  final GameEngine engine;
  final List<bool> revealed;
  final Set<int> active;
  final void Function(int columnIndex) onTap;
  final int stockCount;
  final String label;

  const _PlayerHalf({
    required this.engine,
    required this.revealed,
    required this.active,
    required this.onTap,
    required this.stockCount,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('$label — Kaynak: $stockCount',
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(GameEngine.columnCount, (i) {
            final top = engine.topOf(i);
            final isRevealed = revealed[i];
            final isActive = active.contains(i);
            return Padding(
              padding: EdgeInsets.only(
                left: i == 4 ? 16 : 3,
                right: 3,
              ),
              child: CardWidget(
                card: top,
                faceDown: !isRevealed || top == null,
                highlighted: isActive && isRevealed,
                onTap: (isActive && isRevealed) ? () => onTap(i) : null,
                width: 40,
                height: 58,
              ),
            );
          }),
        ),
      ],
    );
  }
}
