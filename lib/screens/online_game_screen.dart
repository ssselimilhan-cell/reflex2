import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../game/game_engine.dart';
import '../online/firestore_game_repository.dart';
import '../widgets/card_widget.dart';

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
  final List<Timer> _pendingTimers = [];
  int _lastKnownVersionKey = -1;

  PlayerSide get mySide =>
      widget.isHost ? PlayerSide.player1 : PlayerSide.player2;

  void _tap(int columnIndex) {
    if (_revealing) return;
    _repo.attemptPlay(
      code: widget.roomCode,
      side: mySide,
      columnIndex: columnIndex,
    );
  }

  /// Firestore'dan yeni bir durum geldiğinde, eğer bu bir "yeniden dağıtım"
  /// (redeal) ile geldiyse görsel açılış animasyonunu tekrar oynat.
  /// Basit tespit: tüm kolonların uzunluğu 1'e düştüyse (yeni dağıtım
  /// sonrası her kolonda tek kart olur) ve önceki durumdan farklıysa.
  void _maybeStartReveal(Map<String, dynamic> data) {
    final columns = data['columns'] as List;
    final allSingleCard = columns.every((c) => (c as List).length == 1);
    final versionKey = Object.hashAll(
        columns.map((c) => (c as List).join(',')).toList());

    if (allSingleCard && versionKey != _lastKnownVersionKey) {
      _lastKnownVersionKey = versionKey;
      _startReveal();
    } else {
      _lastKnownVersionKey = versionKey;
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
    for (final t in _pendingTimers) {
      t.cancel();
    }
    _repo.leaveRoom(widget.roomCode);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B6E4F),
      appBar: AppBar(title: Text('Oda: ${widget.roomCode}')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _repo.watchRoom(widget.roomCode),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text('Oda bulunamadı ya da kapatıldı.',
                  style: TextStyle(color: Colors.white)),
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
                    'Rakip bekleniyor…\nOda kodunu paylaş: ${widget.roomCode}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
            );
          }

          _localView.loadFromMap(data);
          _maybeStartReveal(data);
          final finished = _localView.status != GameStatus.playing;
          final active = _revealing ? <int>{} : _localView.activeColumns;

          final myStockCount = mySide == PlayerSide.player1
              ? _localView.player1Stock.length
              : _localView.player2Stock.length;
          final oppStockCount = mySide == PlayerSide.player1
              ? _localView.player2Stock.length
              : _localView.player1Stock.length;

          return SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('Rakip kaynağı: $oppStockCount',
                      style: const TextStyle(color: Colors.white70)),
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(GameEngine.columnCount, (i) {
                    final top = _localView.topOf(i);
                    final isRevealed = revealed[i];
                    final isActive = active.contains(i);
                    return Padding(
                      padding:
                          EdgeInsets.only(left: i == 4 ? 20 : 4, right: 4),
                      child: CardWidget(
                        card: top,
                        faceDown: !isRevealed || top == null,
                        highlighted: isActive && isRevealed,
                        onTap: (isActive && isRevealed && !finished)
                            ? () => _tap(i)
                            : null,
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
                      (_localView.status == GameStatus.player1Wins) ==
                              (mySide == PlayerSide.player1)
                          ? 'Kazandın!'
                          : 'Kaybettin!',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                Text('Kaynağın: $myStockCount',
                    style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}
