import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import '../online/firestore_game_repository.dart';
import '../settings/progress.dart';
import '../settings/auth_service.dart';
import '../settings/user_profile.dart';
import '../settings/strings.dart';
import 'online_game_screen.dart';
import 'profile_screen.dart';

class ChannelsScreen extends StatefulWidget {
  const ChannelsScreen({super.key});
  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> {
  final _repo = OnlineRoomRepository();
  String? _deviceId;
  bool _busy = false;
  bool _inviteOnly = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Güvenli kanal üyeliği yalnızca Firebase hesabının UID'siyle yapılır.
    _deviceId = FirebaseAuth.instance.currentUser?.uid;
  }

  Future<void> _createChannel() async {
    final name = TextEditingController();
    final description = TextEditingController();
    _inviteOnly = false;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1B293D),
        title: const Text('Yeni kanal oluştur', style: TextStyle(color: Colors.white)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, maxLength: 32, style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Kanal adı', labelStyle: TextStyle(color: Colors.white70))),
          TextField(controller: description, maxLength: 100, maxLines: 2, style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Kısa açıklama', labelStyle: TextStyle(color: Colors.white70))),
          StatefulBuilder(builder: (context, setDialogState) => SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Yalnızca davetliler katılabilsin', style: TextStyle(color: Colors.white, fontSize: 13)),
            subtitle: const Text('Davet kodu olmayan oyuncular kanala katılamaz.', style: TextStyle(color: Colors.white60, fontSize: 11)),
            value: _inviteOnly,
            activeColor: const Color(0xFFFBBF24),
            onChanged: (value) => setDialogState(() => _inviteOnly = value),
          )),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Oluştur')),
        ],
      ),
    );
    final cleanName = name.text.trim();
    final cleanDescription = description.text.trim();
    name.dispose(); description.dispose();
    if (result != true || _deviceId == null) return;
    if (cleanName.length < 2) {
      setState(() => _error = 'Kanal adı en az 2 karakter olmalı.');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      final p = UserProfile.instance;
      final id = await _repo.createChannel(
        ownerDeviceId: _deviceId!,
        ownerPlayerDeviceId: p.deviceId ?? '',
        ownerDisplayName: p.hasProfile ? p.displayName! : t('you'),
        name: cleanName,
        description: cleanDescription,
        inviteOnly: _inviteOnly,
      );
      if (mounted) await _openChannel(id, joinIfNeeded: false);
    } catch (e) {
      if (mounted) setState(() => _error = 'Kanal oluşturulamadı: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _joinByInviteCode() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1B293D),
      title: const Text('Davet koduyla katıl', style: TextStyle(color: Colors.white)),
      content: TextField(controller: controller, textCapitalization: TextCapitalization.characters,
        maxLength: 8, style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(hintText: '8 haneli kod')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
        FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Katıl')),
      ],
    ));
    final code = value?.trim().toUpperCase();
    controller.dispose();
    if (code == null || code.isEmpty || _deviceId == null) return;
    setState(() { _busy = true; _error = null; });
    try {
      final p = UserProfile.instance;
      final joined = await _repo.joinPrivateChannelByCode(
        code: code, deviceId: _deviceId!,
        playerDeviceId: p.deviceId ?? '',
        displayName: p.hasProfile ? p.displayName! : t('you'),
      );
      if (!joined) throw StateError('Davet kodu geçersiz veya kanal kapalı.');
      final id = await _repo.findChannelByInviteCode(code);
      if (id != null && mounted) await _openChannel(id, joinIfNeeded: false);
    } catch (e) {
      if (mounted) setState(() => _error = 'Kanala katılınamadı: ' + e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openChannel(String id, {bool joinIfNeeded = true}) async {
    if (_deviceId == null) return;
    if (joinIfNeeded) {
      final p = UserProfile.instance;
      final joined = await _repo.joinChannel(
        channelId: id, deviceId: _deviceId!,
        playerDeviceId: p.deviceId ?? '',
        displayName: p.hasProfile ? p.displayName! : t('you'),
      );
      if (!joined) {
        if (mounted) setState(() => _error = 'Bu kanal şu anda kullanılamıyor.');
        return;
      }
    }
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ChannelDetailScreen(channelId: id, deviceId: _deviceId!, playerDeviceId: UserProfile.instance.deviceId ?? ''),
    ));
  }

  Future<void> _openAccountForChannels() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
    if (!mounted) return;
    setState(() => _deviceId = FirebaseAuth.instance.currentUser?.uid);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF101827),
    appBar: AppBar(backgroundColor: const Color(0xFF142238), foregroundColor: Colors.white,
      title: const Text('Oyuncu Kanalları')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _busy || _deviceId == null ? null : _createChannel,
      backgroundColor: const Color(0xFFFBBF24), foregroundColor: const Color(0xFF101827),
      icon: const Icon(Icons.add_rounded),
      label: const Text('Kanal oluştur', style: TextStyle(fontWeight: FontWeight.bold))),
    body: _deviceId == null
      ? SafeArea(child: Center(child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.lock_rounded, color: Color(0xFFFBBF24), size: 48),
            const SizedBox(height: 14),
            const Text('Kanallar için hesap gerekli',
              style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text('Toplulukların ve davetli kanalların güvenli kalması için kanallar yalnızca giriş yapmış hesaplara açıktır. Misafir olarak diğer oyun modlarını kullanmaya devam edebilirsin.',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, height: 1.4)),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _openAccountForChannels,
              icon: const Icon(Icons.account_circle_rounded),
              label: const Text('Giriş yap / Hesap oluştur'),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFBBF24), foregroundColor: const Color(0xFF101827)),
            ),
          ]),
        )))
      : SafeArea(child: Column(children: [
      Container(
        margin: const EdgeInsets.fromLTRB(16, 14, 16, 12), padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF203A5B), Color(0xFF142238)]),
          borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0x553B82F6))),
        child: const Row(children: [
          Icon(Icons.hub_rounded, color: Color(0xFFFBBF24), size: 34), SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Kendi topluluğunu kur', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            SizedBox(height: 4),
            Text('Kanalın maç odasından bağımsız kalır. Oyuncular katılabilir, ayrılabilir ve kanaldan maç daveti alabilir.',
              style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.35)),
          ])),
        ]),
      ),
      Align(alignment: Alignment.centerRight, child: TextButton.icon(
        onPressed: _busy ? null : _joinByInviteCode,
        icon: const Icon(Icons.key_rounded, color: Color(0xFFFBBF24), size: 17),
        label: const Text('Davet koduyla katıl', style: TextStyle(color: Color(0xFFFBBF24))),
      )),
      if (_error != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        child: Text(_error!, style: const TextStyle(color: Colors.redAccent))),
      Expanded(child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _repo.watchChannels(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Kanallar yüklenemedi: ${snapshot.error}', style: const TextStyle(color: Colors.white70)));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFFFBBF24)));
          final docs = snapshot.data!.docs.where((d) => d.data()['visibility'] != 'invite_only').toList();
          if (docs.isEmpty) return const Center(child: Text('Henüz kanal yok. İlk kanalı sen oluştur!', style: TextStyle(color: Colors.white60)));
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100), itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = docs[index]; final data = doc.data();
              return Container(
                decoration: BoxDecoration(color: const Color(0xFF1B293D), borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0x223B82F6))),
                child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
                  Container(width: 48, height: 48, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x223B82F6)),
                    child: const Icon(Icons.forum_rounded, color: Color(0xFF60A5FA), size: 25)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(data['name'] as String? ?? 'Kanal', maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                    if ((data['description'] as String? ?? '').isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(data['description'] as String, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white60, fontSize: 12)),
                    ],
                    const SizedBox(height: 5),
                    Text('${data['memberCount'] ?? 0} oyuncu  ·  ${data['ownerDisplayName'] ?? 'Topluluk'}',
                      style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 11, fontWeight: FontWeight.w600)),
                  ])),
                  StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: _deviceId == null ? null : _repo.watchChannelMembership(doc.id, _deviceId!),
                    builder: (context, memberSnapshot) {
                      final isMember = memberSnapshot.data?.exists == true;
                      return FilledButton(
                        onPressed: _busy || _deviceId == null ? null : () => _openChannel(doc.id, joinIfNeeded: !isMember),
                        style: FilledButton.styleFrom(backgroundColor: isMember ? const Color(0xFF263B55) : const Color(0xFF2563EB), foregroundColor: Colors.white),
                        child: Text(isMember ? 'Aç' : 'Katıl'));
                    }),
                ])),
              );
            },
          );
        },
      )),
    ])),
  );
}

