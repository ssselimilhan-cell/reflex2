import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../game/game_engine.dart';
import '../online/firestore_game_repository.dart';
import '../widgets/card_widget.dart';
import '../widgets/deck_stack_widget.dart';
import '../widgets/score_bar_widget.dart';
import '../widgets/game_result_overlay.dart';
import '../widgets/chat_panel.dart';
import '../widgets/profile_avatar.dart';
import '../settings/app_settings.dart';
import '../settings/score_board.dart';
import '../settings/user_profile.dart';
import '../settings/strings.dart';
import 'settings_screen.dart';

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
  bool _resultDismissed = false;
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
    // NOT: 'columns' alanı her kolon için virgülle ayrılmış TEK bir metin
    // dizisidir (List<String>) — iç içe dizi (List<List>) DEĞİLDİR.
    final columns = (data['columns'] as List).cast<String>();
    final allSingleCard =
        columns.every((c) => c.isNotEmpty && !c.contains(','));
    final versionKey = Object.hashAll(columns);

    if (allSingleCard && versionKey != _lastKnownVersionKey) {
      _lastKnownVersionKey = versionKey;
      // ÖNEMLİ: Bu fonksiyon StreamBuilder'ın build() aşamasında
      // çağrılıyor; setState()'i (_startReveal() içinde) build sırasında
      // DOĞRUDAN çağırmak "setState called during build" hatası verir.
      // Bu yüzden bir sonraki kareye erteliyoruz.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _startReveal();
      });
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
        if (!mounted) return;
        _repo.attemptCollectAndRedeal(widget.roomCode);
        _collectScheduled = false;
      });
      _pendingTimers.add(timer);
    }
  }

  void _startReveal() {
    if (!mounted) return;
    for (final t in _pendingTimers) {
      t.cancel();
    }
    _pendingTimers.clear();
    _collectScheduled = false;
    setState(() {
      revealed = List.filled(GameEngine.columnCount, false);
      _revealing = true;
      _localView.locked = true;
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
            _localView.locked = false;
          }
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
    _repo.clearMessages(widget.roomCode);
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
          appBar: AppBar(
            title: Text('${t('room')}: ${widget.roomCode}'),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                tooltip: t('menu_settings'),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen())),
              ),
            ],
          ),
          body: SafeArea(
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
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

              if (roomStatus == 'ready') {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle,
                            color: Colors.greenAccent, size: 48),
                        const SizedBox(height: 12),
                        Text(t('opponent_connected'),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text(t('press_start_hint'),
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 14)),
                        const SizedBox(height: 28),
                        ElevatedButton.icon(
                          onPressed: () =>
                              _repo.requestStart(widget.roomCode, mySide),
                          icon: const Icon(Icons.play_arrow),
                          label: Text(t('start_game'),
                              style: const TextStyle(fontSize: 16)),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 28, vertical: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (roomStatus == 'start_requested') {
                final requestedByMe =
                    data['startRequestedBy'] == mySide.name;
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: requestedByMe
                          ? [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 16),
                              Text(t('waiting_for_accept'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 18)),
                              const SizedBox(height: 20),
                              TextButton(
                                onPressed: () =>
                                    _repo.cancelStart(widget.roomCode),
                                child: Text(t('cancel_request'),
                                    style: const TextStyle(
                                        color: Colors.white54)),
                              ),
                            ]
                          : [
                              const Icon(Icons.sports_esports,
                                  color: Colors.amber, size: 48),
                              const SizedBox(height: 12),
                              Text(t('opponent_wants_start'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  OutlinedButton(
                                    onPressed: () =>
                                        _repo.cancelStart(widget.roomCode),
                                    style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white70),
                                    child: Text(t('decline')),
                                  ),
                                  const SizedBox(width: 16),
                                  ElevatedButton(
                                    onPressed: () =>
                                        _repo.acceptStart(widget.roomCode),
                                    child: Text(t('accept')),
                                  ),
                                ],
                              ),
                            ],
                    ),
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
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ScoreBoard.instance.addOnline(iWon);
                  UserProfile.instance.recordOnlineResult(iWon);
                });
              } else if (!finished) {
                _scoreCounted = false;
                _resultDismissed = false;
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

              // Rakibin profil bilgisi — ben host'sam rakip guest'tir,
              // ben guest'sem rakip host'tur.
              final oppPhotoBase64 = (mySide == PlayerSide.player1
                  ? data['guestPhotoBase64']
                  : data['hostPhotoBase64']) as String?;
              final oppAvatarIconIndex = (mySide == PlayerSide.player1
                  ? data['guestAvatarIconIndex']
                  : data['hostAvatarIconIndex']) as int?;
              final oppAvatarColorValue = (mySide == PlayerSide.player1
                  ? data['guestAvatarColorValue']
                  : data['hostAvatarColorValue']) as int?;

              final iWonFinal = (_localView.status == GameStatus.player1Wins) ==
                  (mySide == PlayerSide.player1);

              // NOT: Dış SafeArea (body: SafeArea(...)) zaten tüm alt
              // ekranları kapsıyor, bu yüzden burada ikinci bir SafeArea'ya
              // gerek yok.
              return Stack(
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
                        // Rakip ve kendi 4'lü sıraları ortada, birbirine
                        // YAKIN duracak şekilde tek bir kompakt blok
                        // halinde ortalanıyor (önceki tasarımdaki iki
                        // Spacer kaldırıldı).
                        Expanded(
                          child: Center(
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      ProfileAvatar.remote(
                                        radius: 14,
                                        photoBase64: oppPhotoBase64,
                                        iconIndex: oppAvatarIconIndex,
                                        color: oppAvatarColorValue != null
                                            ? Color(oppAvatarColorValue)
                                            : Colors.white24,
                                      ),
                                      const SizedBox(width: 6),
                                      DeckStackWidget(
                                          count: oppStockCount,
                                          label: t('opponent'),
                                          scale: scale),
                                      const SizedBox(width: 14),
                                      Flexible(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: oppCols
                                                .map((i) => _buildCard(
                                                    i, active, cardW, cardH,
                                                    enabled: !finished))
                                                .toList(),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      DeckStackWidget(
                                          count: myStockCount,
                                          label: t('you'),
                                          scale: scale),
                                      const SizedBox(width: 14),
                                      Flexible(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: myCols
                                                .map((i) => _buildCard(
                                                    i, active, cardW, cardH,
                                                    enabled: !finished))
                                                .toList(),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (finished) _buildRematchArea(data),
                        ChatPanel(
                          roomCode: widget.roomCode,
                          mySide: mySide,
                          repo: _repo,
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                    if (isDeadlocked && !_revealing && !finished)
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
                    if (finished && !_resultDismissed)
                      GameResultOverlay(
                        isWin: iWonFinal,
                        title: iWonFinal ? t('win') : t('lose'),
                        onPlayAgain: () {
                          _repo.requestRematch(widget.roomCode, mySide);
                          setState(() => _resultDismissed = true);
                        },
                        onDismiss: () =>
                            setState(() => _resultDismissed = true),
                      ),
                  ],
              );
            },
          ),
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

  /// Kartların altında, ortalı duran "Tekrar Oyna" alanı. Oyun bitince
  /// hep görünür (kutu kapatılsa bile kaybolmaz); tıklanınca DİREKT
  /// başlamaz — karşı tarafın kabul etmesi gerekir.
  Widget _buildRematchArea(Map<String, dynamic> data) {
    final requestedBy = data['rematchRequestedBy'] as String?;

    if (requestedBy == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: ElevatedButton.icon(
            onPressed: () => _repo.requestRematch(widget.roomCode, mySide),
            icon: const Icon(Icons.replay),
            label: Text(t('play_again')),
          ),
        ),
      );
    }

    final requestedByMe = requestedBy == mySide.name;

    if (requestedByMe) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(height: 6),
              Text(t('waiting_for_accept'),
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
              TextButton(
                onPressed: () => _repo.declineRematch(widget.roomCode),
                child: Text(t('cancel_request'),
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t('rematch_requested'),
                style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton(
                  onPressed: () => _repo.declineRematch(widget.roomCode),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white70),
                  child: Text(t('decline')),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () => _repo.acceptRematch(widget.roomCode),
                  child: Text(t('accept')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
