import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../online/firestore_game_repository.dart';
import '../online/persistent_device_id.dart';
import '../settings/user_profile.dart';
import '../settings/strings.dart';
import 'online_game_screen.dart';

class ChannelsScreen extends StatefulWidget {
  const ChannelsScreen({super.key});
  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> {
  final _repo = OnlineRoomRepository();
  String? _deviceId;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    (UserProfile.instance.deviceId == null
            ? getPersistentDeviceId()
            : Future.value(UserProfile.instance.deviceId))
        .then((id) { if (mounted) setState(() => _deviceId = id); });
  }

  Future<void> _createChannel() async {
    final name = TextEditingController();
    final description = TextEditingController();
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
        ownerDisplayName: p.hasProfile ? p.displayName! : t('you'),
        name: cleanName,
        description: cleanDescription,
      );
      if (mounted) await _openChannel(id, joinIfNeeded: false);
    } catch (e) {
      if (mounted) setState(() => _error = 'Kanal oluşturulamadı: $e');
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
        displayName: p.hasProfile ? p.displayName! : t('you'),
      );
      if (!joined) {
        if (mounted) setState(() => _error = 'Bu kanal şu anda kullanılamıyor.');
        return;
      }
    }
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ChannelDetailScreen(channelId: id, deviceId: _deviceId!),
    ));
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
    body: SafeArea(child: Column(children: [
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
      if (_error != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        child: Text(_error!, style: const TextStyle(color: Colors.redAccent))),
      Expanded(child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _repo.watchChannels(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Kanallar yüklenemedi: ${snapshot.error}', style: const TextStyle(color: Colors.white70)));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFFFBBF24)));
          final docs = snapshot.data!.docs;
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
  const ChannelDetailScreen({super.key, required this.channelId, required this.deviceId});
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

  Future<void> _leave() async {
    await _repo.leaveChannel(widget.channelId, widget.deviceId);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _startMatch(String targetDeviceId) async {
    if (_busy || targetDeviceId == widget.deviceId || _pendingRoomCode != null) return;
    setState(() => _busy = true);
    try {
      final p = UserProfile.instance;
      final displayName = p.hasProfile ? p.displayName : t('you');
      final code = await _repo.createRoom(
        widget.deviceId,
        hostDisplayName: displayName,
        hostWinRate: p.hasProfile ? p.onlineWinRate : null,
        hostAvatarIconIndex: p.hasProfile ? p.avatarIconIndex : null,
        hostAvatarColorValue: p.hasProfile ? p.avatarColor.value : null,
        hostPhotoBase64: p.hasProfile ? p.photoBase64 : null,
      );
      await _repo.sendInvite(
        toDeviceId: targetDeviceId,
        fromDeviceId: widget.deviceId,
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
            OnlineGameScreen(roomCode: code, deviceId: widget.deviceId, isHost: true)));
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
        title: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(stream: channel.snapshots(),
          builder: (context, snapshot) => Text(snapshot.data?.data()?['name'] as String? ?? 'Kanal'))),
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
                            ? null : () => _startMatch(member.id),
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
