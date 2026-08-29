import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../online/firestore_game_repository.dart';
import '../online/persistent_device_id.dart';
import '../settings/app_settings.dart';
import '../settings/user_profile.dart';
import '../settings/strings.dart';
import 'online_game_screen.dart';

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
      final ok = await _repo.joinRoom(code, deviceId);
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
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _createRoom,
                    icon: const Icon(Icons.add),
                    label: Text(t('new_room')),
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(_error!,
                      style: const TextStyle(color: Colors.redAccent)),
                ),
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
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _repo.watchOpenTables(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snapshot.data!.docs.toList();
                    // Kazanma oranına göre azalan sırala (misafirler/oranı
                    // olmayanlar en sona düşer). Sıralama istemci
                    // tarafında yapılıyor.
                    docs.sort((a, b) {
                      final rateA = (a.data()['hostWinRate'] as num?)?.toDouble();
                      final rateB = (b.data()['hostWinRate'] as num?)?.toDouble();
                      if (rateA == null && rateB == null) return 0;
                      if (rateA == null) return 1;
                      if (rateB == null) return -1;
                      return rateB.compareTo(rateA);
                    });

                    if (docs.isEmpty) {
                      return Center(
                        child: Text(t('no_open_tables'),
                            style:
                                const TextStyle(color: Colors.white54)),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: docs.length,
                      itemBuilder: (context, i) {
                        final data = docs[i].data();
                        final code = docs[i].id;
                        final hostName =
                            data['hostDisplayName'] as String? ?? t('guest_label');
                        final winRate =
                            (data['hostWinRate'] as num?)?.toDouble();
                        final avatarIconIndex =
                            data['hostAvatarIconIndex'] as int?;
                        final avatarColorValue =
                            data['hostAvatarColorValue'] as int?;

                        return Card(
                          color: Colors.black26,
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: avatarColorValue != null
                                  ? Color(avatarColorValue)
                                  : Colors.white24,
                              child: Icon(
                                avatarIconIndex != null &&
                                        avatarIconIndex <
                                            kAvatarIcons.length
                                    ? kAvatarIcons[avatarIconIndex]
                                    : Icons.person,
                                color: Colors.white,
                              ),
                            ),
                            title: Text(hostName,
                                style: const TextStyle(color: Colors.white)),
                            subtitle: Text(
                              winRate == null
                                  ? t('no_games_yet')
                                  : '${t('online_win_rate')}: ${winRate.round()}%',
                              style: const TextStyle(
                                  color: Colors.white60, fontSize: 12),
                            ),
                            trailing: ElevatedButton(
                              onPressed:
                                  _loading ? null : () => _joinRoomByCode(code),
                              child: Text(t('join_short')),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              // Kod ile katılma — arkadaşla özel oyun için, katlanır.
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  title: Text(t('manual_join_title'),
                      style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  iconColor: Colors.white70,
                  collapsedIconColor: Colors.white70,
                  onExpansionChanged: (v) =>
                      setState(() => _manualJoinExpanded = v),
                  initiallyExpanded: _manualJoinExpanded,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Column(
                        children: [
                          TextField(
                            controller: _codeController,
                            textAlign: TextAlign.center,
                            textCapitalization: TextCapitalization.characters,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                letterSpacing: 6),
                            maxLength: 4,
                            decoration: InputDecoration(
                              hintText: t('room_code_hint'),
                              hintStyle: const TextStyle(color: Colors.white38),
                              counterText: '',
                              enabledBorder: const UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.white54),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _loading
                                ? null
                                : () => _joinRoomByCode(_codeController.text),
                            child: Text(t('join_room')),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