class ChannelDetailScreen extends StatefulWidget {
  final String channelId;
  final String deviceId;
  final String playerDeviceId;
  const ChannelDetailScreen({super.key, required this.channelId, required this.deviceId, required this.playerDeviceId});
  @override
  State<ChannelDetailScreen> createState() => _ChannelDetailScreenState();
}

class _ChannelDetailScreenState extends State<ChannelDetailScreen> {
  final _repo = OnlineRoomRepository();
  bool _busy = false;
  bool _openingMatch = false;
  String? _pendingRoomCode;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _roomSub;

  @override
  void dispose() {
    _roomSub?.cancel();
    super.dispose();
  }

  Future<void> _createTournament() async {
    final title = TextEditingController();
    String format = 'single_elimination';
    int maxPlayers = 16;
    final result = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        backgroundColor: const Color(0xFF1B293D),
        title: const Text('Turnuva oluştur', style: TextStyle(color: Colors.white)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: title, maxLength: 40, style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Turnuva adı', labelStyle: TextStyle(color: Colors.white70))),
          DropdownButtonFormField<String>(
            value: format, dropdownColor: const Color(0xFF1B293D),
            decoration: const InputDecoration(labelText: 'Format', labelStyle: TextStyle(color: Colors.white70)),
            items: const [
              DropdownMenuItem(value: 'single_elimination', child: Text('Eleme usulü', style: TextStyle(color: Colors.white))),
              DropdownMenuItem(value: 'round_robin', child: Text('Herkes birbiriyle', style: TextStyle(color: Colors.white))),
            ],
            onChanged: (v) => setDialogState(() {
              format = v ?? format;
              if (format == 'round_robin' && maxPlayers > 16) maxPlayers = 16;
            }),
          ),
          DropdownButtonFormField<int>(
            value: maxPlayers, dropdownColor: const Color(0xFF1B293D),
            decoration: const InputDecoration(labelText: 'Oyuncu sınırı', labelStyle: TextStyle(color: Colors.white70)),
            items: (format == 'round_robin' ? [8, 16] : [8, 16, 32, 64]).map((n) => DropdownMenuItem(value: n, child: Text('$n oyuncu', style: const TextStyle(color: Colors.white)))).toList(),
            onChanged: (v) => setDialogState(() => maxPlayers = v ?? maxPlayers),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Oluştur')),
        ],
      ),
    ));
    final cleanTitle = title.text.trim();
    title.dispose();
    if (result != true || cleanTitle.length < 2) return;
    try {
      await _repo.createChannelTournament(
        channelId: widget.channelId, creatorDeviceId: widget.deviceId,
        title: cleanTitle, format: format, maxPlayers: maxPlayers,
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Turnuva oluşturulamadı: ' + e.toString())));
    }
  }

  Future<void> _joinTournament(String id) async {
    final joined = await _repo.joinChannelTournament(
      channelId: widget.channelId, tournamentId: id, deviceId: widget.deviceId,
    );
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(joined ? 'Turnuvaya katıldın.' : 'Katılım kapalı veya kontenjan dolu.')),
    );
  }

  Future<void> _startTournament(String id) async {
    try {
      await _repo.startChannelTournament(
        channelId: widget.channelId, tournamentId: id, creatorDeviceId: widget.deviceId,
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _leave() async {
    await _repo.leaveChannel(widget.channelId, widget.deviceId);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _startMatch(String targetDeviceId) async {
    if (_busy || targetDeviceId == widget.playerDeviceId || _pendingRoomCode != null) return;
    setState(() => _busy = true);
    try {
      final p = UserProfile.instance;
      final displayName = p.hasProfile ? p.displayName : t('you');
      final code = await _repo.createRoom(
        widget.playerDeviceId,
        hostDisplayName: displayName,
        hostWinRate: p.hasProfile ? p.onlineWinRate : null,
        hostAvatarIconIndex: p.hasProfile ? p.avatarIconIndex : null,
        hostAvatarColorValue: p.hasProfile ? p.avatarColor.value : null,
        hostPhotoBase64: p.hasProfile ? p.photoBase64 : null,
      );
      await _repo.sendInvite(
        toDeviceId: targetDeviceId,
        fromDeviceId: widget.playerDeviceId,
        roomCode: code,
        fromDisplayName: displayName,
        fromAvatarIconIndex: p.hasProfile ? p.avatarIconIndex : null,
        fromAvatarColorValue: p.hasProfile ? p.avatarColor.value : null,
        fromPhotoBase64: p.hasProfile ? p.photoBase64 : null,
        fromWinRate: p.hasProfile ? p.onlineWinRate : null,
      );
      if (!mounted) return;
      setState(() => _pendingRoomCode = code);
      _roomSub?.cancel();
      _roomSub = _repo.watchRoom(code).listen((snapshot) {
        final data = snapshot.data();
        if (!mounted || _openingMatch || data == null) return;
        if (data['guestDeviceId'] != null && data['roomStatus'] == 'ready') {
          _openingMatch = true;
          _roomSub?.cancel();
          Navigator.push(context, MaterialPageRoute(builder: (_) =>
            OnlineGameScreen(roomCode: code, deviceId: widget.playerDeviceId, isHost: true)))
            .then((_) {
              if (mounted) {
                setState(() {
                  _pendingRoomCode = null;
                  _openingMatch = false;
                });
              }
            });
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Davet gönderildi. Rakibin katılana kadar kanalında kalabilirsin.')),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Davet oluşturulamadı: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final channel = FirebaseFirestore.instance.collection('channels').doc(widget.channelId);
    return Scaffold(
      backgroundColor: const Color(0xFF101827),
      appBar: AppBar(backgroundColor: const Color(0xFF142238), foregroundColor: Colors.white,
        title: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('channels').doc(widget.channelId).snapshots(),
          builder: (context, snapshot) => Text(snapshot.data?.data()?['name'] as String? ?? 'Kanal'),
        ),
        actions: [
          IconButton(
            tooltip: 'Kanal sohbeti',
            icon: const Icon(Icons.forum_rounded, color: Color(0xFFFBBF24)),
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => ChannelChatScreen(channelId: widget.channelId, deviceId: widget.deviceId),
            )),
          ),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('channels').doc(widget.channelId).snapshots(),
            builder: (context, snapshot) {
              final data = snapshot.data?.data();
              if (data?['ownerDeviceId'] != widget.deviceId || data?['visibility'] != 'invite_only') {
                return const SizedBox.shrink();
              }
              final code = data?['inviteCode'] as String?;
              return IconButton(
                tooltip: 'Davet kodunu kopyala',
                onPressed: code == null ? null : () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Davet kodu kopyalandı.')));
                },
                icon: const Icon(Icons.key_rounded, color: Color(0xFFFBBF24)),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _repo.watchChannelMembers(widget.channelId),
        builder: (context, snapshot) {
          final members = snapshot.data?.docs ?? const [];
          return Column(children: [
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF243A55), Color(0xFF18283D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0x44FBBF24)),
              ),
              child: Row(children: [
                const Icon(Icons.groups_rounded, color: Color(0xFFFBBF24), size: 30),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${members.length} oyuncu kanalda',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    const Text('Bir oyuncu seçip özel maç daveti gönder.',
                      style: TextStyle(color: Colors.white60, fontSize: 12)),
                  ],
                )),
              ]),
            ),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _repo.watchChannelTournaments(widget.channelId),
              builder: (context, tournamentSnapshot) {
                final tournaments = tournamentSnapshot.data?.docs ?? const [];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Expanded(child: Text('KANAL TURNUVALARI',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1))),
                      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: channel.snapshots(),
                        builder: (context, ownerSnapshot) {
                          final isOwner = ownerSnapshot.data?.data()?['ownerDeviceId'] == widget.deviceId;
                          return isOwner ? TextButton.icon(
                            onPressed: _createTournament,
                            icon: const Icon(Icons.add, color: Color(0xFFFBBF24), size: 17),
                            label: const Text('Turnuva kur', style: TextStyle(color: Color(0xFFFBBF24))),
                          ) : const SizedBox.shrink();
                        },
                      ),
                    ]),
                    if (tournaments.isEmpty)
                      const Text('Kanal kurucusu burada turnuva düzenleyebilir.',
                        style: TextStyle(color: Colors.white54, fontSize: 11))
                    else
                      ...tournaments.map((doc) {
                        final data = doc.data();
                        final participants = List<String>.from(data['participantIds'] ?? const <String>[]);
                        final status = data['status'] as String? ?? 'registration';
                        final isCreator = data['creatorDeviceId'] == widget.deviceId;
                        final isParticipant = participants.contains(widget.deviceId);
                        final maxPlayers = data['maxPlayers'] ?? 16;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 7),
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(color: const Color(0xFF1B293D), borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0x44FBBF24))),
                          child: Row(children: [
                            const Icon(Icons.emoji_events_rounded, color: Color(0xFFFBBF24)),
                            const SizedBox(width: 9),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(data['title'] as String? ?? 'Turnuva', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                              Text(participants.length.toString() + '/' + maxPlayers.toString() + ' oyuncu · ' + (status == 'registration' ? 'Kayıt açık' : status == 'completed' ? 'Tamamlandı' : 'Devam ediyor'),
                                style: const TextStyle(color: Colors.white60, fontSize: 11)),
                            ])),
                            if (status == 'registration' && !isParticipant)
                              TextButton(onPressed: () => _joinTournament(doc.id), child: const Text('Katıl')),
                            if (status == 'registration' && isCreator)
                              IconButton(onPressed: () => _startTournament(doc.id),
                                tooltip: 'Turnuvayı başlat',
                                icon: const Icon(Icons.play_arrow_rounded, color: Color(0xFFFBBF24))),
                            if (status == 'in_progress' || status == 'completed')
                              TextButton(
                                onPressed: () => Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => ChannelTournamentScreen(
                                    channelId: widget.channelId,
                                    tournamentId: doc.id,
                                    deviceId: widget.deviceId,
                                  ),
                                )),
                                child: Text(status == 'completed' ? 'Geçmiş' : 'Eşleşmeler'),
                              ),
                          ]),
                        );
                      }),
                  ]),
                );
              },
            ),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _repo.watchChannelTournamentStats(widget.channelId),
              builder: (context, statsSnapshot) {
                final stats = [...(statsSnapshot.data?.docs ?? const [])]
                  ..sort((a, b) {
                    final aData = a.data();
                    final bData = b.data();
                    final championCompare = ((bData['championships'] as num?) ?? 0)
                        .compareTo((aData['championships'] as num?) ?? 0);
                    if (championCompare != 0) return championCompare;
                    final podiumCompare = ((bData['podiums'] as num?) ?? 0)
                        .compareTo((aData['podiums'] as num?) ?? 0);
                    if (podiumCompare != 0) return podiumCompare;
                    return ((bData['starsEarned'] as num?) ?? 0)
                        .compareTo((aData['starsEarned'] as num?) ?? 0);
                  });
                Map<String, dynamic>? myStats;
                for (final item in stats) {
                  if (item.id == widget.deviceId) {
                    myStats = item.data();
                    break;
                  }
                }
                if (stats.isEmpty && myStats == null) return const SizedBox.shrink();
                final memberNames = {
                  for (final member in members)
                    member.id: member.data()['displayName'] as String? ?? 'Oyuncu',
                };
                return Container(
                  margin: const EdgeInsets.fromLTRB(16, 2, 16, 12),
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: const Color(0xFF17263A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0x55FBBF24)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (myStats != null) ...[
                      const Text('SENİN TURNUVA PERFORMANSIN',
                        style: TextStyle(color: Color(0xFFFBBF24), fontSize: 10,
                          fontWeight: FontWeight.w900, letterSpacing: .5)),
                      const SizedBox(height: 7),
                      Row(children: [
                        _TournamentStatPill(label: 'Turnuva', value: '${myStats['tournamentsPlayed'] ?? 0}'),
                        const SizedBox(width: 6),
                        _TournamentStatPill(label: 'Şampiyonluk', value: '${myStats['championships'] ?? 0}'),
                        const SizedBox(width: 6),
                        _TournamentStatPill(label: 'Podyum', value: '${myStats['podiums'] ?? 0}'),
                        const SizedBox(width: 6),
                        _TournamentStatPill(label: 'Yıldız', value: '${myStats['starsEarned'] ?? 0}'),
                      ]),
                      const SizedBox(height: 12),
                    ],
                    const Row(children: [
                      Icon(Icons.leaderboard_rounded, color: Color(0xFFFBBF24), size: 19),
                      SizedBox(width: 8),
                      Text('KANALIN TURNUVA SIRALAMASI',
                        style: TextStyle(color: Colors.white, fontSize: 11,
                          fontWeight: FontWeight.w900, letterSpacing: .5)),
                    ]),
                    const SizedBox(height: 8),
                    for (var i = 0; i < stats.length && i < 5; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(children: [
                          SizedBox(width: 24, child: Text(
                            '${i + 1}.',
                            style: TextStyle(
                              color: i == 0 ? const Color(0xFFFBBF24) : Colors.white60,
                              fontWeight: FontWeight.w900),
                          )),
                          Expanded(child: Text(
                            memberNames[stats[i].id] ?? 'Oyuncu',
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                          Text('${stats[i].data()['championships'] ?? 0} şamp.  ·  '
                            '${stats[i].data()['podiums'] ?? 0} podyum',
                            style: const TextStyle(color: Colors.white70, fontSize: 10)),
                        ]),
                      ),
                  ]),
                );
              },
            ),
            if (_pendingRoomCode != null)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: const Color(0x2234D399),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x6634D399)),
                ),
                child: const Row(children: [
                  SizedBox(width: 8, height: 8, child: DecoratedBox(
                    decoration: BoxDecoration(color: Color(0xFF34D399), shape: BoxShape.circle))),
                  SizedBox(width: 10),
                  Expanded(child: Text('Davet bekleniyor · Kanalın açık kalıyor',
                    style: TextStyle(color: Color(0xFFB7F7D5), fontSize: 12, fontWeight: FontWeight.w700))),
                ]),
              ),
            Expanded(child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              itemCount: members.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final member = members[index];
                final data = member.data();
                final isMe = member.id == widget.deviceId;
                return Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B293D),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: isMe ? const Color(0x66FBBF24) : Colors.white10),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                    leading: CircleAvatar(
                      backgroundColor: isMe ? const Color(0x33FBBF24) : const Color(0x223B82F6),
                      child: Icon(Icons.person_rounded,
                        color: isMe ? const Color(0xFFFBBF24) : Colors.white),
                    ),
                    title: Text(data['displayName'] as String? ?? t('guest_label'),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    subtitle: Text(isMe ? 'Sen' : (data['role'] == 'owner' ? 'Kanal sahibi' : 'Oyuncu'),
                      style: const TextStyle(color: Colors.white54, fontSize: 11)),
                    trailing: isMe
                      ? const Icon(Icons.verified_rounded, color: Color(0xFFFBBF24))
                      : FilledButton(
                          onPressed: _busy || _pendingRoomCode != null
                            ? null : () => _startMatch(data['playerDeviceId'] as String? ?? member.id),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFFBBF24),
                            foregroundColor: const Color(0xFF101827),
                            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                          ),
                          child: const Text('Davet et', style: TextStyle(fontWeight: FontWeight.w800)),
                        ),
                  ),
                );
              })),
            SafeArea(top: false, child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: SizedBox(width: double.infinity, child: OutlinedButton.icon(
                onPressed: _busy ? null : _leave, icon: const Icon(Icons.logout_rounded),
                label: const Text('Kanaldan ayrıl'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white70, padding: const EdgeInsets.symmetric(vertical: 14)))))),
          ]);
        },
      ),
    );
  }
}


