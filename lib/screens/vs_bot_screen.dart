import 'dart:async';
import 'package:flutter/material.dart';
import '../game/game_engine.dart';
import '../game/bot_ai.dart';
import '../widgets/card_widget.dart';
import '../widgets/deck_stack_widget.dart';

class VsBotScreen extends StatefulWidget {
  const VsBotScreen({super.key});

  @override
  State<VsBotScreen> createState() => _VsBotScreenState();
}

class _VsBotScreenState extends State<VsBotScreen> {
  late GameEngine engine;
  late BotAi bot;
  double difficulty = 0.5;
  List<bool> revealed = List.filled(GameEngine.columnCount, true);
  bool _revealing = false;
  bool _showNoMatch = false;
  final List<Timer> _pendingTimers = [];

  @override
  void initState() {
    super.initState();
    _startNewGame();
  }

  void _startNewGame() {
    engine = GameEngine()..startNewGame();
    bot = BotAi(engine, PlayerSide.player2, _onBotMove, difficulty: difficulty)
      ..start();
    _startReveal();
  }

  void _onBotMove() {
    if (!mounted) return;
    setState(() {});
    if (engine.isDeadlocked && !_showNoMatch && !_revealing) {
      _handleDeadlock();
    }
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

  void _handleDeadlock() {
    setState(() => _showNoMatch = true);
    final timer = Timer(const Duration(seconds: 1), () {
      if (!mounted) return;
      engine.collectAndRedeal();
      _startReveal();
    });
    _pendingTimers.add(timer);
  }

  @override
  void dispose() {
    bot.stop();
    for (final t in _pendingTimers) {
      t.cancel();
    }
    super.dispose();
  }

  void _tap(int columnIndex) {
    if (_revealing || _showNoMatch) return;
    setState(() {
      engine.attemptPlay(PlayerSide.player1, columnIndex);
    });
    if (engine.isDeadlocked) {
      _handleDeadlock();
    }
  }

  @override
  Widget build(BuildContext context) {
    final finished = engine.status != GameStatus.playing;
    final active = (_revealing || _showNoMatch) ? <int>{} : engine.activeColumns;

    return Scaffold(
      backgroundColor: const Color(0xFF0B6E4F),
      appBar: AppBar(
        title: const Text('Bilgisayara Karşı'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              bot.stop();
              _startNewGame();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Text('Zorluk:',
                          style: TextStyle(color: Colors.white)),
                      Expanded(
                        child: Slider(
                          value: difficulty,
                          onChanged: (v) {
                            setState(() {
                              difficulty = v;
                              bot.difficulty = v;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Bot sırası (üst)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    DeckStackWidget(
                        count: engine.player2Stock.length, label: 'Bot'),
                    const SizedBox(width: 16),
                    ...[4, 5, 6, 7].map((i) => _buildCard(i, active)),
                  ],
                ),
                const SizedBox(height: 24),
                // Oyuncu sırası (alt)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    DeckStackWidget(
                        count: engine.player1Stock.length, label: 'Sen'),
                    const SizedBox(width: 16),
                    ...[0, 1, 2, 3].map((i) => _buildCard(i, active)),
                  ],
                ),
                const Spacer(),
                if (finished)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Text(
                      engine.status == GameStatus.player1Wins
                          ? 'Kazandın!'
                          : 'Bot Kazandı!',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                  )
                else
                  const SizedBox(height: 24),
              ],
            ),
            if (_showNoMatch)
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
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

  Widget _buildCard(int i, Set<int> active) {
    final top = engine.topOf(i);
    final isRevealed = revealed[i];
    final isActive = active.contains(i);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: CardWidget(
        card: top,
        faceDown: !isRevealed || top == null,
        highlighted: isActive && isRevealed,
        onTap: (isActive && isRevealed) ? () => _tap(i) : null,
        width: 52,
        height: 74,
      ),
    );
  }
}
