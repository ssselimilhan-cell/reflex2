import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../game/game_engine.dart';
import '../online/firestore_game_repository.dart';
import '../widgets/card_widget.dart';
import '../widgets/deck_stack_widget.dart';
import '../widgets/score_bar_widget.dart';
import '../settings/app_settings.dart';
import '../settings/score_board.dart';
import '../settings/strings.dart';

class OnlineGameScreen extends StatefulWidget {
  final String roomCode;
  final String deviceId;
  final bool isHost;

  const OnlineGameScreen({
    super.key,
    required this.roomCode,
    required this.deviceId,
    required this.isHost,
  });

  @override
  State<OnlineGameScreen> createState() => _OnlineGameScreenState();
}

class _OnlineGameScreenState extends State<OnlineGameScreen> {
  final _repo = OnlineRoomRepository();
  final GameEngine _localView = GameEngine();
  List<bool> revealed = List.filled(GameEngine.columnCount, true);
  bool _revealing = false;
  bool _scoreCounted = false;
  final List<Timer> _pendingTimers = [];
  int _lastKnownVersionKey = -1;
  bool _collectScheduled = false;

  PlayerSide get mySide =>
      widget.isHost ? PlayerSide.player1 : PlayerSide.player2;

  int get _stepMs => (500 * AppSettings.instance.animationSpeed).round();

  void _tap(int columnIndex) {
    if (_revealing) return;
    _repo.attemptPlay(
      code: widget.roomCode,
      side: mySide,
      columnIndex: columnIndex,
    );
  }

  void _maybeStartReveal(Map<String, dynamic> data) {
    // NOT: 'columns' alanı artık her kolon için virgülle ayrılmış TEK bir
    // metin dizisi (List<String>) — iç içe dizi (List<List>) değil.
    final columns = (data['columns'] as List).cast<String>();
    final allSingleCard =
        columns.every((c) => c.isNotEmpty && !c.contains(','));
    final versionKey = Object.hashAll(columns);

    if (allSingleCard && versionKey != _lastKnownVersionKey) {
      _lastKnownVersionKey = versionKey;
      _startReveal();
    } else {
      _lastKnownVersionKey = versionKey;
    }
  }

  void _maybeScheduleCollect(bool isDeadlocked) {
    if (!isDeadlocked) {
      _collectScheduled = false;
      return;
    }
    if (widget.isHost && !_collectScheduled && !_revealing) {
      _collectScheduled = true;
      final timer = Timer(const Duration(seconds: 1), () {
        _repo.attemptCollectAndRedeal(widget.roomCode);
        _collectScheduled = false;
      });
      _pendingTimers.add(timer);
    }
  }

  void _startReveal() {
    for (final t in _pendingTimers) {
      t.cancel();
    }
    _pendingTimers.clear();
    _collectScheduled = false;
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
      final timer = Timer(Duration(milliseconds: _stepMs * i), () {
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
    for (final t in _pendingTimers) {
      t.cancel();
    }
    _repo.leaveRoom(widget.roomCode);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppSettings.instance,
      builder: (context, _) {
        final scale = AppSettings.instance.cardScale;
        final cardW = 100.0 * scale;
        final cardH = 142.0 * scale;
        return Scaffold(
          backgroundColor: AppSettings.instance.themeColor,
          appBar: AppBar(title: Text('${t('room')}: ${widget.roomCode}')),
          body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _repo.watchRoom(widget.roomCode),
            builder: (context, snapshot) {
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return Center(
                  child: Text(t('not_found_closed'),
                      style: const TextStyle(color: Colors.white)),
                );
              }
              final data = snapshot.data!.data()!;
              final roomStatus = data['roomStatus'] as String;

              if (roomStatus == 'waiting') {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        '${t('waiting_opponent')}\n${t('share_code')}: ${widget.roomCode}',
                        textAlign: TextAlign.center,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    ],
                  ),
                );
              }

              _localView.loadFromMap(data);
              _maybeStartReveal(data);
              final finished = _localView.status != GameStatus.playing;
              if (finished && !_scoreCounted) {
                _scoreCounted = true;
                final iWon = (_localView.status == GameStatus.player1Wins) ==
                    (mySide == PlayerSide.player1);
                WidgetsBinding.instance.addPostFrameCallback(
                    (_) => ScoreBoard.instance.addOnline(iWon));
              }
              final isDeadlocked = _localView.isDeadlocked;
              if (!finished) _maybeScheduleCollect(isDeadlocked);
              final active = (_revealing || isDeadlocked)
                  ? <int>{}
                  : _localView.activeColumns;

              final myStockCount = mySide == PlayerSide.player1
                  ? _localView.player1Stock.length
                  : _localView.player2Stock.length;
              final oppStockCount = mySide == PlayerSide.player1
                  ? _localView.player2Stock.length
                  : _localView.player1Stock.length;

              final myCols = mySide == PlayerSide.player1
                  ? const [0, 1, 2, 3]
                  : const [4, 5, 6, 7];
              final oppCols = mySide == PlayerSide.player1
                  ? const [4, 5, 6, 7]
                  : const [0, 1, 2, 3];

              return SafeArea(
                child: Stack(
                  children: [
                    Column(
                      children: [
                        ListenableBuilder(
                          listenable: ScoreBoard.instance,
                          builder: (context, _) => ScoreBarWidget(
                            leftLabel: t('you'),
                            leftScore: ScoreBoard.instance.onlineYou,
                            rightLabel: t('opponent'),
                            rightScore: ScoreBoard.instance.onlineOpp,
                            onReset: ScoreBoard.instance.resetOnline,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            DeckStackWidget(
                                count: oppStockCount,
                                label: t('opponent'),
                                scale: scale),
                            const SizedBox(width: 16),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: oppCols
                                      .map((i) => _buildCard(i, active, cardW,
                                          cardH, enabled: !finished))
                                      .toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        if (finished)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(
                              (_localView.status ==
                                          GameStatus.player1Wins) ==
                                      (mySide == PlayerSide.player1)
                                  ? t('win')
                                  : t('lose'),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            DeckStackWidget(
                                count: myStockCount,
                                label: t('you'),
                                scale: scale),
                            const SizedBox(width: 16),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: myCols
                                      .map((i) => _buildCard(i, active, cardW,
                                          cardH, enabled: !finished))
                                      .toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                    if (isDeadlocked && !_revealing)
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
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCard(int i, Set<int> active, double w, double h,
      {bool enabled = true}) {
    final top = _localView.topOf(i);
    final isRevealed = revealed[i];
    final isActive = active.contains(i);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: CardWidget(
        card: top,
        faceDown: !isRevealed || top == null,
        highlighted: isActive && isRevealed,
        onTap: (isActive && isRevealed && enabled) ? () => _tap(i) : null,
        width: w,
        height: h,
      ),
    );
  }
}
