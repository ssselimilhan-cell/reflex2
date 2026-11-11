import 'dart:async';
import 'package:flutter/material.dart';
import '../game/game_engine.dart';
import '../game/bot_ai.dart';
import '../game/bot_profile.dart';
import '../widgets/card_widget.dart';
import '../widgets/score_bar_widget.dart';
import '../widgets/game_result_overlay.dart';
import '../widgets/player_header.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/streak_celebration_overlay.dart';
import '../settings/app_settings.dart';
import '../settings/sound_manager.dart';
import '../settings/progress.dart';
import '../settings/ladder.dart';
import '../widgets/level_result_overlay.dart';
import '../widgets/table_felt.dart';
import '../widgets/game_ui.dart';
import '../settings/telemetry.dart';
import '../settings/score_board.dart';
import '../settings/user_profile.dart';
import '../settings/strings.dart';
import 'settings_screen.dart';

class VsBotScreen extends StatefulWidget {
  /// true ise "Oyunu Başlat" düğmesine basılmadan oyun hemen başlar
  /// (Hızlı Eşleş bota düştüğünde ve ilk açılış eğitiminde kullanılır).
  final bool autoStart;
  final double? initialDifficulty;

  /// Bot Yolu seviyesi (1-100). Verilirse zorluk çubuğu yerine o seviyenin
  /// botu kullanılır ve oyun hemen başlar.
  final int? level;
  final Future<Widget?> Function()? onGameFinished;
  final Future<void> Function()? onAbandon;

  const VsBotScreen({
    super.key,
    this.autoStart = false,
    this.initialDifficulty,
    this.level,
    this.onGameFinished,
    this.onAbandon,
  });

  @override
  State<VsBotScreen> createState() => _VsBotScreenState();
}

class _VsBotScreenState extends State<VsBotScreen> {
  GameEngine engine = GameEngine();
  BotAi? bot;
  double difficulty = 0.5;
  List<bool> revealed = List.filled(GameEngine.columnCount, true);
  bool _revealing = false;
  bool _showNoMatch = false;
  bool _paused = false;
  bool _scoreCounted = false;
  bool _gameStarted = false;
  bool _resultDismissed = false;
  bool _ladderRecorded = false;
  bool _matchCallbackInvoked = false;
  int _ladderStars = 0;
  final List<Timer> _pendingTimers = [];
  /// Sadece OYUNCUNUN kazandığı avantaj kutlanıyor (botunki
  /// bildirilmiyor, rahatsız edici olmasın diye).
  int? _celebrationBonus;

