import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../online/firestore_game_repository.dart';
import '../online/persistent_device_id.dart';
import '../settings/app_settings.dart';
import '../settings/user_profile.dart';
import '../settings/strings.dart';
import '../widgets/profile_avatar.dart';
import '../settings/moderation.dart';
import '../settings/ranks.dart';
import 'online_game_screen.dart';
import 'channels_screen.dart';

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
  String? _myDeviceId;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _friendSub;
  Set<String> _friendIds = {};
  bool _friendsOnly = false;
  bool _showPlayers = false;

  @override
  void initState() {
    super.initState();
    _deviceId().then((id) {
      if (!mounted) return;
      setState(() => _myDeviceId = id);
      _friendSub = _repo.watchFriendships(id).listen((snap) {
        final ids = <String>{};
        for (final d in snap.docs) {
          for (final u in (d.data()['users'] as List? ?? const [])) {
            if (u != id) ids.add(u as String);
          }
        }
        if (mounted) setState(() => _friendIds = ids);
      }, onError: (_) {});
    });
  }

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

  Future<void> _inviteToPlay(String toDeviceId) async {
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
      await _repo.sendInvite(
        toDeviceId: toDeviceId,
        fromDeviceId: deviceId,
        roomCode: code,
        fromDisplayName: profile.hasProfile ? profile.displayName : null,
        fromAvatarIconIndex: profile.hasProfile ? profile.avatarIconIndex : null,
        fromAvatarColorValue:
            profile.hasProfile ? profile.avatarColor.value : null,
        fromPhotoBase64: profile.hasProfile ? profile.photoBase64 : null,
        fromWinRate: profile.hasProfile ? profile.onlineWinRate : null,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Davet gönderildi. Masan açık lobide kalıyor; davetli katıldığında kendi masandan oyuna geçebilirsin.')),
      );
    } catch (e) {
      setState(() => _error = 'Davet gönderilemedi: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showPlayerDetail(
      BuildContext context, String targetDeviceId, Map<String, dynamic> data) {
    final name = data['displayName'] as String? ?? t('guest_label');
    final wins = ((data['onlineWins'] as num?) ?? 0).toInt();
    final losses = ((data['onlineLosses'] as num?) ?? 0).toInt();
    final played = wins + losses;
    final rate = played == 0 ? null : wins / played * 100;
    final photoBase64 = data['photoBase64'] as String?;
    final iconIndex = data['avatarIconIndex'] as int?;
    final colorValue = data['avatarColor'] as int?;
    final isMe = targetDeviceId == _myDeviceId;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1B1B1B),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        // SafeArea + kaydırma: düğmenin ekran altına taşmasını önler.
        return SafeArea(
          child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ProfileAvatar.remote(
                radius: 30,
                photoBase64: photoBase64,
                iconIndex: iconIndex,
                color: colorValue != null ? Color(colorValue) : Colors.white24,
              ),
              const SizedBox(height: 12),
              Text(name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('${rankFor(wins).emoji} ${t(rankFor(wins).nameKey)}',
                  style: const TextStyle(color: Colors.amber, fontSize: 14)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _StatChip(
                      label: t('games_played'), value: played.toString()),
                  _StatChip(
                      label: t('online_win_rate'),
                      value: rate == null ? '—' : '${rate.round()}%'),
                ],
              ),
              const SizedBox(height: 24),
              if (!isMe) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _loading
                        ? null
                        : () {
                            Navigator.pop(sheetContext);
                            _inviteToPlay(targetDeviceId);
                          },
                    icon: const Icon(Icons.send),
                    label: Text(t('send_invite')),
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
                const SizedBox(height: 8),
                _friendIds.contains(targetDeviceId)
                    ? TextButton.icon(
                        onPressed: () async {
                          Navigator.pop(sheetContext);
                          if (_myDeviceId != null) {
                            await _repo.removeFriend(
                                _myDeviceId!, targetDeviceId);
                          }
                        },
                        icon: const Icon(Icons.favorite,
                            color: Colors.pinkAccent, size: 18),
                        label: Text(t('friend_remove'),
                            style: const TextStyle(color: Colors.white70)),
                      )
                    : OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _sendFriendRequest(targetDeviceId);
                        },
                        icon: const Icon(Icons.person_add_alt_1),
                        label: Text(t('friend_add')),
                      ),
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    await Moderation.instance.block(targetDeviceId, name);
                    if (_myDeviceId != null) {
                      _repo.removeFriend(_myDeviceId!, targetDeviceId);
                    }
                    if (!mounted) return;
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(t('user_blocked'))));
                  },
                  icon: const Icon(Icons.block, color: Colors.white54, size: 18),
                  label: Text(t('block_short'),
                      style: const TextStyle(color: Colors.white54)),
                ),
              ],
            ],
          ),
          ),
        );
      },
    );
  }

  Widget _buildIncomingInvites() {
    if (_myDeviceId == null) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _repo.watchIncomingInvites(_myDeviceId!),
      builder: (context, snapshot) {
        final docs = (snapshot.data?.docs ?? [])
            .where((d) => !Moderation.instance
                .isBlocked(d.data()['fromDeviceId'] as String?))
            .toList();
        if (docs.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            children: docs.map((doc) {
              final data = doc.data();
              final fromName =
                  data['fromDisplayName'] as String? ?? t('guest_label');
              final fromWinRate = (data['fromWinRate'] as num?)?.toDouble();
              final fromPhotoBase64 = data['fromPhotoBase64'] as String?;
              final fromIconIndex = data['fromAvatarIconIndex'] as int?;
              final fromColorValue = data['fromAvatarColorValue'] as int?;
              final roomCode = data['roomCode'] as String? ?? '';

              return Card(
                color: Colors.amber.withOpacity(0.15),
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.amber, width: 1.2),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      ProfileAvatar.remote(
                        radius: 18,
                        photoBase64: fromPhotoBase64,
                        iconIndex: fromIconIndex,
                        color: fromColorValue != null
                            ? Color(fromColorValue)
                            : Colors.white24,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t('invite_received'),
                                style: const TextStyle(
                                    color: Colors.amber,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                            Text(
                              fromWinRate == null
                                  ? fromName
                                  : '$fromName · ${fromWinRate.round()}%',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.white54, size: 20),
                        tooltip: t('close_invite'),
                        onPressed: () => _repo.closeInvite(doc.id),
                      ),
                      ElevatedButton(
                        onPressed: _loading
                            ? null
                            : () async {
                                await _repo.closeInvite(doc.id);
                                if (mounted) _joinRoomByCode(roomCode);
                              },
                        child: Text(t('accept')),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Future<void> _sendFriendRequest(String targetDeviceId) async {
    final p = UserProfile.instance;
    String key;
    if (!p.hasProfile) {
      key = 'friend_need_profile';
    } else {
      final id = await _deviceId();
      final r = await _repo.sendFriendRequest(
        fromDeviceId: id,
        toDeviceId: targetDeviceId,
        fromDisplayName: p.displayName,
        fromAvatarIconIndex: p.avatarIconIndex,
        fromAvatarColorValue: p.avatarColor.value,
        fromPhotoBase64: p.photoBase64,
      );
      key = switch (r) {
        'sent' => 'friend_request_sent',
        'already' => 'friend_already',
        'accepted' => 'friend_added',
        _ => 'friend_error',
      };
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(t(key))));
  }

  Widget _buildIncomingFriendRequests() {
    if (_myDeviceId == null) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _repo.watchIncomingFriendRequests(_myDeviceId!),
      builder: (context, snapshot) {
        final docs = (snapshot.data?.docs ?? [])
            .where((d) => !Moderation.instance
                .isBlocked(d.data()['fromDeviceId'] as String?))
            .toList();
        if (docs.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            children: docs.map((doc) {
              final data = doc.data();
              final fromId = data['fromDeviceId'] as String? ?? '';
              final fromName =
                  data['fromDisplayName'] as String? ?? t('guest_label');
              final fromColor = data['fromAvatarColorValue'] as int?;
              return Card(
                color: Colors.pinkAccent.withOpacity(0.15),
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.pinkAccent, width: 1.2),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      ProfileAvatar.remote(
                        radius: 16,
                        photoBase64: data['fromPhotoBase64'] as String?,
                        iconIndex: data['fromAvatarIconIndex'] as int?,
                        color: fromColor != null
                            ? Color(fromColor)
                            : Colors.white24,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '$fromName ${t('friend_request_text')}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.white54, size: 20),
                        onPressed: () => _repo.declineFriendRequest(doc.id),
                      ),
                      ElevatedButton(
                        onPressed: () => _repo.acceptFriendRequest(
                          requestId: doc.id,
                          fromDeviceId: fromId,
                          toDeviceId: _myDeviceId!,
                        ),
                        child: Text(t('accept')),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
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
    _friendSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppSettings.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppSettings.instance.themeColor,
          appBar: AppBar(
            backgroundColor: const Color(0xFF142238),
            foregroundColor: Colors.white,
            title: Row(children: [
              const Icon(Icons.public_rounded, color: Color(0xFFFBBF24), size: 23),
              const SizedBox(width: 9),
              Text(t('lobby_title'), style: const TextStyle(fontWeight: FontWeight.w800)),
            ]),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ChannelsScreen())),
                  icon: const Icon(Icons.forum_rounded, size: 17),
                  label: const Text('Kanallar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFBBF24),
                    side: const BorderSide(color: Color(0x88FBBF24)),
                    padding: const EdgeInsets.symmetric(horizontal: 11),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                _buildIncomingInvites(),
                _buildIncomingFriendRequests(),
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 15),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF243B58), Color(0xFF142238)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0x44FBBF24)),
                    boxShadow: const [
                      BoxShadow(color: Color(0x33000000), blurRadius: 14, offset: Offset(0, 6)),
                    ],
                  ),
                  child: Row(children: [
                    Container(
                      width: 44, height: 44,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [Color(0xFFFFD84D), Color(0xFFF59E0B)]),
                      ),
                      child: const Icon(Icons.sports_esports_rounded, color: Color(0xFF172033), size: 24),
                    ),
                    const SizedBox(width: 13),
                    const Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('GENEL LOBİ', style: TextStyle(
                          color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 0.7)),
                        SizedBox(height: 3),
                        Text('Açık masalara katıl veya kendi masanı kur.',
                          style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                      ],
                    )),
                    if (_loading)
                      const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFBBF24))),
                  ]),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 5, 16, 0),
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                      childrenPadding: const EdgeInsets.symmetric(horizontal: 8),
                      title: Row(children: [
                        const Icon(Icons.key_rounded, color: Color(0xFFFBBF24), size: 17),
                        const SizedBox(width: 8),
                        Text(t('manual_join_title'),
                          style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                      ]),
                      iconColor: Colors.white70,
                      collapsedIconColor: Colors.white70,
                      onExpansionChanged: (v) => setState(() => _manualJoinExpanded = v),
                      initiallyExpanded: _manualJoinExpanded,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Column(children: [
                            TextField(
                              controller: _codeController,
                              textAlign: TextAlign.center,
                              textCapitalization: TextCapitalization.characters,
                              style: const TextStyle(color: Colors.white, fontSize: 22, letterSpacing: 6),
                              maxLength: 4,
                              decoration: InputDecoration(
                                hintText: t('room_code_hint'),
                                hintStyle: const TextStyle(color: Colors.white38),
                                counterText: '',
                                enabledBorder: const UnderlineInputBorder(
                                  borderSide: BorderSide(color: Colors.white54)),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(width: double.infinity, child: FilledButton(
                              onPressed: _loading ? null : () => _joinRoomByCode(_codeController.text),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFFBBF24),
                                foregroundColor: const Color(0xFF101827)),
                              child: Text(t('join_room')),
                            )),
                          ]),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111F31),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(children: [
                      Expanded(child: _lobbyTabButton(
                        label: t('open_tables'), icon: Icons.table_restaurant_rounded,
                        selected: !_showPlayers, onTap: () => setState(() => _showPlayers = false))),
                      const SizedBox(width: 4),
                      Expanded(child: _lobbyTabButton(
                        label: t('players_title'), icon: Icons.groups_rounded,
                        selected: _showPlayers, onTap: () => setState(() => _showPlayers = true))),
                    ]),
                  ),
                ),
                Expanded(child: _showPlayers ? _buildPlayersPanel() : _buildOpenTablesList()),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _lobbyTabButton({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? const Color(0xFFFBBF24) : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 17,
              color: selected ? const Color(0xFF101827) : Colors.white60),
            const SizedBox(width: 7),
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? const Color(0xFF101827) : Colors.white70,
                fontSize: 12, fontWeight: FontWeight.w800))),
          ]),
        ),
      ),
    );
  }

  Widget _buildOpenTablesList() {
    // "Boş Masa" kartı bilerek StreamBuilder'ın DIŞINDA — Firestore akışı
    // yüklenirken, hata verirken ya da hiç kayıt yokken bile HER ZAMAN
    // görünsün diye. Önceki tasarımda bu kart akışın içindeydi ve akış
    // (ör. eksik bir Firestore dizini yüzünden) takılırsa hiç görünmüyordu.
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: _buildTwoSeatCard(
            onTap: _loading ? null : _createRoom,
            seat1: _seatEmpty(highlight: true),
            seat2: _seatEmpty(),
            centerTitle: t('empty_table'),
            centerSubtitle: t('sit_and_wait'),
            borderColor: Colors.white.withOpacity(0.35),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _repo.watchOpenTables(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.redAccent, fontSize: 11)),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }
              final docs = snapshot.data!.docs.toList();
              docs.removeWhere((d) => Moderation.instance
                  .isBlocked(d.data()['hostDeviceId'] as String?));
              // Kazanma oranına göre azalan sırala (misafirler/oranı
              // olmayanlar en sona düşer). Sıralama istemci tarafında.
              docs.sort((a, b) {
                final rateA = (a.data()['hostWinRate'] as num?)?.toDouble();
                final rateB = (b.data()['hostWinRate'] as num?)?.toDouble();
                if (rateA == null && rateB == null) return 0;
                if (rateA == null) return 1;
                if (rateB == null) return -1;
                return rateB.compareTo(rateA);
              });

              if (docs.isEmpty) return const SizedBox.shrink();

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(0, 4, 4, 16),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final data = docs[i].data();
                  final code = docs[i].id;
                  final hostName =
                      data['hostDisplayName'] as String? ?? t('guest_label');
                  final winRate = (data['hostWinRate'] as num?)?.toDouble();
                  final avatarIconIndex = data['hostAvatarIconIndex'] as int?;
                  final avatarColorValue =
                      data['hostAvatarColorValue'] as int?;
                  final photoBase64 = data['hostPhotoBase64'] as String?;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildTwoSeatCard(
                      onTap: _loading ? null : () {
                        if (data['hostDeviceId'] == _myDeviceId) {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => OnlineGameScreen(
                            roomCode: code, deviceId: _myDeviceId!, isHost: true,
                          )));
                        } else {
                          _joinRoomByCode(code);
                        }
                      },
                      seat1: ProfileAvatar.remote(
                        radius: 20,
                        photoBase64: photoBase64,
                        iconIndex: avatarIconIndex,
                        color: avatarColorValue != null
                            ? Color(avatarColorValue)
                            : Colors.white24,
                      ),
                      seat2: _seatEmpty(highlight: true),
                      centerTitle: data['hostDeviceId'] == _myDeviceId ? 'SENİN MASAN · $hostName' : hostName,
                      centerSubtitle: winRate == null
                          ? t('no_games_yet')
                          : '${t('online_win_rate')}: ${winRate.round()}%',
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  /// Karşılıklı iki koltuklu masa görünümü: solda 1. koltuk, sağda 2.
  /// koltuk, ortada masa bilgisi. Dolu koltuk avatar gösterir, boş
  /// koltuk "+" ile oturulabilir olduğunu belli eder.
  Widget _buildTwoSeatCard({
    required VoidCallback? onTap,
    required Widget seat1,
    required Widget seat2,
    required String centerTitle,
    required String centerSubtitle,
    Color borderColor = Colors.white24,
  }) {
    return Card(
      color: Colors.black26,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: 1.3),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              seat1,
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.table_restaurant,
                        color: Colors.white24, size: 16),
                    const SizedBox(height: 2),
                    Text(centerTitle,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                    Text(centerSubtitle,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 11)),
                  ],
                ),
              ),
              seat2,
            ],
          ),
        ),
      ),
    );
  }

  /// Boş bir koltuğu temsil eden kesikli çerçeveli "+" ikonu.
  Widget _seatEmpty({bool highlight = false}) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: highlight ? Colors.amber : Colors.white38,
          width: 1.6,
        ),
      ),
      child: Icon(Icons.add,
          color: highlight ? Colors.amber : Colors.white38, size: 20),
    );
  }

  /// Sağda duran, tüm profilli oyuncuları listeleyen ve alfabetik / oyun
  /// sayısı / online kazanma oranına göre sıralanabilen kompakt panel.
  Widget _buildPlayersPanel() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
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
              _friendsToggleButton(),
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
                docs.removeWhere((d) => Moderation.instance.isBlocked(d.id));
                if (_friendsOnly) {
                  docs.retainWhere((d) => _friendIds.contains(d.id));
                }
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
                      child: Text(
                          _friendsOnly ? t('no_friends_yet') : t('no_open_tables'),
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
                    return InkWell(
                      onTap: () =>
                          _showPlayerDetail(context, docs[i].id, data),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
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
                                  Row(
                                    children: [
                                      Text('${rankFor(wins).emoji} ',
                                          style: const TextStyle(fontSize: 11)),
                                      Flexible(
                                        child: Text(name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold)),
                                      ),
                                      if (_friendIds.contains(docs[i].id))
                                        const Padding(
                                          padding: EdgeInsets.only(left: 3),
                                          child: Icon(Icons.favorite,
                                              color: Colors.pinkAccent, size: 11),
                                        ),
                                    ],
                                  ),
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

  Widget _friendsToggleButton() {
    return Tooltip(
      message: t('friends_filter'),
      child: GestureDetector(
        onTap: () => setState(() => _friendsOnly = !_friendsOnly),
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: _friendsOnly ? Colors.white24 : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.favorite,
              size: 16,
              color: _friendsOnly ? Colors.pinkAccent : Colors.white54),
        ),
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

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.amber,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
      ],
    );
  }
}