class ChannelChatScreen extends StatefulWidget {
  final String channelId;
  final String deviceId;
  const ChannelChatScreen({super.key, required this.channelId, required this.deviceId});

  @override
  State<ChannelChatScreen> createState() => _ChannelChatScreenState();
}

class _ChannelChatScreenState extends State<ChannelChatScreen> {
  final _repo = OnlineRoomRepository();
  final _controller = TextEditingController();
  bool _sending = false;
  bool _announcement = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send({required bool isOwner}) async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final profile = UserProfile.instance;
      await _repo.sendChannelMessage(
        channelId: widget.channelId,
        senderUid: widget.deviceId,
        senderName: profile.hasProfile ? profile.displayName! : 'Oyuncu',
        text: text,
        announcement: _announcement && isOwner,
      );
      _controller.clear();
      if (mounted) setState(() => _announcement = false);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mesaj gönderilemedi: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final channel = FirebaseFirestore.instance.collection('channels').doc(widget.channelId);
    return Scaffold(
      backgroundColor: const Color(0xFF101827),
      appBar: AppBar(
        backgroundColor: const Color(0xFF142238),
        foregroundColor: Colors.white,
        title: const Text('Kanal sohbeti'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: channel.snapshots(),
        builder: (context, channelSnapshot) {
          final isOwner = channelSnapshot.data?.data()?['ownerDeviceId'] == widget.deviceId;
          return Column(children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _repo.watchChannelMessages(widget.channelId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text('Sohbet yüklenemedi: ${snapshot.error}',
                        textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54)),
                    ));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFFFBBF24)));
                  }
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return const Center(child: Text('Henüz mesaj yok. İlk mesajı sen gönder.',
                      style: TextStyle(color: Colors.white54)));
                  }
                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data();
                      final mine = data['senderUid'] == widget.deviceId;
                      final announcement = data['isAnnouncement'] == true;
                      final sentAt = data['sentAt'];
                      final time = sentAt is Timestamp ? sentAt.toDate() : null;
                      return Align(
                        alignment: announcement ? Alignment.center : (mine ? Alignment.centerRight : Alignment.centerLeft),
                        child: Container(
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .86),
                          margin: const EdgeInsets.only(bottom: 9),
                          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                          decoration: BoxDecoration(
                            color: announcement ? const Color(0xFF473A19) : (mine ? const Color(0xFF263B55) : const Color(0xFF1B293D)),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: announcement ? const Color(0x99FBBF24) : Colors.white10),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            if (announcement)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 5),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(Icons.campaign_rounded, color: Color(0xFFFBBF24), size: 15),
                                  SizedBox(width: 5),
                                  Text('KANAL DUYURUSU', style: TextStyle(color: Color(0xFFFBBF24), fontSize: 10, fontWeight: FontWeight.w900)),
                                ]),
                              ),
                            if (!mine)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(data['senderName'] as String? ?? 'Oyuncu',
                                  style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 11, fontWeight: FontWeight.w800)),
                              ),
                            Text(data['text'] as String? ?? '', style: const TextStyle(color: Colors.white, height: 1.35)),
                            if (time != null)
                              Align(alignment: Alignment.bottomRight, child: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text('${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                                  style: const TextStyle(color: Colors.white38, fontSize: 9)),
                              )),
                          ]),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: const BoxDecoration(
                color: Color(0xFF142238),
                border: Border(top: BorderSide(color: Colors.white12)),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (_announcement && isOwner)
                  const Align(alignment: Alignment.centerLeft, child: Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 5),
                    child: Text('Duyuru olarak gönderilecek', style: TextStyle(color: Color(0xFFFBBF24), fontSize: 11, fontWeight: FontWeight.w700)),
                  )),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  if (isOwner)
                    IconButton(
                      tooltip: 'Duyuru modu',
                      onPressed: () => setState(() => _announcement = !_announcement),
                      icon: Icon(Icons.campaign_rounded, color: _announcement ? const Color(0xFFFBBF24) : Colors.white54),
                    ),
                  Expanded(child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 500,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: 'Kanala mesaj yaz...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF0E1929),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                    onSubmitted: (_) => _send(isOwner: isOwner),
                  )),
                  const SizedBox(width: 7),
                  IconButton.filled(
                    onPressed: _sending ? null : () => _send(isOwner: isOwner),
                    style: IconButton.styleFrom(backgroundColor: const Color(0xFFFBBF24), foregroundColor: const Color(0xFF101827)),
                    icon: _sending
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF101827)))
                      : const Icon(Icons.send_rounded),
                  ),
                ]),
              ]),
            ),
          ]);
        },
      ),
    );
  }
}


