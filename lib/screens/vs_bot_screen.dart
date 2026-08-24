import 'dart:async';
import 'package:flutter/material.dart';
import '../game/game_engine.dart';
import '../game/bot_ai.dart';
import '../widgets/card_widget.dart';
import '../widgets/deck_stack_widget.dart';
import '../widgets/score_bar_widget.dart';
import '../settings/app_settings.dart';
import '../settings/score_board.dart';
import '../settings/strings.dart';

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
  bool _paused = false;
  bool _scoreCounted = false;
  final List<Timer> _pendingTimers = [];

  @override
  void initState() {
    super.initState();
    _startNewGame();
  }

  int get _stepMs => (500 * AppSettings.instance.animationSpeed).round();

  void _startNewGame() {
    engine = GameEngine()..startNewGame();
    _scoreCounted = false;
    _paused = false;
    bot = BotAi(engine, PlayerSide.player2, _onBotMove, difficulty: difficulty)
      ..start();
    _startReveal();
  }

  void _onBotMove() {
    if (!mounted) return;
    setState(() {});
    _checkFinishForScore();
    if (engine.isDeadlocked && !_showNoMatch && !_revealing) {
      _handleDeadlock();
    }
  }

  void _checkFinishForScore() {
    if (engine.status != GameStatus.playing && !_scoreCounted) {
      _scoreCounted = true;
      ScoreBoard.instance.addBot(engine.status == GameStatus.player1Wins);
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
      final timer = Timer(Duration(milliseconds: _stepMs * i), () {
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
    if (_revealing || _showNoMatch || _paused) return;
    setState(() {
      engine.attemptPlay(PlayerSide.player1, columnIndex);
    });
    _checkFinishForScore();
    if (engine.isDeadlocked) {
      _handleDeadlock();
    }
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
    if (_paused) {
      bot.stop();
    } else if (engine.status == GameStatus.playing) {
      bot.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final finished = engine.status != GameStatus.playing;
    final active = (_revealing || _showNoMatch || _paused)
        ? <int>{}
        : engine.activeColumns;
    final scale = AppSettings.instance.cardScale;
    final cardW = 100.0 * scale;
    final cardH = 142.0 * scale;

    return AnimatedBuilder(
      animation: AppSettings.instance,
      builder: (context, _) {
        final difficultyColor =
            Color.lerp(Colors.greenAccent, Colors.redAccent, difficulty)!;
        return Scaffold(
          backgroundColor: AppSettings.instance.themeColor,
          appBar: AppBar(
            title: Text(t('menu_bot')),
            actions: [
              IconButton(
                icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
                onPressed: finished ? null : _togglePause,
                tooltip: _paused ? t('resume') : t('pause'),
              ),
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
                    ListenableBuilder(
                      listenable: ScoreBoard.instance,
                      builder: (context, _) => ScoreBarWidget(
                        leftLabel: t('you'),
                        leftScore: ScoreBoard.instance.youVsBot,
                        rightLabel: t('bot'),
                        rightScore: ScoreBoard.instance.botVsYou,
                        onReset: ScoreBoard.instance.resetBot,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Text('${t('difficulty')}:',
                              style: const TextStyle(color: Colors.white)),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: difficultyColor,
                                thumbColor: difficultyColor,
                                overlayColor: difficultyColor.withOpacity(0.2),
                              ),
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
                          ),
                          SizedBox(
                            width: 44,
                            child: Text(
                              '${(difficulty * 100).round()}%',
                              style: TextStyle(
                                  color: difficultyColor,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        DeckStackWidget(
                            count: engine.player2Stock.length,
                            label: t('bot'),
                            scale: scale),
                        const SizedBox(width: 16),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [4, 5, 6, 7]
                                  .map((i) =>
                                      _buildCard(i, active, cardW, cardH))
                                  .toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        DeckStackWidget(
                            count: engine.player1Stock.length,
                            label: t('you'),
                            scale: scale),
                        const SizedBox(width: 16),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [0, 1, 2, 3]
                                  .map((i) =>
                                      _buildCard(i, active, cardW, cardH))
                                  .toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (finished)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Text(
                          engine.status == GameStatus.player1Wins
                              ? t('you_won')
                              : t('bot_won'),
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
                if (_paused && !finished)
                  Container(
                    color: Colors.black54,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            t('paused'),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _togglePause,
                            icon: const Icon(Icons.play_arrow),
                            label: Text(t('resume')),
                          ),
                        ],
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

  Widget _buildCard(int i, Set<int> active, double w, double h) {
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
        width: w,
        height: h,
      ),
    );
  }
}
