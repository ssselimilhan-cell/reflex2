import 'dart:async';
import 'package:flutter/material.dart';
import '../game/game_engine.dart';
import '../widgets/card_widget.dart';
import '../widgets/deck_stack_widget.dart';

/// Aynı cihazda 2 kişilik mod.
///
/// Ekran ortadan ikiye bölünür; HER İKİ yarıda da AYNI 8 sütun (aynı
/// mantıksal oyun durumu) simetrik biçimde gösterilir. Üstteki yarı
/// 180° döndürülmüştür ki karşıda oturan oyuncu da düzgün okuyabilsin.
/// Bu sayede her oyuncu kendi tarafına dokunarak TÜM 8 aktif sütuna
/// erişebilir (kural 9 tam uygulanmış olur), ekranın "kimin dokunduğunu"
/// anlaması ise hangi yarıya dokunulduğuna bakarak çözülür.
class LocalPvpScreen extends StatefulWidget {
  const LocalPvpScreen({super.key});

  @override
  State<LocalPvpScreen> createState() => _LocalPvpScreenState();
}

class _LocalPvpScreenState extends State<LocalPvpScreen> {
  late GameEngine engine;
  List<bool> revealed = List.filled(GameEngine.columnCount, true);
  bool _revealing = false;
  bool _showNoMatch = false;
  final List<Timer> _pendingTimers = [];

  @override
  void initState() {
    super.initState();
    engine = GameEngine()..startNewGame();
    _startReveal();
  }

  @override
  void dispose() {
    for (final t in _pendingTimers) {
      t.cancel();
    }
    super.dispose();
  }

  void _startReveal() {
    for (final t in _pendingTimers) {
      t.cancel();
    }
    _pendingTimers.clear();
    setState(() {
      revealed = List.filled(GameEngine.columnCount, false);
      _revealing = true;
      _showNoMatch = false;
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
          if (i == pairs.length - 1) {
            _revealing = false;
            if (engine.isDeadlocked) {
              WidgetsBinding.instance
                  .addPostFrameCallback((_) => _handleDeadlock());
            }
          }
        });
      });
      _pendingTimers.add(timer);
    }
  }

  void _tap(PlayerSide side, int columnIndex) {
    if (_revealing || _showNoMatch) return;
    setState(() {
      engine.attemptPlay(side, columnIndex);
    });
    if (engine.isDeadlocked) {
      _handleDeadlock();
    }
  }

  void _handleDeadlock() {
    if (_showNoMatch) return;
    setState(() => _showNoMatch = true);
    final timer = Timer(const Duration(seconds: 1), () {
      if (!mounted) return;
      engine.collectAndRedeal();
      _startReveal();
    });
    _pendingTimers.add(timer);
  }

  void _restart() {
    for (final t in _pendingTimers) {
      t.cancel();
    }
    setState(() => engine.startNewGame());
    _startReveal();
  }

  @override
  Widget build(BuildContext context) {
    final finished = engine.status != GameStatus.playing;
    final active =
        (_revealing || _showNoMatch) ? <int>{} : engine.activeColumns;

    return Scaffold(
      backgroundColor: const Color(0xFF0B6E4F),
      appBar: AppBar(
        title: const Text('2 Kişilik - Aynı Cihaz'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _restart),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Oyuncu 2'nin yarısı (üst, 180° döndürülmüş — karşıdan okunur)
                Expanded(
                  child: RotatedBox(
                    quarterTurns: 2,
                    child: _FullBoardHalf(
                      engine: engine,
                      revealed: revealed,
                      active: active,
                      onTap: (i) => _tap(PlayerSide.player2, i),
                      stockCount: engine.player2Stock.length,
                      label: 'Oyuncu 2',
                    ),
                  ),
                ),
                const Divider(color: Colors.white24, height: 1),
                // Oyuncu 1'in yarısı (alt, normal yön)
                Expanded(
                  child: _FullBoardHalf(
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
            if (finished)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(12),
                  ),
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
              )
            else if (_showNoMatch)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Benzer Kalmadı',
                    style: TextStyle(
                        color: Colors.amber,
                        fontSize: 22,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Tek bir oyuncunun yarısında, AYNI 8 sütunun tamamını 2 sıra x 4
/// düzeninde gösterir (x y z t / a b c d). Herhangi bir aktif karta
/// dokunmak, bu yarının sahibi olan oyuncunun kartını oynatır.
class _FullBoardHalf extends StatelessWidget {
  final GameEngine engine;
  final List<bool> revealed;
  final Set<int> active;
  final void Function(int columnIndex) onTap;
  final int stockCount;
  final String label;

  const _FullBoardHalf({
    required this.engine,
    required this.revealed,
    required this.active,
    required this.onTap,
    required this.stockCount,
    required this.label,
  });

  Widget _buildCard(int i) {
    final top = engine.topOf(i);
    final isRevealed = revealed[i];
    final isActive = active.contains(i);
    return Padding(
      padding: const EdgeInsets.all(3),
      child: CardWidget(
        card: top,
        faceDown: !isRevealed || top == null,
        highlighted: isActive && isRevealed,
        onTap: (isActive && isRevealed) ? () => onTap(i) : null,
        width: 40,
        height: 58,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        DeckStackWidget(count: stockCount, label: label),
        const SizedBox(width: 12),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [0, 1, 2, 3].map(_buildCard).toList(),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [4, 5, 6, 7].map(_buildCard).toList(),
            ),
          ],
        ),
      ],
    );
  }
}
