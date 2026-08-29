import 'dart:async';
import 'package:flutter/material.dart';
import '../game/game_engine.dart';
import '../widgets/card_widget.dart';
import '../widgets/deck_stack_widget.dart';
import '../widgets/score_bar_widget.dart';
import '../widgets/game_result_overlay.dart';
import '../settings/app_settings.dart';
import '../settings/score_board.dart';
import '../settings/strings.dart';
import 'settings_screen.dart';

/// Aynı cihazda 2 kişilik mod.
///
/// Ekran ortadan ikiye bölünür; HER İKİ yarıda da AYNI 8 sütun (aynı
/// mantıksal oyun durumu) simetrik biçimde gösterilir. Üstteki yarı
/// 180° döndürülmüştür ki karşıda oturan oyuncu da düzgün okuyabilsin.
/// Bu sayede her oyuncu kendi tarafına dokunarak TÜM 8 aktif sütuna
/// erişebilir (kural 9 tam uygulanmış olur).
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
  bool _scoreCounted = false;
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

  int get _stepMs => (500 * AppSettings.instance.animationSpeed).round();

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
      final timer = Timer(Duration(milliseconds: _stepMs * i), () {
        if (!mounted) return;
        setState(() {
          for (final idx in pairs[i]) {
            revealed[idx] = true;
          }
          if (i == pairs.length - 1) {
            _revealing = false;
            engine.locked = false;
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
    if (engine.status != GameStatus.playing && !_scoreCounted) {
      _scoreCounted = true;
      ScoreBoard.instance.addLocal(engine.status == GameStatus.player1Wins);
    }
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
    setState(() {
      engine.startNewGame();
      _scoreCounted = false;
    });
    _startReveal();
  }

  @override
  Widget build(BuildContext context) {
    final finished = engine.status != GameStatus.playing;
    final active =
        (_revealing || _showNoMatch) ? <int>{} : engine.activeColumns;

    return AnimatedBuilder(
      animation: AppSettings.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppSettings.instance.themeColor,
          appBar: AppBar(
            title: Text(t('menu_local')),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                tooltip: t('menu_settings'),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen())),
              ),
              IconButton(icon: const Icon(Icons.refresh), onPressed: _restart),
            ],
          ),
          body: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    ListenableBuilder(
                      listenable: ScoreBoard.instance,
                      builder: (context, _) => ScoreBarWidget(
                        leftLabel: t('player1'),
                        leftScore: ScoreBoard.instance.localP1,
                        rightLabel: t('player2'),
                        rightScore: ScoreBoard.instance.localP2,
                        onReset: ScoreBoard.instance.resetLocal,
                      ),
                    ),
                    Expanded(
                      child: RotatedBox(
                        quarterTurns: 2,
                        child: _FullBoardHalf(
                          engine: engine,
                          revealed: revealed,
                          active: active,
                          onTap: (i) => _tap(PlayerSide.player2, i),
                          stockCount: engine.player2Stock.length,
                          label: t('player2'),
                        ),
                      ),
                    ),
                    const Divider(color: Colors.white24, height: 1),
                    Expanded(
                      child: _FullBoardHalf(
                        engine: engine,
                        revealed: revealed,
                        active: active,
                        onTap: (i) => _tap(PlayerSide.player1, i),
                        stockCount: engine.player1Stock.length,
                        label: t('player1'),
                      ),
                    ),
                  ],
                ),
                if (finished)
                  GameResultOverlay(
                    isWin: true, // yerel modda ikisi de "kazanan" perspektifiyle görür; başlık ayırt eder
                    title: engine.status == GameStatus.player1Wins
                        ? t('p1_won')
                        : t('p2_won'),
                    onPlayAgain: _restart,
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
                      child: Text(
                        t('no_match'),
                        style: const TextStyle(
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
      },
    );
  }
}

/// Tek bir oyuncunun yarısında, AYNI 8 sütunun tamamını 2 sıra x 4
/// düzeninde gösterir (x y z t / a b c d).
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

  Widget _buildCard(int i, double w, double h) {
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
        width: w,
        height: h,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = AppSettings.instance.cardScale;
    final w = 78.0 * scale;
    final h = 112.0 * scale;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        DeckStackWidget(count: stockCount, label: label, scale: scale),
        const SizedBox(width: 12),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children:
                      [0, 1, 2, 3].map((i) => _buildCard(i, w, h)).toList(),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children:
                      [4, 5, 6, 7].map((i) => _buildCard(i, w, h)).toList(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
