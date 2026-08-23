import 'dart:async';
import 'package:flutter/material.dart';
import '../game/game_engine.dart';
import '../game/bot_ai.dart';
import '../widgets/card_widget.dart';

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
  final List<Timer> _pendingTimers = [];

  @override
  void initState() {
    super.initState();
    _startNewGame();
  }

  void _startNewGame() {
    engine = GameEngine();
    engine.onRedeal = _startReveal;
    engine.startNewGame();
    bot = BotAi(engine, PlayerSide.player2, () {
      if (mounted) setState(() {});
    }, difficulty: difficulty)
      ..start();
    _startReveal();
  }

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

  @override
  void dispose() {
    bot.stop();
    for (final t in _pendingTimers) {
      t.cancel();
    }
    super.dispose();
  }

  void _tap(int columnIndex) {
    if (_revealing) return;
    setState(() {
      engine.attemptPlay(PlayerSide.player1, columnIndex);
    });
  }

  @override
  Widget build(BuildContext context) {
    final finished = engine.status != GameStatus.playing;
    final active = _revealing ? <int>{} : engine.activeColumns;

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
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text('Zorluk:', style: TextStyle(color: Colors.white)),
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
            Text('Bot kaynağı: ${engine.player2Stock.length}',
                style: const TextStyle(color: Colors.white70)),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(GameEngine.columnCount, (i) {
                final top = engine.topOf(i);
                final isRevealed = revealed[i];
                final isActive = active.contains(i);
                return Padding(
                  padding: EdgeInsets.only(left: i == 4 ? 20 : 4, right: 4),
                  child: CardWidget(
                    card: top,
                    faceDown: !isRevealed || top == null,
                    highlighted: isActive && isRevealed,
                    onTap:
                        (isActive && isRevealed) ? () => _tap(i) : null,
                    width: 48,
                    height: 70,
                  ),
                );
              }),
            ),
            const Spacer(),
            if (finished)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  engine.status == GameStatus.player1Wins
                      ? 'Kazandın!'
                      : 'Bot Kazandı!',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
              ),
            Text('Kaynak: ${engine.player1Stock.length}',
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
