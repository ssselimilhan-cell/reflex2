import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../game/game_engine.dart';
import '../online/firestore_game_repository.dart';
import '../widgets/card_widget.dart';
import '../widgets/score_bar_widget.dart';
import '../widgets/game_result_overlay.dart';
import '../widgets/streak_celebration_overlay.dart';
import '../widgets/chat_panel.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/player_header.dart';
import '../settings/app_settings.dart';
import '../settings/sound_manager.dart';
import '../settings/progress.dart';
import '../settings/share_helper.dart';
import '../widgets/table_felt.dart';
import '../settings/moderation.dart';
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
  int _lastSeenStreakEventId = -1;
  int _lastTotalColumnCards = -1;
  bool _nomatchSoundPlayed = false;
  String? _opponentDeviceId;
  String? _opponentName;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _friendSub;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _incomingFriendDocs = [];
  bool _leavingBlocked = false;
  bool _autoAccepted = false;
  int? _celebrationBonus;

  PlayerSide get mySide =>
      widget.isHost ? PlayerSide.player1 : PlayerSide.player2;

  /// Yeni durumda kolonlardaki toplam kart sayısı arttıysa bir hamle
  /// yapılmış demektir — ses çal. "Benzer kalmadı" durumuna ilk girildiğinde
  /// uyarı sesi çalar.
  void _maybePlayMoveSound(Map<String, dynamic> data) {
    final cols = (data['columns'] as List).cast<String>();
    final total = cols.fold<int>(
        0, (sum, c) => sum + (c.isEmpty ? 0 : c.split(',').length));
    if (_lastTotalColumnCards != -1 && total > _lastTotalColumnCards) {
      SoundManager.instance.play(Sfx.play);
    }
    _lastTotalColumnCards = total;

    if (_localView.isDeadlocked && !_revealing) {
      if (!_nomatchSoundPlayed) {
        _nomatchSoundPlayed = true;
        SoundManager.instance.play(Sfx.nomatch);
      }
    } else if (!_localView.isDeadlocked) {
      _nomatchSoundPlayed = false;
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _addFriendOpponent() async {
    final id = _opponentDeviceId;
    if (id == null) return;
    final p = UserProfile.instance;
    if (!p.hasProfile) {
      _snack(t('friend_need_profile'));
      return;
    }
    if (_opponentName == null) {
      _snack(t('friend_guest'));
      return;
    }
    final r = await _repo.sendFriendRequest(
      fromDeviceId: p.deviceId ?? widget.deviceId,
      toDeviceId: id,
      fromDisplayName: p.displayName,
      fromAvatarIconIndex: p.avatarIconIndex,
      fromAvatarColorValue: p.avatarColor.value,
      fromPhotoBase64: p.photoBase64,
    );
    if (!mounted) return;
    _snack(t(switch (r) {
      'sent' => 'friend_request_sent',
      'already' => 'friend_already',
      'accepted' => 'friend_added',
      _ => 'friend_error',
    }));
  }

  QueryDocumentSnapshot<Map<String, dynamic>>? _friendRequestFromOpponent() {
    final opp = _opponentDeviceId;
    if (opp == null) return null;
    for (final d in _incomingFriendDocs) {
      if (d.data()['fromDeviceId'] == opp) return d;
    }
    return null;
  }

  Widget _buildFriendRequestBanner(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final sender = doc.data()['fromDisplayName'] as String? ?? t('opponent');
    final me = UserProfile.instance.deviceId ?? widget.deviceId;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.pinkAccent.withOpacity(0.18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.pinkAccent.withOpacity(0.6)),
      ),
      child: Row(
        children: [
          const Icon(Icons.favorite, color: Colors.pinkAccent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text('$sender ${t('friend_request_text')}',
                style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
          TextButton(
            onPressed: () => _repo.declineFriendRequest(doc.id),
            child: Text(t('decline'),
                style: const TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => _repo.acceptFriendRequest(
              requestId: doc.id,
              fromDeviceId: doc.data()['fromDeviceId'] as String,
              toDeviceId: me,
            ),
            child: Text(t('accept')),
          ),
        ],
      ),
    );
  }

  /// Rakibi engeller (onay sonrası) ve odadan çıkar.
  Future<void> _confirmBlockOpponent() async {
    final id = _opponentDeviceId;
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t('block_user')),
        content: Text(t('block_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(t('decline')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(t('block_user')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await Moderation.instance.block(id, _opponentName);
    _repo.removeFriend(UserProfile.instance.deviceId ?? widget.deviceId, id);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(t('user_blocked'))));
    Navigator.of(context).pop();
  }

  /// Rakibi bildirmek için neden seçtiren küçük bir pencere açar.
  void _showReportDialog() {
    final reasons = <String>[
      t('report_reason_chat'),
      t('report_reason_profile'),
      t('report_reason_abuse'),
      t('report_reason_other'),
    ];
    showDialog<void>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(t('report_user')),
        children: reasons
            .map((r) => SimpleDialogOption(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    _repo.reportUser(
                      roomCode: widget.roomCode,
                      reporterDeviceId:
                          UserProfile.instance.deviceId ?? widget.deviceId,
                      reportedDeviceId: _opponentDeviceId,
                      reason: r,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(t('report_sent'))));
                  },
                  child: Text(r),
                ))
            .toList(),
      ),
    );
  }

  /// Sunucu (Firestore transaction) tarafında uygulanan art arda hamle
  /// avantajını, senkronize edilen streakEventId değişimini izleyerek
  /// tespit eder — çünkü asıl mantık bu istemcinin _localView'ında değil,
  /// repository'nin transaction içinde kurduğu geçici bir motorda çalışıyor.
  void _maybeShowStreakCelebration(Map<String, dynamic> data) {
    final eventId = (data['streakEventId'] as num?)?.toInt() ?? 0;
    final wasInitialLoad = _lastSeenStreakEventId == -1;
    if (eventId == _lastSeenStreakEventId) return;
    _lastSeenStreakEventId = eventId;
    if (wasInitialLoad || eventId <= 0) return;
    final amount = (data['lastStreakBonusAmount'] as num?)?.toInt();
    if (amount == null) return;
    if (data['lastStreakBonusSide'] == mySide.name) {
      Progress.instance.recordStreakBonus();
    }
    SoundManager.instance.play(Sfx.streak);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _celebrationBonus = amount);
    });
  }

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
          SoundManager.instance.play(Sfx.deal);
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
  void initState() {
    super.initState();
    // Rakipten gelen arkadaşlık isteği oyun içinde de görünsün.
    _friendSub = _repo.watchIncomingFriendRequests(widget.deviceId).listen(
      (snap) {
        if (mounted) setState(() => _incomingFriendDocs = snap.docs);
      },
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    _friendSub?.cancel();
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
              PopupMenuButton<String>(
                icon: const Icon(Icons.flag_outlined),
                tooltip: t('report_user'),
                onSelected: (v) {
                  if (v == 'report') _showReportDialog();
                  if (v == 'friend') _addFriendOpponent();
                  if (v == 'block') _confirmBlockOpponent();
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'report', child: Text(t('report_user'))),
                  PopupMenuItem(value: 'friend', child: Text(t('friend_add'))),
                  PopupMenuItem(value: 'block', child: Text(t('block_user'))),
                ],
              ),
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
            ],
          ),
          body: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusScope.of(context).unfocus(),
            child: SafeArea(
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
              _opponentDeviceId = (mySide == PlayerSide.player1
                  ? data['guestDeviceId']
                  : data['hostDeviceId']) as String?;
              _opponentName = (mySide == PlayerSide.player1
                  ? data['guestDisplayName']
                  : data['hostDisplayName']) as String?;
              // Daha önce engellediğim biri odaya girdiyse otomatik çık.
              if (Moderation.instance.isBlocked(_opponentDeviceId) &&
                  !_leavingBlocked) {
                _leavingBlocked = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) Navigator.of(context).maybePop();
                });
              }

                // Hızlı Eşleş odalarında başlatma isteğini ev sahibi otomatik kabul eder.
                if (data['quickMatch'] == true &&
                    roomStatus == 'start_requested' &&
                    data['startRequestedBy'] != mySide.name &&
                    !_autoAccepted) {
                  _autoAccepted = true;
                  WidgetsBinding.instance.addPostFrameCallback(
                      (_) => _repo.acceptStart(widget.roomCode));
                }

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
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () => shareRoomCode(widget.roomCode),
                        icon: const Icon(Icons.share),
                        label: Text(t('share_code_button')),
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
              _maybeShowStreakCelebration(data);
              _maybePlayMoveSound(data);
              final finished = _localView.status != GameStatus.playing;
              if (finished && !_scoreCounted) {
                _scoreCounted = true;
                final iWon = (_localView.status == GameStatus.player1Wins) ==
                    (mySide == PlayerSide.player1);
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  ScoreBoard.instance.addOnline(iWon);
                  SoundManager.instance.play(iWon ? Sfx.win : Sfx.lose);
                  Progress.instance.recordGame(won: iWon, mode: 'online');
                  UserProfile.instance.recordOnlineResult(iWon);
                  final profile = UserProfile.instance;
                  final saveError = await _repo.recordGameResult(
                    deviceId: profile.deviceId ?? widget.deviceId,
                    won: iWon,
                    displayName:
                        profile.hasProfile ? profile.displayName : null,
                    avatarIconIndex:
                        profile.hasProfile ? profile.avatarIconIndex : null,
                    avatarColorValue: profile.hasProfile
                        ? profile.avatarColor.value
                        : null,
                    photoBase64:
                        profile.hasProfile ? profile.photoBase64 : null,
                  );
                  // Kayıt başarısız olursa (ör. Firestore kuralı yüzünden)
                  // sessiz kalma, nedenini göster.
                  if (saveError != null && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        duration: const Duration(seconds: 8),
                        content: Text('Sonuç liderlik tablosuna kaydedilemedi: $saveError')));
                  }
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
              final oppDisplayName = (mySide == PlayerSide.player1
                  ? data['guestDisplayName']
                  : data['hostDisplayName']) as String?;
              final myName = UserProfile.instance.hasProfile
                  ? UserProfile.instance.displayName!
                  : t('you');

              final iWonFinal = (_localView.status == GameStatus.player1Wins) ==
                  (mySide == PlayerSide.player1);

              // NOT: Dış SafeArea (body: SafeArea(...)) zaten tüm alt
              // ekranları kapsıyor, bu yüzden burada ikinci bir SafeArea'ya
              // gerek yok.
              return Stack(
                children: [
                  const Positioned.fill(child: TableFelt()),
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
                        StockCountsBar(
                          leftLabel: t('you'),
                          leftCount: myStockCount,
                          rightLabel: t('opponent'),
                          rightCount: oppStockCount,
                        ),
                        if (_friendRequestFromOpponent() != null)
                          _buildFriendRequestBanner(_friendRequestFromOpponent()!),
                        // Rakip ve kendi 4'lü sıraları ortada; aralarında
                        // "yarım kart" kadar boşluk bırakılıyor (cardH/2).
                        Expanded(
                          child: Center(
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  PlayerHeader(
                                    avatar: ProfileAvatar.remote(
                                      radius: 18,
                                      photoBase64: oppPhotoBase64,
                                      iconIndex: oppAvatarIconIndex,
                                      color: oppAvatarColorValue != null
                                          ? Color(oppAvatarColorValue)
                                          : Colors.white24,
                                    ),
                                    name: oppDisplayName ?? t('opponent'),
                                    stockCount: oppStockCount,
                                  ),
                                  const SizedBox(height: 8),
                                  Padding(
                                    padding:
                                        const EdgeInsets.symmetric(horizontal: 4),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: oppCols
                                            .map((i) => _buildCard(
                                                i, active, cardW, cardH,
                                                enabled: !finished,
                                                fromAbove: true))
                                            .toList(),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: cardH / 2),
                                  Padding(
                                    padding:
                                        const EdgeInsets.symmetric(horizontal: 4),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: myCols
                                            .map((i) => _buildCard(
                                                i, active, cardW, cardH,
                                                enabled: !finished,
                                                fromAbove: false))
                                            .toList(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  PlayerHeader(
                                    avatar: const ProfileAvatar(radius: 18),
                                    name: myName,
                                    stockCount: myStockCount,
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
                    if (_celebrationBonus != null)
                      StreakCelebrationOverlay(
                        bonus: _celebrationBonus!,
                        onDone: () => setState(() => _celebrationBonus = null),
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
          ),
        );
      },
    );
  }

  Widget _buildCard(int i, Set<int> active, double w, double h,
      {bool enabled = true, bool fromAbove = true}) {
    final top = _localView.topOf(i);
    final isRevealed = revealed[i];
    final isActive = active.contains(i);
    final showHighlight = isActive && AppSettings.instance.assistedMode;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: CardWidget(
        card: top,
        faceDown: !isRevealed || top == null,
        highlighted: showHighlight && isRevealed,
        onTap: (isActive && isRevealed && enabled) ? () => _tap(i) : null,
        width: w,
        height: h,
        fromAbove: fromAbove,
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