  @override
  void initState() {
    super.initState();
    if (widget.initialDifficulty != null) {
      difficulty = widget.initialDifficulty!;
    }
    if (widget.autoStart || widget.level != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _beginGame();
      });
    }
    // NOT: Artık ekran açılır açılmaz otomatik başlamıyor — "Oyunu
    // Başlat" düğmesine basılana kadar bekliyor. Zorluk da o ekranda
    // (oyun başlamadan ÖNCE) ayarlanabiliyor.
  }

  int get _stepMs => (500 * AppSettings.instance.animationSpeed).round();

  void _beginGame() {
    Telemetry.log('game_start',
        {'mode': 'bot', if (widget.level != null) 'level': widget.level});
    setState(() => _gameStarted = true);
    _startNewGame();
  }

  void _startNewGame() {
    engine = GameEngine()..startNewGame();
    engine.onStreakBonus = (side, bonus) {
      if (side == PlayerSide.player1 && mounted) {
        SoundManager.instance.play(Sfx.streak);
        Progress.instance.recordStreakBonus();
        setState(() => _celebrationBonus = bonus);
      }
    };
    _scoreCounted = false;
    _paused = false;
    _resultDismissed = false;
    _ladderRecorded = false;
    _ladderStars = 0;
    _celebrationBonus = null;
    bot?.stop();
    bot = BotAi(
      engine,
      PlayerSide.player2,
      _onBotMove,
      difficulty: difficulty,
      profile:
          widget.level != null ? BotProfile.forLevel(widget.level!) : null,
    )..start();
    _startReveal();
  }

  void _onBotMove() {
    if (!mounted) return;
    setState(() {});
    SoundManager.instance.play(Sfx.play);
    _checkFinishForScore();
    if (engine.isDeadlocked && !_showNoMatch && !_revealing) {
      _handleDeadlock();
    }
  }

  void _checkFinishForScore() {
    if (engine.status != GameStatus.playing && !_scoreCounted) {
      _scoreCounted = true;
      ScoreBoard.instance.addBot(engine.status == GameStatus.player1Wins);
      SoundManager.instance.play(
          engine.status == GameStatus.player1Wins ? Sfx.win : Sfx.lose);
      Progress.instance
          .recordGame(won: engine.status == GameStatus.player1Wins, mode: 'bot');
      if (!_matchCallbackInvoked && widget.onGameFinished != null) {
        _matchCallbackInvoked = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          widget.onGameFinished!().then((nextScreen) {
            if (!mounted || nextScreen == null) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => nextScreen),
            );
          });
        });
      }
      if (widget.level != null) {
        final won = engine.status == GameStatus.player1Wins;
        if (won && !_ladderRecorded) {
          _ladderRecorded = true;
          _ladderStars = LadderProgress.instance.recordWin(widget.level!);
          Telemetry.log('level_clear', {'level': widget.level});
        } else if (!won) {
          Telemetry.log('level_fail', {'level': widget.level});
        }
      }
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
          SoundManager.instance.play(Sfx.deal);
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

  void _handleDeadlock() {
    SoundManager.instance.play(Sfx.nomatch);
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
    if (widget.onAbandon != null && !_matchCallbackInvoked) {
      widget.onAbandon!.call();
    }
    bot?.stop();
    for (final t in _pendingTimers) {
      t.cancel();
    }
    super.dispose();
  }

  void _tap(int columnIndex) {
    if (_revealing || _showNoMatch || _paused) return;
    var played = false;
    setState(() {
      played = engine.attemptPlay(PlayerSide.player1, columnIndex);
    });
    if (played) SoundManager.instance.play(Sfx.play);
    _checkFinishForScore();
    if (engine.isDeadlocked) {
      _handleDeadlock();
    }
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
    if (_paused) {
      bot?.stop();
    } else if (engine.status == GameStatus.playing) {
      bot?.start();
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
          backgroundColor: GameUi.background,
          appBar: AppBar(
            backgroundColor: GameUi.surface,
            foregroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            title: Text(widget.level != null
                ? '${t('level')} ${widget.level}'
                : t('menu_bot')),
            actions: [
              IconButton(
                icon: Icon(AppSettings.instance.soundEnabled
                    ? Icons.volume_up
                    : Icons.volume_off),
                tooltip: t('settings_sound'),
                onPressed: () => AppSettings.instance
                    .setSoundEnabled(!AppSettings.instance.soundEnabled),

              ),
              IconButton(
                icon: const Icon(Icons.settings),
                tooltip: t('menu_settings'),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen())),
              ),
              if (_gameStarted) ...[
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _startNewGame,
                ),
              ],
            ],
          ),
          body: SafeArea(
            child: Stack(
              children: [
                const Positioned.fill(child: TableFelt()),
                if (!_gameStarted)
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 26),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xE6253B58), Color(0xE6101B2C)],
                            ),
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(color: GameUi.gold.withOpacity(0.24)),
                            boxShadow: const [
                              BoxShadow(color: Color(0x50000000), blurRadius: 28, offset: Offset(0, 12)),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 76,
                                height: 76,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF2563EB), Color(0xFF0891B2)],
                                  ),
                                  boxShadow: [
                                    BoxShadow(color: GameUi.gold.withOpacity(0.25), blurRadius: 22),
                                  ],
                                ),
                                child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 38),
                              ),
                              const SizedBox(height: 18),
                              Text(t('menu_bot'),
                                  style: GameUi.display(25, color: Colors.white)),
                              const SizedBox(height: 7),
                              Text(t('difficulty'),
                                  style: const TextStyle(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        activeTrackColor: difficultyColor,
                                        inactiveTrackColor: Colors.white12,
                                        thumbColor: GameUi.gold,
                                        overlayColor: GameUi.gold.withOpacity(0.16),
                                        trackHeight: 5,
                                      ),
                                      child: Slider(
                                        value: difficulty,
                                        onChanged: (v) => setState(() => difficulty = v),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 48,
                                    alignment: Alignment.center,
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    decoration: BoxDecoration(
                                      color: difficultyColor.withOpacity(0.14),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: difficultyColor.withOpacity(0.35)),
                                    ),
                                    child: Text('${(difficulty * 100).round()}%',
                                      style: TextStyle(color: difficultyColor, fontWeight: FontWeight.w900)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              GamePrimaryButton(
                                label: t('start_game'),
                                icon: Icons.play_arrow_rounded,
                                height: 58,
                                onTap: _beginGame,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                else
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
                      StockCountsBar(
                        leftLabel: t('you'),
                        leftCount: engine.player1Stock.length,
                        rightLabel: t('bot'),
                        rightCount: engine.player2Stock.length,
                      ),
                      // Zorluk çubuğu artık başlangıç ekranında —
                      // buradaki eski yerine duraklat çubuğu geldi.
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        child: Center(
                          child: OutlinedButton.icon(
                            onPressed: finished ? null : _togglePause,
                            icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
                            label: Text(_paused ? t('resume') : t('pause')),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: GameUi.gold,
                              backgroundColor: GameUi.surface.withOpacity(0.72),
                              side: BorderSide(color: GameUi.gold.withOpacity(0.42)),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      PlayerHeader(
                        avatar: const CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white24,
                          child: Icon(Icons.smart_toy,
                              color: Colors.white, size: 20),
                        ),
                        name: t('bot'),
                        stockCount: engine.player2Stock.length,
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [4, 5, 6, 7]
                                .map((i) => _buildCard(
                                    i, active, cardW, cardH, true))
                                .toList(),
                          ),
                        ),
                      ),
                      SizedBox(height: cardH / 2),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [0, 1, 2, 3]
                                .map((i) => _buildCard(
                                    i, active, cardW, cardH, false))
                                .toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      PlayerHeader(
                        avatar: const ProfileAvatar(radius: 18),
                        name: UserProfile.instance.hasProfile
                            ? UserProfile.instance.displayName!
                            : t('you'),
                        stockCount: engine.player1Stock.length,
                      ),
                      const Spacer(),
                      if (finished && _resultDismissed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: TextButton.icon(
                            onPressed: _startNewGame,
                            icon: const Icon(Icons.replay, color: Colors.white70),
                            label: Text(t('play_again'),
                                style: const TextStyle(color: Colors.white70)),
                          ),
                        )
                      else if (!finished)
                        const SizedBox(height: 24),
                    ],
                  ),
                if (_showNoMatch && !finished)
                  Positioned(
                    top: 8,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xEE263A50),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: GameUi.gold.withOpacity(0.55)),
                          boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 12)],
                        ),
                        child: Text(
                          t('no_match'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: GameUi.gold, fontSize: 14, fontWeight: FontWeight.w800),
                        ),
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
                if (_celebrationBonus != null)
                  Positioned(
                    top: 8,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: StreakCelebrationOverlay(
                        bonus: _celebrationBonus!,
                        onDone: () => setState(() => _celebrationBonus = null),
                      ),
                    ),
                  ),
                if (finished && !_resultDismissed)
                  (widget.level != null
                      ? LevelResultOverlay(
                          isWin: engine.status == GameStatus.player1Wins,
                          level: widget.level!,
                          starsGained: _ladderStars,
                          isLastLevel:
                              widget.level! >= LadderProgress.maxLevel,
                          onRetry: _startNewGame,
                          onBack: () => Navigator.pop(context),
                          onNext: (engine.status == GameStatus.player1Wins &&
                                  widget.level! < LadderProgress.maxLevel)
                              ? () => Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => VsBotScreen(
                                          level: widget.level! + 1,
                                          autoStart: true),
                                    ),
                                  )
                              : null,
                          onDismiss: () =>
                              setState(() => _resultDismissed = true),
                        )
                      : GameResultOverlay(
                          isWin: engine.status == GameStatus.player1Wins,
                          title: engine.status == GameStatus.player1Wins
                              ? t('you_won')
                              : t('bot_won'),
                          onPlayAgain: _startNewGame,
                          onDismiss: () =>
                              setState(() => _resultDismissed = true),
                        )),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCard(
      int i, Set<int> active, double w, double h, bool fromAbove) {
    final top = engine.topOf(i);
    final isRevealed = revealed[i];
    final isActive = active.contains(i);
    final showHighlight = isActive && AppSettings.instance.assistedMode;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: CardWidget(
        card: top,
        faceDown: !isRevealed || top == null,
        highlighted: showHighlight && isRevealed,
        onTap: (isActive && isRevealed) ? () => _tap(i) : null,
        width: w,
        height: h,
        fromAbove: fromAbove,
      ),
    );
  }
}
