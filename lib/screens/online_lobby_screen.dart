import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../online/firestore_game_repository.dart';
import '../online/persistent_device_id.dart';
import '../settings/app_settings.dart';
import '../settings/user_profile.dart';
import '../settings/strings.dart';
import '../widgets/profile_avatar.dart';
import 'online_game_screen.dart';

enum _PlayerSort { alphabetical, gamesPlayed, winRate }

class OnlineLobbyScreen extends StatefulWidget {
  const OnlineLobbyScreen({super.key});

  @override
  State<OnlineLobbyScreen> createState() => _OnlineLobbyScreenState();
}

class _OnlineLobbyScreenState extends State<OnlineLobbyScreen> {
  final _repo = OnlineRoomRepository();
  final _codeController = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _manualJoinExpanded = false;
  _PlayerSort _playerSort = _PlayerSort.alphabetical;

  /// Profil ile aynı, cihazda KALICI kimlik — oturum bazlı değil,
  /// böylece profil senkronizasyonuyla tutarlı kalır.
  Future<String> _deviceId() async =>
      UserProfile.instance.deviceId ?? await getPersistentDeviceId();

  Future<void> _createRoom() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final deviceId = await _deviceId();
      final profile = UserProfile.instance;
      final code = await _repo.createRoom(
        deviceId,
        hostDisplayName: profile.hasProfile ? profile.displayName : null,
        hostWinRate: profile.hasProfile ? profile.onlineWinRate : null,
        hostAvatarIconIndex: profile.hasProfile ? profile.avatarIconIndex : null,
        hostAvatarColorValue: profile.hasProfile ? profile.avatarColor.value : null,
        hostPhotoBase64: profile.hasProfile ? profile.photoBase64 : null,
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OnlineGameScreen(
            roomCode: code,
            deviceId: deviceId,
            isHost: true,
          ),
        ),
      );
    } catch (e) {
      setState(() => _error = 'Oda oluşturulamadı: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _joinRoomByCode(String rawCode) async {
    final code = rawCode.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final deviceId = await _deviceId();
      final profile = UserProfile.instance;
      final ok = await _repo.joinRoom(
        code,
        deviceId,
        guestDisplayName: profile.hasProfile ? profile.displayName : null,
        guestWinRate: profile.hasProfile ? profile.onlineWinRate : null,
        guestAvatarIconIndex: profile.hasProfile ? profile.avatarIconIndex : null,
        guestAvatarColorValue: profile.hasProfile ? profile.avatarColor.value : null,
        guestPhotoBase64: profile.hasProfile ? profile.photoBase64 : null,
      );
      if (!ok) {
        setState(() => _error = t('room_not_found'));
        return;
      }
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OnlineGameScreen(
            roomCode: code,
            deviceId: deviceId,
            isHost: false,
          ),
        ),
      );
    } catch (e) {
      setState(() => _error = 'Katılınamadı: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppSettings.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppSettings.instance.themeColor,
          appBar: AppBar(title: Text(t('lobby_title'))),
          body: SafeArea(
            child: Column(
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Text(_error!,
                        style: const TextStyle(color: Colors.redAccent)),
                  ),
                // Kod ile katılma — arkadaşla özel oyun için, katlanır.
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text(t('manual_join_title'),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 14)),
                      iconColor: Colors.white70,
                      collapsedIconColor: Colors.white70,
                      onExpansionChanged: (v) =>
                          setState(() => _manualJoinExpanded = v),
                      initiallyExpanded: _manualJoinExpanded,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            children: [
                              TextField(
                                controller: _codeController,
                                textAlign: TextAlign.center,
                                textCapitalization:
                                    TextCapitalization.characters,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    letterSpacing: 6),
                                maxLength: 4,
                                decoration: InputDecoration(
                                  hintText: t('room_code_hint'),
                                  hintStyle:
                                      const TextStyle(color: Colors.white38),
                                  counterText: '',
                                  enabledBorder: const UnderlineInputBorder(
                                    borderSide:
                                        BorderSide(color: Colors.white54),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _loading
                                    ? null
                                    : () =>
                                        _joinRoomByCode(_codeController.text),
                                child: Text(t('join_room')),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(color: Colors.white24, height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: Row(
                    children: [
                      Text(t('open_tables'),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                      const Spacer(),
                      if (_loading)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _buildOpenTablesList(),
                      ),
                      _buildPlayersPanel(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOpenTablesList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _repo.watchOpenTables(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs.toList();
        // Kazanma oranına göre azalan sırala (misafirler/oranı olmayanlar
        // en sona düşer). Sıralama istemci tarafında yapılıyor.
        docs.sort((a, b) {
          final rateA = (a.data()['hostWinRate'] as num?)?.toDouble();
          final rateB = (b.data()['hostWinRate'] as num?)?.toDouble();
          if (rateA == null && rateB == null) return 0;
          if (rateA == null) return 1;
          if (rateB == null) return -1;
          return rateB.compareTo(rateA);
        });

        // İlk satır HER ZAMAN "Boş Masa" — gerçek bir Firestore kaydı
        // değil, dokununca anında yeni bir oda oluşturup oraya oturtan
        // sabit bir davet. Böylece "birine oturulunca ikinci bir boş
        // masa açılsın" isteği doğal olarak karşılanıyor: bu satır asla
        // tükenmiyor, her dokunuşta kendi (yeni) masasını oluşturuyor.
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
          itemCount: docs.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) return _buildEmptyTableCard();

            final data = docs[index - 1].data();
            final code = docs[index - 1].id;
            final hostName =
                data['hostDisplayName'] as String? ?? t('guest_label');
            final winRate = (data['hostWinRate'] as num?)?.toDouble();
            final avatarIconIndex = data['hostAvatarIconIndex'] as int?;
            final avatarColorValue = data['hostAvatarColorValue'] as int?;
            final photoBase64 = data['hostPhotoBase64'] as String?;

            return Card(
              color: Colors.black26,
              margin: const EdgeInsets.only(bottom: 10),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: ProfileAvatar.remote(
                  radius: 20,
                  photoBase64: photoBase64,
                  iconIndex: avatarIconIndex,
                  color: avatarColorValue != null
                      ? Color(avatarColorValue)
                      : Colors.white24,
                ),
                title: Text(hostName,
                    style: const TextStyle(color: Colors.white)),
                subtitle: Text(
                  winRate == null
                      ? t('no_games_yet')
                      : '${t('online_win_rate')}: ${winRate.round()}%',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
                trailing: ElevatedButton(
                  onPressed: _loading ? null : () => _joinRoomByCode(code),
                  child: Text(t('join_short')),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Her zaman listenin ilk satırı — gerçek bir masa değil, dokununca
  /// yeni bir oda oluşturup kullanıcıyı oraya "oturtan" sabit bir davet.
  /// Tükenmez: her dokunuş kendi yeni odasını açar, bu yüzden "boş masa"
  /// hep mevcut olur.
  Widget _buildEmptyTableCard() {
    return Card(
      color: Colors.white10,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withOpacity(0.3), width: 1.4),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _loading ? null : _createRoom,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.white24,
                child: const Icon(Icons.event_seat, color: Colors.white70),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t('empty_table'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    Text(t('sit_and_wait'),
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 12)),
                  ],
                ),
              ),
              if (_loading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const Icon(Icons.chevron_right, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }

  /// Sağda duran, tüm profilli oyuncuları listeleyen ve alfabetik / oyun
  /// sayısı / online kazanma oranına göre sıralanabilen kompakt panel.
  Widget _buildPlayersPanel() {
    return Container(
      width: 132,
      margin: const EdgeInsets.only(right: 10, top: 4, bottom: 10),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(t('players_title'),
                style: const TextStyle(
                    color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _sortIconButton(Icons.sort_by_alpha, _PlayerSort.alphabetical,
                  t('sort_alpha')),
              _sortIconButton(
                  Icons.tag, _PlayerSort.gamesPlayed, t('sort_games')),
              _sortIconButton(
                  Icons.emoji_events, _PlayerSort.winRate, t('sort_winrate')),
            ],
          ),
          const Divider(color: Colors.white24, height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream:
                  FirebaseFirestore.instance.collection('profiles').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                final docs = snapshot.data!.docs.toList();
                docs.sort((a, b) {
                  final da = a.data();
                  final db = b.data();
                  switch (_playerSort) {
                    case _PlayerSort.alphabetical:
                      final na = (da['displayName'] as String? ?? '');
                      final nb = (db['displayName'] as String? ?? '');
                      return na.toLowerCase().compareTo(nb.toLowerCase());
                    case _PlayerSort.gamesPlayed:
                      final pa = ((da['onlineWins'] as num?) ?? 0).toInt() +
                          ((da['onlineLosses'] as num?) ?? 0).toInt();
                      final pb = ((db['onlineWins'] as num?) ?? 0).toInt() +
                          ((db['onlineLosses'] as num?) ?? 0).toInt();
                      return pb.compareTo(pa);
                    case _PlayerSort.winRate:
                      final wa = ((da['onlineWins'] as num?) ?? 0).toInt();
                      final la = ((da['onlineLosses'] as num?) ?? 0).toInt();
                      final wb = ((db['onlineWins'] as num?) ?? 0).toInt();
                      final lb = ((db['onlineLosses'] as num?) ?? 0).toInt();
                      final ra = (wa + la) == 0 ? -1.0 : wa / (wa + la);
                      final rb = (wb + lb) == 0 ? -1.0 : wb / (wb + lb);
                      return rb.compareTo(ra);
                  }
                });

                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(t('no_open_tables'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11)),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final data = docs[i].data();
                    final name = data['displayName'] as String? ?? '?';
                    final wins = ((data['onlineWins'] as num?) ?? 0).toInt();
                    final losses =
                        ((data['onlineLosses'] as num?) ?? 0).toInt();
                    final played = wins + losses;
                    final rate = played == 0 ? null : wins / played * 100;
                    final photoBase64 = data['photoBase64'] as String?;
                    final iconIndex = data['avatarIconIndex'] as int?;
                    final colorValue = data['avatarColor'] as int?;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ProfileAvatar.remote(
                            radius: 12,
                            photoBase64: photoBase64,
                            iconIndex: iconIndex,
                            color: colorValue != null
                                ? Color(colorValue)
                                : Colors.white24,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                                Text(
                                  '$played · ${rate == null ? "—" : "${rate.round()}%"}',
                                  style: const TextStyle(
                                      color: Colors.white54, fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _sortIconButton(IconData icon, _PlayerSort sort, String tooltip) {
    final selected = _playerSort == sort;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () => setState(() => _playerSort = sort),
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: selected ? Colors.white24 : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon,
              size: 16, color: selected ? Colors.amber : Colors.white54),
        ),
      ),
    );
  }
}