class ChannelTournamentScreen extends StatefulWidget {
  final String channelId;
  final String tournamentId;
  final String deviceId;
  const ChannelTournamentScreen({
    super.key,
    required this.channelId,
    required this.tournamentId,
    required this.deviceId,
  });

  @override
  State<ChannelTournamentScreen> createState() => _ChannelTournamentScreenState();
}

class _ChannelTournamentScreenState extends State<ChannelTournamentScreen> {
  final _repo = OnlineRoomRepository();
  bool _busy = false;

  Future<void> _startTournamentMatch(String matchId, Map<String, dynamic> match) async {
    if (_busy || match['player1Uid'] != widget.deviceId ||
        match['player2Uid'] == null || match['roomCode'] != null) return;
    setState(() => _busy = true);
    String? roomCode;
    try {
      final profile = UserProfile.instance;
      final name = profile.hasProfile ? profile.displayName : 'Oyuncu';
      roomCode = await _repo.createRoom(
        widget.deviceId,
        hostDisplayName: name,
        hostWinRate: profile.hasProfile ? profile.onlineWinRate : null,
        hostAvatarIconIndex: profile.hasProfile ? profile.avatarIconIndex : null,
        hostAvatarColorValue: profile.hasProfile ? profile.avatarColor.value : null,
        hostPhotoBase64: profile.hasProfile ? profile.photoBase64 : null,
        inviteToDeviceId: match['player2Uid'] as String,
        tournamentChannelId: widget.channelId,
        tournamentId: widget.tournamentId,
        tournamentMatchId: matchId,
      );
      await _repo.linkTournamentMatchRoom(
        channelId: widget.channelId,
        tournamentId: widget.tournamentId,
        matchId: matchId,
        deviceId: widget.deviceId,
        roomCode: roomCode,
      );
      await _repo.sendInvite(
        toDeviceId: match['player2Uid'] as String,
        fromDeviceId: widget.deviceId,
        roomCode: roomCode,
        fromDisplayName: name,
        fromAvatarIconIndex: profile.hasProfile ? profile.avatarIconIndex : null,
        fromAvatarColorValue: profile.hasProfile ? profile.avatarColor.value : null,
        fromPhotoBase64: profile.hasProfile ? profile.photoBase64 : null,
        fromWinRate: profile.hasProfile ? profile.onlineWinRate : null,
      );
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) =>
        OnlineGameScreen(roomCode: roomCode!, deviceId: widget.deviceId, isHost: true)));
    } catch (e) {
      if (roomCode != null) {
        try { await _repo.leaveRoom(roomCode, widget.deviceId, isHost: true); } catch (_) {}
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Turnuva maçı başlatılamadı: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setWinner(String matchId, Map<String, dynamic> match, {String? forcedWinnerUid}) async {
    final player1 = match['player1Uid'] as String?;
    final player2 = match['player2Uid'] as String?;
    if (player1 == null || player2 == null) return;
    final selected = forcedWinnerUid ?? await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B293D),
        title: const Text('Maç kazananını seç', style: TextStyle(color: Colors.white)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            title: Text(match['player1Name'] as String? ?? 'Oyuncu 1',
              style: const TextStyle(color: Colors.white)),
            leading: const Icon(Icons.person, color: Color(0xFFFBBF24)),
            onTap: () => Navigator.pop(ctx, player1),
          ),
          ListTile(
            title: Text(match['player2Name'] as String? ?? 'Oyuncu 2',
              style: const TextStyle(color: Colors.white)),
            leading: const Icon(Icons.person, color: Color(0xFFFBBF24)),
            onTap: () => Navigator.pop(ctx, player2),
          ),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç'))],
      ),
    );
    if (selected == null) return;
    setState(() => _busy = true);
    try {
      await _repo.recordTournamentMatchWinner(
        channelId: widget.channelId,
        tournamentId: widget.tournamentId,
        matchId: matchId,
        creatorDeviceId: widget.deviceId,
        winnerUid: selected,
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Maç sonucu kaydedilemedi: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tournamentRef = FirebaseFirestore.instance.collection('channels')
        .doc(widget.channelId).collection('tournaments').doc(widget.tournamentId);
    return Scaffold(
      backgroundColor: const Color(0xFF101827),
      appBar: AppBar(
        backgroundColor: const Color(0xFF142238),
        foregroundColor: Colors.white,
        title: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: tournamentRef.snapshots(),
          builder: (context, snapshot) => Text(snapshot.data?.data()?['title'] as String? ?? 'Turnuva'),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: tournamentRef.snapshots(),
        builder: (context, tournamentSnapshot) {
          final tournament = tournamentSnapshot.data?.data() ?? const <String, dynamic>{};
          final isCreator = tournament['creatorDeviceId'] == widget.deviceId;
          final status = tournament['status'] as String? ?? 'in_progress';
          return Column(children: [
            if (status == 'completed')
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _repo.watchChannelMembers(widget.channelId),
                builder: (context, memberSnapshot) {
                  final membersById = {
                    for (final member in memberSnapshot.data?.docs ?? [])
                      member.id: member.data()['displayName'] as String? ?? 'Oyuncu',
                  };
                  final placements = Map<String, dynamic>.from(
                    tournament['placements'] as Map? ?? const {});
                  final podium = placements.entries.toList()
                    ..sort((a, b) => ((a.value['rank'] as num?) ?? 99)
                        .compareTo((b.value['rank'] as num?) ?? 99));
                  return Container(
                    margin: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF473A19),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0x99FBBF24)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Row(children: [
                        Icon(Icons.emoji_events_rounded, color: Color(0xFFFBBF24), size: 26),
                        SizedBox(width: 10),
                        Text('TURNUVA PODYUMU',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: .6)),
                      ]),
                      if (podium.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text('Turnuva tamamlandı · Sıralama eşitlikle sonuçlandı',
                            style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ),
                      for (final entry in podium)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Row(children: [
                            SizedBox(width: 30, child: Text(
                              entry.value['rank'] == 1 ? '🥇' : entry.value['rank'] == 2 ? '🥈' : '🥉',
                              style: const TextStyle(fontSize: 20))),
                            Expanded(child: Text(
                              membersById[entry.key] ?? 'Oyuncu',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                            Text('+${entry.value['stars'] ?? 0} ⭐',
                              style: const TextStyle(color: Color(0xFFFBBF24), fontWeight: FontWeight.w900)),
                          ]),
                        ),
                    ]),
                  );
                },
              ),
            if (status == 'completed')
              Builder(builder: (context) {
                final placements = Map<String, dynamic>.from(tournament['placements'] as Map? ?? const {});
                final myPlacement = placements[widget.deviceId];
                if (myPlacement is! Map) return const SizedBox.shrink();
                final rank = (myPlacement['rank'] as num?)?.toInt() ?? 0;
                final reward = (myPlacement['stars'] as num?)?.toInt() ?? 0;
                final rankLabel = rank == 1 ? '1.' : rank == 2 ? '2.' : '3.';
                return Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF473A19),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0x99FBBF24)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.stars_rounded, color: Color(0xFFFBBF24), size: 25),
                    const SizedBox(width: 10),
                    Expanded(child: Text('$rankLabel sıra · $reward yıldız ödülün hazır',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
                    FilledButton(
                      onPressed: _busy ? null : () async {
                        setState(() => _busy = true);
                        try {
                          await AuthService.instance.syncProgressForCurrentUser();
                          final amount = await _repo.claimTournamentReward(
                            channelId: widget.channelId,
                            tournamentId: widget.tournamentId,
                            deviceId: widget.deviceId,
                          );
                          final credited = Progress.instance.awardTournamentReward(widget.tournamentId, amount);
                          if (credited) {
                            try {
                              await AuthService.instance.syncProgressForCurrentUser();
                            } catch (_) {
                              // Local balance is saved; the next account sync will upload it.
                            }
                          }
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(credited ? '$amount yıldız hesabına eklendi!' : 'Bu turnuva ödülü daha önce hesabına eklendi.')),
                          );
                        } catch (e) {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Ödül alınamadı: $e')),
                          );
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFBBF24), foregroundColor: const Color(0xFF241B08)),
                      child: Text(Progress.instance.claimedTournamentRewards.contains(widget.tournamentId)
                        ? 'ALINDI' : 'ÖDÜLÜ AL'),
                    ),
                  ]),
                );
              }),
            if (isCreator && status == 'in_progress')
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text('Maçları oynattıktan sonra kazananı burada işle. Eleme turnuvasında sonraki tur otomatik oluşturulur.',
                  style: TextStyle(color: Colors.white54, fontSize: 11)),
              ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _repo.watchTournamentMatches(widget.channelId, widget.tournamentId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return Center(child: Text('Eşleşmeler yüklenemedi: ${snapshot.error}',
                    style: const TextStyle(color: Colors.white54)));
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFFFBBF24)));
                  final matches = [...snapshot.data!.docs]
                    ..sort((a, b) {
                      final roundCompare = ((a.data()['round'] as num?) ?? 1).compareTo((b.data()['round'] as num?) ?? 1);
                      if (roundCompare != 0) return roundCompare;
                      return ((a.data()['matchIndex'] as num?) ?? 0).compareTo((b.data()['matchIndex'] as num?) ?? 0);
                    });
                  if (matches.isEmpty) return const Center(child: Text('Henüz eşleşme oluşturulmadı.',
                    style: TextStyle(color: Colors.white54)));
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                    itemCount: matches.length,
                    itemBuilder: (context, index) {
                      final doc = matches[index];
                      final data = doc.data();
                      final round = (data['round'] as num?)?.toInt() ?? 1;
                      final p1 = data['player1Name'] as String? ?? 'Oyuncu 1';
                      final p2 = data['player2Name'] as String? ?? 'Bay';
                      final matchWinner = data['winnerUid'] as String?;
                      final p1Won = matchWinner != null && matchWinner == data['player1Uid'];
                      final p2Won = matchWinner != null && matchWinner == data['player2Uid'];
                      final isBye = data['isBye'] == true;
                      final ready = data['status'] == 'ready';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 9),
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B293D),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: ready ? Colors.white12 : const Color(0x66FBBF24)),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('TUR $round · MAÇ ${data['matchIndex'] ?? index + 1}',
                            style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .7)),
                          const SizedBox(height: 8),
                          _TournamentPlayerRow(name: p1, winner: p1Won, isBye: isBye),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 5),
                            child: Text('VS', style: TextStyle(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.w900)),
                          ),
                          _TournamentPlayerRow(name: p2, winner: p2Won, isBye: false),
                          if (ready && data['roomCode'] == null &&
                              data['player1Uid'] == widget.deviceId && !isBye)
                            Align(alignment: Alignment.centerRight, child: TextButton.icon(
                              onPressed: _busy ? null : () => _startTournamentMatch(doc.id, data),
                              icon: const Icon(Icons.sports_esports_rounded, size: 17),
                              label: const Text('Maçı başlat ve davet et'),
                            )),
                          if (ready && data['roomCode'] is String)
                            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                              stream: _repo.watchRoom(data['roomCode'] as String),
                              builder: (context, roomSnapshot) {
                                final room = roomSnapshot.data?.data();
                                if (room?['roomStatus'] == 'cancelled') {
                                  final canRetry = data['player1Uid'] == widget.deviceId;
                                  return Align(
                                    alignment: Alignment.centerRight,
                                    child: Wrap(
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      spacing: 8,
                                      children: [
                                        const Text('Önceki maç odası iptal edildi',
                                          style: TextStyle(color: Colors.white54, fontSize: 11)),
                                        if (canRetry)
                                          TextButton.icon(
                                            onPressed: _busy ? null : () async {
                                              setState(() => _busy = true);
                                              try {
                                                await _repo.resetCancelledTournamentMatchRoom(
                                                  channelId: widget.channelId,
                                                  tournamentId: widget.tournamentId,
                                                  matchId: doc.id,
                                                  deviceId: widget.deviceId,
                                                  roomCode: data['roomCode'] as String,
                                                );
                                              } catch (e) {
                                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('Yeniden deneme açılamadı: $e')));
                                              } finally {
                                                if (mounted) setState(() => _busy = false);
                                              }
                                            },
                                            icon: const Icon(Icons.refresh_rounded, size: 17),
                                            label: const Text('Yeniden oda aç'),
                                          ),
                                      ],
                                    ),
                                  );
                                }
                                final gameStatus = room?['status'] as String?;
                                String? winnerUid;
                                if (gameStatus == 'player1Wins') {
                                  winnerUid = room?['hostDeviceId'] as String?;
                                } else if (gameStatus == 'player2Wins') {
                                  winnerUid = room?['guestDeviceId'] as String?;
                                }
                                if (winnerUid != null && isCreator) {
                                  return Align(alignment: Alignment.centerRight, child: TextButton.icon(
                                    onPressed: _busy ? null : () => _setWinner(doc.id, data, forcedWinnerUid: winnerUid),
                                    icon: const Icon(Icons.verified_rounded, size: 17),
                                    label: const Text('Gerçek maç sonucunu işle'),
                                  ));
                                }
                                return Align(alignment: Alignment.centerRight, child: Text(
                                  winnerUid != null ? 'Maç bitti · Turnuva yöneticisi sonucu işleyecek'
                                    : 'Oda ${data['roomCode']} · ${roomSnapshot.hasData ? 'Rakip bekleniyor / maç sürüyor' : 'Oda yükleniyor'}',
                                  style: const TextStyle(color: Colors.white54, fontSize: 11)));
                              },
                            ),
                          if (ready && data['roomCode'] == null &&
                              data['player1Uid'] != widget.deviceId && !isCreator)
                            const Align(alignment: Alignment.centerRight, child: Text('İlk oyuncunun maç odasını açması bekleniyor',
                              style: TextStyle(color: Colors.white38, fontSize: 11))),
                          if (ready && isCreator && data['roomCode'] == null &&
                              data['player1Uid'] != widget.deviceId)
                            const Align(alignment: Alignment.centerRight, child: Text('İlk oyuncu maçı başlatabilir',
                              style: TextStyle(color: Colors.white38, fontSize: 11))),
                          if (!ready)
                            Align(alignment: Alignment.centerRight, child: Text(isBye ? 'Bay geçti' : 'Tamamlandı',
                              style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 11, fontWeight: FontWeight.w700))),
                        ]),
                      );
                    },
                  );
                },
              ),
            ),
          ]);
        },
      ),
    );
  }
}

class _TournamentPlayerRow extends StatelessWidget {
  final String name;
  final bool winner;
  final bool isBye;
  const _TournamentPlayerRow({required this.name, required this.winner, required this.isBye});

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(winner ? Icons.emoji_events_rounded : Icons.person_outline_rounded,
      color: winner ? const Color(0xFFFBBF24) : Colors.white54, size: 18),
    const SizedBox(width: 8),
    Expanded(child: Text(name,
      style: TextStyle(color: winner ? const Color(0xFFFBBF24) : Colors.white,
        fontWeight: winner ? FontWeight.w900 : FontWeight.w600))),
    if (isBye) const Text('BYE', style: TextStyle(color: Colors.white38, fontSize: 10)),
    if (winner) const Icon(Icons.check_rounded, color: Color(0xFFFBBF24), size: 17),
  ]);
}

class _TournamentStatPill extends StatelessWidget {
  const _TournamentStatPill({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF25364C),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14,
          fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white60, fontSize: 8,
            fontWeight: FontWeight.w700)),
      ]),
    ),
  );
}

