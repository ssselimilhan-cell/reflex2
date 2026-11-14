import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import '../online/firestore_game_repository.dart';
import '../online/persistent_device_id.dart';
import '../settings/progress.dart';
import '../settings/auth_service.dart';
import '../settings/user_profile.dart';
import '../settings/strings.dart';
import 'online_game_screen.dart';
import 'profile_screen.dart';
import '../widgets/game_ui.dart';

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

  Future<String> _currentPlayerDeviceId() async =>
      UserProfile.instance.deviceId ?? await getPersistentDeviceId();

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
            title: const Text('Yalnızca davetliler katılabilsin', style: TextStyle(color: Colors.white, fontSize: 15)),
            subtitle: const Text('Davet kodu olmayan oyuncular kanala katılamaz.', style: TextStyle(color: Colors.white60, fontSize: 15)),
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
        ownerPlayerDeviceId: await _currentPlayerDeviceId(),
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

  Future<void> _deleteOwnedChannel(String channelId) async {
    if (_deviceId == null || _busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B293D),
        title: const Text('Eski kanalı sil?', style: TextStyle(color: Colors.white)),
        content: const Text('Bu eski kapalı kanal ve ona bağlı üyelik, sohbet ve turnuva verileri kalıcı olarak silinecek.',
          style: TextStyle(color: Colors.white70, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB91C1C)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kalıcı olarak sil'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() { _busy = true; _error = null; });
    try {
      await _repo.deleteChannel(channelId, _deviceId!);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Eski kanal ve bağlı verileri silindi.')),
      );
    } catch (e) {
      if (mounted) setState(() => _error = 'Kanal silinemedi: $e');
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
      final id = await _repo.findChannelByInviteCode(code);
      if (id == null) throw StateError('Davet kodu geçersiz veya kanal kapalı.');
      await _repo.requestChannelJoin(
        channelId: id,
        uid: _deviceId!,
        playerDeviceId: await _currentPlayerDeviceId(),
        displayName: p.hasProfile ? p.displayName! : t('you'),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Katılma talebin kanal kurucusuna gönderildi. Onaylandığında kanala girebilirsin.')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Kanala katılınamadı: ' + e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestJoin(String channelId, String displayName) async {
    if (_deviceId == null || _busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      await _repo.requestChannelJoin(
        channelId: channelId,
        uid: _deviceId!,
        playerDeviceId: await _currentPlayerDeviceId(),
        displayName: displayName,
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Katılma talebin kurucuya gönderildi. Onaylandığında kanala girebilirsin.')),
      );
    } catch (e) {
      if (mounted) setState(() => _error = 'Katılma talebi gönderilemedi: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openChannel(String id, {bool joinIfNeeded = true}) async {
    if (_deviceId == null) return;
    final p = UserProfile.instance;
    final playerDeviceId = await _currentPlayerDeviceId();
    if (joinIfNeeded) {
      final joined = await _repo.joinChannel(
        channelId: id, deviceId: _deviceId!,
        playerDeviceId: playerDeviceId,
        displayName: p.hasProfile ? p.displayName! : t('you'),
      );
      if (!joined) {
        if (mounted) setState(() => _error = 'Bu kanal şu anda kullanılamıyor.');
        return;
      }
    } else {
      await _repo.refreshChannelMemberIdentity(
        channelId: id, deviceId: _deviceId!,
        playerDeviceId: playerDeviceId,
        displayName: p.hasProfile ? p.displayName! : t('you'),
      );
    }
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ChannelDetailScreen(
        channelId: id, deviceId: _deviceId!, playerDeviceId: playerDeviceId),
    ));
  }

  Future<void> _openAccountForChannels() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
    if (!mounted) return;
    setState(() => _deviceId = FirebaseAuth.instance.currentUser?.uid);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFB94E20),
    appBar: AppBar(backgroundColor: const Color(0xFF713116), foregroundColor: Colors.white,
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
          borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0x55FBBF24))),
        child: const Row(children: [
          Icon(Icons.hub_rounded, color: Color(0xFFFBBF24), size: 34), SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Kendi topluluğunu kur', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
            SizedBox(height: 6),
            Text('Kanalın maç odasından bağımsız kalır. Oyuncular katılabilir, ayrılabilir ve kanaldan maç daveti alabilir.',
              style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4)),
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
          final docs = snapshot.data!.docs.where((d) {
            final data = d.data();
            final visible = data['visibility'] == 'public' || data['visibility'] == 'invite_only';
            final open = data['status'] == 'open';
            // Old versions archived closed channels; keep them visible only
            // to their owner so they can permanently remove the stale record.
            final legacyClosedOwned = data['status'] == 'closed' && data['ownerDeviceId'] == _deviceId;
            return visible && (open || legacyClosedOwned);
          }).toList();
          if (docs.isEmpty) return Center(child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
              decoration: BoxDecoration(
                color: const Color(0xFF1B293D),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0x66FBBF24)),
              ),
              child: const Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.groups_rounded, color: Color(0xFFFBBF24), size: 60),
                SizedBox(height: 18),
                Text('TOPLULUĞUNU KUR', textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                SizedBox(height: 10),
                Text('Henüz açık bir oyuncu kanalı yok. Kendi kanalını oluştur, arkadaşlarını topla ve turnuvalar düzenle.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 16, height: 1.45)),
              ]),
            ),
          ));
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100), itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = docs[index]; final data = doc.data();
              return Container(
                decoration: BoxDecoration(color: const Color(0xFF1B293D), borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0x33FBBF24))),
                child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
                  Container(width: 48, height: 48, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x22FBBF24)),
                    child: const Icon(Icons.forum_rounded, color: Color(0xFFFBBF24), size: 25)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(data['name'] as String? ?? 'Kanal', maxLines: 2, softWrap: true, overflow: TextOverflow.visible,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                    if ((data['description'] as String? ?? '').isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(data['description'] as String, maxLines: 3, softWrap: true, overflow: TextOverflow.visible,
                        style: const TextStyle(color: Colors.white70, fontSize: 14)),
                    ],
                    const SizedBox(height: 5),
                    Text('${data['memberCount'] ?? 0} oyuncu  ·  ${data['ownerDisplayName'] ?? 'Topluluk'}',
                      style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 15, fontWeight: FontWeight.w700)),
                  ])),
                  StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: _deviceId == null ? null : _repo.watchChannelMembership(doc.id, _deviceId!),
                    builder: (context, memberSnapshot) {
                      final isMember = memberSnapshot.data?.exists == true;
                      final inviteOnly = data['visibility'] == 'invite_only';
                      if (data['status'] == 'closed' && data['ownerDeviceId'] == _deviceId) {
                        return OutlinedButton.icon(
                          onPressed: _busy ? null : () => _deleteOwnedChannel(doc.id),
                          icon: const Icon(Icons.delete_forever_rounded, size: 18),
                          label: const Text('Sil'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFFF8A80),
                            side: const BorderSide(color: Color(0xFFFF8A80)),
                          ),
                        );
                      }
                      if (!inviteOnly) {
                        return FilledButton(
                          onPressed: _busy || _deviceId == null ? null : () => _openChannel(doc.id, joinIfNeeded: !isMember),
                          style: FilledButton.styleFrom(
                            backgroundColor: isMember ? const Color(0xFF263B55) : const Color(0xFFFBBF24),
                            foregroundColor: isMember ? Colors.white : const Color(0xFF101827)),
                          child: Text(isMember ? 'Aç' : 'Katıl', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)));
                      }
                      if (isMember) return FilledButton(
                        onPressed: () => _openChannel(doc.id, joinIfNeeded: false),
                        child: const Text('Aç'),
                      );
                      return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: _repo.watchMyChannelJoinRequest(doc.id, _deviceId!),
                        builder: (context, requestSnapshot) {
                          final requestStatus = requestSnapshot.data?.data()?['status'] as String?;
                          final pending = requestStatus == 'pending';
                          final alreadyRequested = requestStatus != null;
                          return FilledButton(
                            onPressed: _busy || alreadyRequested ? null : () => _requestJoin(
                              doc.id, UserProfile.instance.hasProfile
                                  ? UserProfile.instance.displayName! : 'Oyuncu',
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: pending ? const Color(0xFF263B55) : const Color(0xFFFBBF24),
                              foregroundColor: pending ? Colors.white : const Color(0xFF101827),
                              disabledBackgroundColor: const Color(0xFF263B55),
                              disabledForegroundColor: Colors.white,
                            ),
                            child: GameUi.fitLabel(
                              pending ? 'Talep gönderildi' : requestStatus == 'rejected'
                                ? 'Talep reddedildi' : alreadyRequested ? 'Talep tamamlandı' : 'Katılma talebi',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900), maxLines: 2,
                            ),
                          );
                        },
                      );
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
  final Set<String> _startingTournamentIds = <String>{};
  final Set<String> _minimumPlayerWarningsShown = <String>{};
  String? _pendingRoomCode;
  String? _pendingInviteId;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _roomSub;

  @override
  void dispose() {
    _roomSub?.cancel();
    super.dispose();
  }

  Future<void> _createTournament() async {
    final title = TextEditingController();
    final maxPlayersController = TextEditingController(text: '16');
    String format = 'swiss';
    final result = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        backgroundColor: const Color(0xFF1B293D),
        title: const Text('Turnuva oluştur', style: TextStyle(color: Colors.white)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: title, maxLength: 40, style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Turnuva adı', labelStyle: TextStyle(color: Colors.white70))),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.leaderboard_rounded, color: Color(0xFFFBBF24)),
            title: Text('İsviçre sistemi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            subtitle: Text('Herkes tüm turlarda puan toplar. Tur sayısı kayıtlı oyuncu sayısına göre otomatik belirlenir.', style: TextStyle(color: Colors.white70)),
          ),
          TextField(
            controller: maxPlayersController,
            keyboardType: TextInputType.number,
            maxLength: 3,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'En fazla katılımcı sayısı',
              helperText: '2–256 arasında istediğin sayıyı belirle.',
              labelStyle: TextStyle(color: Colors.white70),
              helperStyle: TextStyle(color: Colors.white54),
              counterStyle: TextStyle(color: Colors.white54),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: const Color(0xFF25364C),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x66FBBF24)),
            ),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('SIRALAMA ÖDÜLLERİ',
                style: TextStyle(color: Color(0xFFFBBF24), fontSize: 14,
                  fontWeight: FontWeight.w900, letterSpacing: .6)),
              SizedBox(height: 6),
              Text('🥇 1. 100 yıldız   ·   🥈 2. 60 yıldız   ·   🥉 3. 30 yıldız',
                style: TextStyle(color: Colors.white, fontSize: 15,
                  fontWeight: FontWeight.w700)),
            ]),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Oluştur')),
        ],
      ),
    ));
    final cleanTitle = title.text.trim();
    final maxPlayers = int.tryParse(maxPlayersController.text.trim());
    title.dispose();
    maxPlayersController.dispose();
    if (result != true || cleanTitle.length < 2) return;
    if (maxPlayers == null || maxPlayers < 2 || maxPlayers > 256) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Katılımcı sınırı 2 ile 256 arasında olmalı.')),
      );
      return;
    }
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
    if (!_startingTournamentIds.add(id)) return;
    if (mounted) setState(() {});
    try {
      await _repo.startChannelTournament(
        channelId: widget.channelId, tournamentId: id, creatorDeviceId: widget.deviceId,
      );
    } catch (e) {
      final message = e.toString();
      final isMinimumPlayersWarning =
          message.contains('en az 2 oyuncu') ||
          message.contains('en az iki kanal üyesi');
      // A missing-player warning is shown once per tournament while this
      // channel screen remains open, not on every repeated tap.
      final shouldShow = !isMinimumPlayersWarning ||
          _minimumPlayerWarningsShown.add(id);
      if (mounted && shouldShow) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      _startingTournamentIds.remove(id);
      if (mounted) setState(() {});
    }
  }

  Future<void> _deleteChannel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B293D),
        title: const Text('Kanalı sil?', style: TextStyle(color: Colors.white)),
        content: const Text('Kanal; üyeleri, sohbet mesajları, davet kodları ve turnuva kayıtlarıyla birlikte kalıcı olarak silinecek. Bu işlem geri alınamaz.',
          style: TextStyle(color: Colors.white70, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç', style: TextStyle(color: Colors.white70))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB91C1C), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true), child: const Text('Kanalı sil')),
        ],
      ),
    );
    if (confirmed != true || !mounted || _busy) return;
    setState(() => _busy = true);
    try {
      await _repo.deleteChannel(widget.channelId, widget.deviceId);
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kanal ve bağlı tüm verileri silindi.'))); Navigator.pop(context); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kanal silinemedi: $e')));
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _leave() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1B293D),
        title: const Text('Kanaldan ayrıl?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Bu kanaldaki üyeliğin sona erecek. Kanal sahibiysen sahiplik başka bir üyeye devredilir; son üye sensen kanal kapatılır.',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB45309),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Evet, ayrıl'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _busy) return;
    setState(() => _busy = true);
    try {
      await _repo.leaveChannel(widget.channelId, widget.deviceId);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kanaldan ayrılamadın: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _acceptTournamentInvite(
    String inviteId,
    Map<String, dynamic> invite,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final code = invite['roomCode'] as String?;
      if (code == null || code.isEmpty) {
        throw StateError('Davetin maç odası bulunamadı.');
      }
      final roomSnap = await _repo.getRoomFromServer(code);
      final room = roomSnap.data();
      if (!roomSnap.exists || room == null ||
          room['tournamentChannelId'] != widget.channelId ||
          room['tournamentId'] != invite['tournamentId'] ||
          room['tournamentMatchId'] != invite['tournamentMatchId'] ||
          room['inviteToDeviceId'] != widget.playerDeviceId) {
        throw StateError('Bu turnuva daveti artık geçerli değil.');
      }
      final seatedGuest = room['guestDeviceId'] as String?;
      if (seatedGuest == null) {
        final profile = UserProfile.instance;
        final joined = await _repo.joinRoom(
          code,
          widget.playerDeviceId,
          guestDisplayName: profile.hasProfile ? profile.displayName : 'Oyuncu',
          guestWinRate: profile.hasProfile ? profile.onlineWinRate : null,
          guestAvatarIconIndex: profile.hasProfile ? profile.avatarIconIndex : null,
          guestAvatarColorValue: profile.hasProfile ? profile.avatarColor.value : null,
          guestPhotoBase64: profile.hasProfile ? profile.photoBase64 : null,
        );
        if (!joined) {
          final latest = await _repo.getRoomFromServer(code);
          if (latest.data()?['guestDeviceId'] != widget.playerDeviceId) {
            throw StateError('Maç odasına katılınamadı. Davet süresi dolmuş veya rakip başka bir oyuncuyla eşleşmiş olabilir.');
          }
        }
      } else if (seatedGuest != widget.playerDeviceId) {
        throw StateError('Bu maç odasına başka bir cihaz katılmış.');
      }
      await _repo.closeInvite(inviteId);
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) =>
        OnlineGameScreen(
          roomCode: code,
          deviceId: widget.playerDeviceId,
          isHost: false,
          isTournamentMatch: true,
        )));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Turnuva daveti kabul edilemedi: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelMatchInvite() async {
    final code = _pendingRoomCode;
    if (code == null || _busy) return;
    setState(() => _busy = true);
    try {
      if (_pendingInviteId != null) await _repo.closeInvite(_pendingInviteId!);
      await _repo.leaveRoom(code, widget.playerDeviceId, isHost: true);
      await _roomSub?.cancel();
      if (mounted) setState(() { _pendingRoomCode = null; _pendingInviteId = null; _openingMatch = false; });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gönderilen davet geri alındı.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Davet geri alınamadı: $e')));
    } finally { if (mounted) setState(() => _busy = false); }
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
      final inviteId = await _repo.sendInvite(
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
      setState(() { _pendingRoomCode = code; _pendingInviteId = inviteId; });
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
                  _pendingInviteId = null;
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
      backgroundColor: const Color(0xFFB94E20),
      appBar: AppBar(backgroundColor: const Color(0xFF713116), foregroundColor: Colors.white,
        title: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('channels').doc(widget.channelId).snapshots(),
          builder: (context, snapshot) => Text(snapshot.data?.data()?['name'] as String? ?? 'Kanal'),
        ),
        actions: [
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('channels').doc(widget.channelId).snapshots(),
            builder: (context, snapshot) => snapshot.data?.data()?['ownerDeviceId'] == widget.deviceId
              ? IconButton(tooltip: 'Kanalı sil', icon: const Icon(Icons.delete_forever_rounded, color: Color(0xFFFFD76A)),
                  onPressed: _busy ? null : _deleteChannel)
              : const SizedBox.shrink(),
          ),
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
              if (data?['visibility'] != 'invite_only') {
                return const SizedBox.shrink();
              }
              return FutureBuilder<String?>(
                future: _repo.getChannelInviteCode(widget.channelId, widget.deviceId),
                builder: (context, codeSnapshot) {
                  final code = codeSnapshot.data;
                  return IconButton(
                    tooltip: 'Davet kodunu kopyala',
                    onPressed: code == null ? null : () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Davet kodu kopyalandı.')));
                    },
                    icon: const Icon(Icons.key_rounded, color: Color(0xFFFBBF24)),
                  );
                },
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
                      style: TextStyle(color: Colors.white60, fontSize: 14)),
                  ],
                )),
              ]),
            ),
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: channel.snapshots(),
              builder: (context, ownerSnapshot) {
                if (ownerSnapshot.data?.data()?['ownerDeviceId'] != widget.deviceId) return const SizedBox.shrink();
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _repo.watchChannelJoinRequests(widget.channelId),
                  builder: (context, requestSnapshot) {
                    final requests = (requestSnapshot.data?.docs ?? const [])
                        .where((request) => request.data()['status'] == 'pending').toList();
                    if (requests.isEmpty) return const SizedBox.shrink();
                    return Container(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF302719),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0x88FBBF24)),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('KATILMA TALEPLERİ (${requests.length})',
                          style: const TextStyle(color: Color(0xFFFBBF24), fontWeight: FontWeight.w900)),
                        const SizedBox(height: 6),
                        ...requests.map((request) => Row(children: [
                          Expanded(child: Text(request.data()['displayName'] as String? ?? 'Oyuncu',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                          IconButton(
                            tooltip: 'Reddet',
                            onPressed: _busy ? null : () => _repo.respondToChannelJoinRequest(
                              channelId: widget.channelId, requesterUid: request.id, accept: false),
                            icon: const Icon(Icons.close_rounded, color: Colors.redAccent),
                          ),
                          IconButton(
                            tooltip: 'Kabul et',
                            onPressed: _busy ? null : () async {
                              try {
                                await _repo.respondToChannelJoinRequest(
                                  channelId: widget.channelId, requesterUid: request.id, accept: true);
                              } catch (e) {
                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Talep kabul edilemedi: $e')));
                              }
                            },
                            icon: const Icon(Icons.check_circle_rounded, color: Color(0xFF34D399)),
                          ),
                        ])),
                      ]),
                    );
                  },
                );
              },
            ),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _repo.watchIncomingInvites(widget.playerDeviceId),
              builder: (context, inviteSnapshot) {
                final invites = (inviteSnapshot.data?.docs ?? const [])
                    .where((doc) {
                      final data = doc.data();
                      return data['inviteType'] == 'tournament' &&
                          data['tournamentChannelId'] == widget.channelId;
                    }).toList();
                if (invites.isEmpty) return const SizedBox.shrink();
                return Container(
                  margin: const EdgeInsets.fromLTRB(16, 2, 16, 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF263B55),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0x99FBBF24)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(Icons.mark_email_unread_rounded,
                        color: Color(0xFFFFD76A), size: 21),
                      const SizedBox(width: 8),
                      Expanded(child: Text('TURNUVA MAÇ DAVETLERİ · ${invites.length}',
                        style: const TextStyle(color: Color(0xFFFFD76A),
                          fontSize: 14, fontWeight: FontWeight.w900))),
                    ]),
                    const SizedBox(height: 8),
                    ...invites.map((inviteDoc) {
                      final invite = inviteDoc.data();
                      final sender = invite['fromDisplayName'] as String? ?? 'Rakibin';
                      return Container(
                        margin: const EdgeInsets.only(top: 7),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF17263A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(sender, style: const TextStyle(
                            color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 3),
                          const Text('Turnuva rakibin seni maç odasına çağırıyor. Katıldıktan sonra oyunun başlaması için ayrıca onay vereceksiniz.',
                            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.35)),
                          const SizedBox(height: 8),
                          Row(children: [
                            Expanded(child: FilledButton.icon(
                              onPressed: _busy ? null : () => _acceptTournamentInvite(
                                inviteDoc.id, invite),
                              icon: const Icon(Icons.meeting_room_rounded, size: 18),
                              label: GameUi.fitLabel('DAVETİ KABUL ET', maxLines: 2),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFFBBF24),
                                foregroundColor: const Color(0xFF101827),
                                padding: const EdgeInsets.symmetric(vertical: 11)),
                            )),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: _busy ? null : () => _repo.closeInvite(inviteDoc.id),
                              child: const Text('Reddet', style: TextStyle(color: Colors.white70)),
                            ),
                          ]),
                        ]),
                      );
                    }),
                  ]),
                );
              },
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
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1))),
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
                        style: TextStyle(color: Colors.white54, fontSize: 15))
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
                                style: const TextStyle(color: Colors.white60, fontSize: 15)),
                              const Text('Ödül: 100 / 60 / 30 ⭐',
                                style: TextStyle(color: Color(0xFFFBBF24),
                                  fontSize: 14, fontWeight: FontWeight.w800)),
                            ])),
                            if (status == 'registration' && !isParticipant)
                              TextButton(onPressed: () => _joinTournament(doc.id), child: const Text('Katıl')),
                            if (status == 'registration' && isCreator)
                              IconButton(
                                onPressed: _startingTournamentIds.contains(doc.id)
                                    ? null : () => _startTournament(doc.id),
                                tooltip: 'Turnuvayı başlat',
                                icon: _startingTournamentIds.contains(doc.id)
                                    ? const SizedBox(
                                        width: 20, height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFFFBBF24),
                                        ),
                                      )
                                    : const Icon(Icons.play_arrow_rounded, color: Color(0xFFFBBF24)),
                              ),
                            if (status == 'in_progress' || status == 'completed')
                              TextButton(
                                onPressed: () => Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => ChannelTournamentScreen(
                                    channelId: widget.channelId,
                                    tournamentId: doc.id,
                                    deviceId: widget.deviceId,
                                    playerDeviceId: widget.playerDeviceId,
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
                    final starsCompare = ((bData['starsEarned'] as num?) ?? 0)
                        .compareTo((aData['starsEarned'] as num?) ?? 0);
                    if (starsCompare != 0) return starsCompare;
                    return ((bData['secondPlaces'] as num?) ?? 0)
                        .compareTo((aData['secondPlaces'] as num?) ?? 0);
                  });
                bool sameStanding(Map<String, dynamic> a, Map<String, dynamic> b) =>
                    (a['championships'] ?? 0) == (b['championships'] ?? 0) &&
                    (a['podiums'] ?? 0) == (b['podiums'] ?? 0) &&
                    (a['starsEarned'] ?? 0) == (b['starsEarned'] ?? 0) &&
                    (a['secondPlaces'] ?? 0) == (b['secondPlaces'] ?? 0);
                final ranks = <String, int>{};
                var lastRank = 0;
                for (var index = 0; index < stats.length; index++) {
                  final data = stats[index].data();
                  if (index == 0 || !sameStanding(data, stats[index - 1].data())) {
                    lastRank = index + 1;
                  }
                  ranks[stats[index].id] = lastRank;
                }
                Map<String, dynamic>? myStats;
                for (final item in stats) {
                  if (item.id == widget.deviceId) {
                    myStats = item.data();
                    break;
                  }
                }
                final myRank = ranks[widget.deviceId];
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
                        style: TextStyle(color: Color(0xFFFBBF24), fontSize: 14,
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
                      if (myRank != null) ...[
                        const SizedBox(height: 8),
                        Row(children: [
                          const Icon(Icons.military_tech_rounded,
                            color: Color(0xFFFBBF24), size: 16),
                          const SizedBox(width: 6),
                          Text('Kanal sıralamasında $myRank. sıradasın',
                            style: const TextStyle(color: Color(0xFFFFE7A3),
                              fontSize: 15, fontWeight: FontWeight.w800)),
                        ]),
                      ],
                      const SizedBox(height: 12),
                    ],
                    const Row(children: [
                      Icon(Icons.leaderboard_rounded, color: Color(0xFFFBBF24), size: 19),
                      SizedBox(width: 8),
                      Text('KANALIN TURNUVA SIRALAMASI',
                        style: TextStyle(color: Colors.white, fontSize: 15,
                          fontWeight: FontWeight.w900, letterSpacing: .5)),
                    ]),
                    const SizedBox(height: 8),
                    for (var i = 0; i < stats.length && i < 5; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(children: [
                          SizedBox(width: 24, child: Text(
                            '${ranks[stats[i].id] ?? i + 1}.',
                            style: TextStyle(
                              color: (ranks[stats[i].id] ?? i + 1) == 1
                                  ? const Color(0xFFFBBF24) : Colors.white60,
                              fontWeight: FontWeight.w900),
                          )),
                          Expanded(child: Text(
                            memberNames[stats[i].id] ?? 'Oyuncu',
                            maxLines: 2, softWrap: true, overflow: TextOverflow.visible,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                          Flexible(child: Text('${stats[i].data()['championships'] ?? 0} şamp.  ·  '
                            '${stats[i].data()['podiums'] ?? 0} podyum',
                            maxLines: 2, softWrap: true, textAlign: TextAlign.end,
                            style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.15))),
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
                child: Row(children: [
                  const SizedBox(width: 8, height: 8, child: DecoratedBox(
                    decoration: BoxDecoration(color: Color(0xFF34D399), shape: BoxShape.circle))),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('Davet bekleniyor · Kanalın açık kalıyor',
                    style: TextStyle(color: Color(0xFFB7F7D5), fontSize: 14, fontWeight: FontWeight.w700))),
                  TextButton.icon(onPressed: _busy ? null : _cancelMatchInvite,
                    icon: const Icon(Icons.undo_rounded, size: 17), label: const Text('Geri al'),
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFFFFD0C2),
                      disabledForegroundColor: const Color(0xFFB6A39C))),
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
                      style: const TextStyle(color: Colors.white54, fontSize: 15)),
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
                          child: GameUi.fitLabel('Davet et', style: const TextStyle(fontWeight: FontWeight.w800)),
                        ),
                  ),
                );
              })),
            SafeArea(top: false, child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: SizedBox(width: double.infinity, child: OutlinedButton.icon(
                onPressed: _busy ? null : _leave, icon: const Icon(Icons.logout_rounded),
                label: GameUi.fitLabel('Kanaldan ayrıl'),
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
      backgroundColor: const Color(0xFFB94E20),
      appBar: AppBar(
        backgroundColor: const Color(0xFF713116),
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
                                  Text('KANAL DUYURUSU', style: TextStyle(color: Color(0xFFFBBF24), fontSize: 14, fontWeight: FontWeight.w900)),
                                ]),
                              ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                mine ? 'Sen · ${data['senderName'] as String? ?? 'Oyuncu'}'
                                    : (data['senderName'] as String? ?? 'Oyuncu'),
                                style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 15, fontWeight: FontWeight.w800),
                              ),
                            ),
                            Text(data['text'] as String? ?? '', style: const TextStyle(color: Colors.white, height: 1.35)),
                            if (time != null)
                              Align(alignment: Alignment.bottomRight, child: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text('${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
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
                    child: Text('Duyuru olarak gönderilecek', style: TextStyle(color: Color(0xFFFBBF24), fontSize: 15, fontWeight: FontWeight.w700)),
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
  final String playerDeviceId;
  const ChannelTournamentScreen({
    super.key,
    required this.channelId,
    required this.tournamentId,
    required this.deviceId,
    required this.playerDeviceId,
  });

  @override
  State<ChannelTournamentScreen> createState() => _ChannelTournamentScreenState();
}

class _ChannelTournamentScreenState extends State<ChannelTournamentScreen> {
  final _repo = OnlineRoomRepository();
  bool _busy = false;
  bool _isCreator = false;
  Timer? _reconcileTimer;
  final Set<String> _openingMatches = <String>{};
  final Set<String> _joiningMatches = <String>{};
  final Set<String> _joinedMatches = <String>{};

  @override
  void initState() {
    super.initState();
    _reconcileTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_isCreator) _repo.reconcileSwissTournament(
        channelId: widget.channelId, tournamentId: widget.tournamentId,
        creatorDeviceId: widget.deviceId,
      ).catchError((_) {});
    });
  }

  @override
  void dispose() { _reconcileTimer?.cancel(); super.dispose(); }

  Future<void> _startTournamentMatch(String matchId, Map<String, dynamic> match) async {
    if (_busy || match['player1Uid'] != widget.deviceId ||
        match['player2Uid'] == null || match['roomCode'] != null) return;
    setState(() => _busy = true);
    String? roomCode;
    try {
      final profile = UserProfile.instance;
      final name = profile.hasProfile ? profile.displayName : 'Oyuncu';
      final opponentUid = match['player2Uid'] as String?;
      if (opponentUid == null || opponentUid.isEmpty) {
        throw StateError('Bu eşleşmede rakip oyuncu kaydı bulunamadı.');
      }
      // Bracket kayıtları turnuva başladığı anda oluşturulur ve cihaz kimliği
      // sonradan değişmiş olabilir. Eski turnuvalarda da davetin doğru telefona
      // gitmesi için her davette güncel kanal üyeliğini esas al.
      final opponent = await FirebaseFirestore.instance.collection('channels')
          .doc(widget.channelId).collection('members')
          .doc(opponentUid).get();
      final opponentDeviceId = opponent.data()?['playerDeviceId'] as String?;
      if (opponentDeviceId == null || opponentDeviceId.trim().isEmpty) {
        throw StateError('Rakibin cihaz kimliği bulunamadı. Rakip kanalı yeni sürümde açıp tekrar denemeli.');
      }
      if (opponentDeviceId == UserProfile.instance.deviceId) {
        throw StateError('Rakibin cihaz kimliği seninkiyle aynı görünüyor. Rakip kanalı kendi telefonunda yeniden açmalı.');
      }
      roomCode = await _repo.createRoom(
        widget.playerDeviceId,
        hostDisplayName: name,
        hostWinRate: profile.hasProfile ? profile.onlineWinRate : null,
        hostAvatarIconIndex: profile.hasProfile ? profile.avatarIconIndex : null,
        hostAvatarColorValue: profile.hasProfile ? profile.avatarColor.value : null,
        hostPhotoBase64: profile.hasProfile ? profile.photoBase64 : null,
        inviteToDeviceId: opponentDeviceId,
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
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) =>
        OnlineGameScreen(
          roomCode: roomCode!,
          deviceId: widget.playerDeviceId,
          isHost: true,
          isTournamentMatch: true,
        )));
    } catch (e) {
      if (roomCode != null) {
        try { await _repo.leaveRoom(roomCode, widget.playerDeviceId, isHost: true); } catch (_) {}
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Turnuva maçı başlatılamadı: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }


  Future<void> _joinTournamentMatch(String matchId, String roomCode) async {
    if (!_joiningMatches.add(matchId)) return;
    try {
      final profile = UserProfile.instance;
      final joined = await _repo.joinRoom(roomCode, widget.playerDeviceId,
        guestDisplayName: profile.hasProfile ? profile.displayName : 'Oyuncu',
        guestWinRate: profile.hasProfile ? profile.onlineWinRate : null,
        guestAvatarIconIndex: profile.hasProfile ? profile.avatarIconIndex : null,
        guestAvatarColorValue: profile.hasProfile ? profile.avatarColor.value : null,
        guestPhotoBase64: profile.hasProfile ? profile.photoBase64 : null,
      );
      final snap = await _repo.getRoomFromServer(roomCode);
      if (!mounted || !snap.exists) return;
      if (!joined && snap.data()?['guestDeviceId'] != widget.playerDeviceId) return;
      _joinedMatches.add(matchId);
      await Navigator.push(context, MaterialPageRoute(builder: (_) => OnlineGameScreen(
        roomCode: roomCode, deviceId: widget.playerDeviceId, isHost: false, isTournamentMatch: true,
      )));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Turnuva maçına katılınamadı: $e')));
    } finally {
      _joiningMatches.remove(matchId);
    }
  }


  @override
  Widget build(BuildContext context) {
    final tournamentRef = FirebaseFirestore.instance.collection('channels')
        .doc(widget.channelId).collection('tournaments').doc(widget.tournamentId);
    return Scaffold(
      backgroundColor: const Color(0xFFB94E20),
      appBar: AppBar(
        backgroundColor: const Color(0xFF713116),
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
          _isCreator = isCreator;
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
                            style: TextStyle(color: Colors.white70, fontSize: 14)),
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
                child: Text('Sonuçlar otomatik işlenir; tur eşleşmeleri puanlara göre yenilenir.',
                  style: TextStyle(color: Colors.white54, fontSize: 15)),
              ),
            if (status == 'in_progress' && tournament['scoresHalf'] is Map)
              Builder(builder: (context) {
                final scores = Map<String, dynamic>.from(tournament['scoresHalf'] as Map);
                final opponents = Map<String, dynamic>.from(tournament['opponents'] as Map? ?? const {});
                final info = Map<String, dynamic>.from(tournament['playerInfo'] as Map? ?? const {});
                int buchholz(String id) {
                  final list = List<String>.from(opponents[id] as List? ?? const []);
                  return list.fold<int>(0, (sum, other) => sum + ((scores[other] as num?)?.toInt() ?? 0));
                }
                final ids = scores.keys.toList()..sort((a, b) {
                  final points = ((scores[b] as num?)?.toInt() ?? 0).compareTo((scores[a] as num?)?.toInt() ?? 0);
                  if (points != 0) return points;
                  final tie = buchholz(b).compareTo(buchholz(a));
                  return tie != 0 ? tie : a.compareTo(b);
                });
                return Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B293D),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0x66FBBF24)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('PUAN DURUMU', style: TextStyle(color: Color(0xFFFBBF24), fontWeight: FontWeight.w900, letterSpacing: .7)),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 150,
                      child: ListView.builder(
                        itemCount: ids.length,
                        itemBuilder: (context, index) {
                          final id = ids[index];
                          final half = (scores[id] as num?)?.toInt() ?? 0;
                          final points = (half ~/ 2).toString() + (half.isOdd ? '½' : '');
                          final player = info[id] is Map ? Map<String, dynamic>.from(info[id] as Map) : const <String, dynamic>{};
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(children: [
                              SizedBox(width: 28, child: Text('${index + 1}.', style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.w800))),
                              Expanded(child: Text(player['name'] as String? ?? 'Oyuncu', maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                              SizedBox(width: 58, child: Text('$points p.', textAlign: TextAlign.end,
                                style: const TextStyle(color: Color(0xFFFBBF24), fontWeight: FontWeight.w900))),
                              SizedBox(width: 74, child: Text('BH ${(buchholz(id) / 2).toStringAsFixed(1)}',
                                textAlign: TextAlign.end, style: const TextStyle(color: Colors.white60, fontSize: 12))),
                            ]),
                          );
                        },
                      ),
                    ),
                  ]),
                );
              }),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _repo.watchTournamentMatches(widget.channelId, widget.tournamentId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return Center(child: Text('Eşleşmeler yüklenemedi: ${snapshot.error}',
                    style: const TextStyle(color: Colors.white54)));
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFFFBBF24)));
                  if (isCreator) _repo.reconcileSwissTournament(
                    channelId: widget.channelId, tournamentId: widget.tournamentId,
                    creatorDeviceId: widget.deviceId,
                  ).catchError((_) {});
                  final matches = [...snapshot.data!.docs]
                    ..sort((a, b) {
                      final roundCompare = ((a.data()['round'] as num?) ?? 1).compareTo((b.data()['round'] as num?) ?? 1);
                      if (roundCompare != 0) return roundCompare;
                      return ((a.data()['matchIndex'] as num?) ?? 0).compareTo((b.data()['matchIndex'] as num?) ?? 0);
                    });
                  for (final matchDoc in matches) {
                    final matchData = matchDoc.data();
                    if (matchData['status'] == 'ready' &&
                        matchData['roomCode'] == null &&
                        matchData['player1Uid'] == widget.deviceId &&
                        matchData['isBye'] != true &&
                        _openingMatches.add(matchDoc.id)) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        _startTournamentMatch(matchDoc.id, matchData).whenComplete(
                          () => _openingMatches.remove(matchDoc.id));
                      });
                    }
                  }
                  if (matches.isEmpty) return Center(child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(26),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B293D),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0x66FBBF24)),
                      ),
                      child: const Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.emoji_events_rounded, color: Color(0xFFFBBF24), size: 58),
                        SizedBox(height: 18),
                        Text('TURNUVA EŞLEŞMELERİ HAZIRLANIYOR', textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                        SizedBox(height: 10),
                        Text('Oyuncular kayıt olduktan sonra turnuva yöneticisi turnuvayı başlatır. Eşleşmeler bu alanda büyük ve kolay okunur şekilde görünür.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, fontSize: 17, height: 1.45)),
                      ]),
                    ),
                  ));
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
                            style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: .7)),
                          const SizedBox(height: 8),
                          _TournamentPlayerRow(name: p1, winner: p1Won, isBye: isBye),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 5),
                            child: Text('VS', style: TextStyle(color: Colors.white30, fontSize: 14, fontWeight: FontWeight.w900)),
                          ),
                          _TournamentPlayerRow(name: p2, winner: p2Won, isBye: false),
                          if (ready && data['roomCode'] == null &&
                              data['player1Uid'] == widget.deviceId && !isBye)
                            const Align(alignment: Alignment.centerRight,
                              child: Text('Maç odası otomatik hazırlanıyor…',
                                style: TextStyle(color: Colors.white54, fontSize: 14))),
                          if (ready && data['roomCode'] is String)
                            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                              stream: _repo.watchRoom(data['roomCode'] as String),
                              builder: (context, roomSnapshot) {
                                final room = roomSnapshot.data?.data();
                                if (roomSnapshot.hasData &&
                                    (!roomSnapshot.data!.exists || room?['roomStatus'] == 'cancelled')) {
                                  final canRetry = data['player1Uid'] == widget.deviceId;
                                  return Align(
                                    alignment: Alignment.centerRight,
                                    child: Wrap(
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      spacing: 8,
                                      children: [
                                        const Text('Önceki maç odası iptal edildi',
                                          style: TextStyle(color: Colors.white54, fontSize: 15)),
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
                                  winnerUid = data['player1Uid'] as String?;
                                } else if (gameStatus == 'player2Wins') {
                                  // Tournament winner IDs are Firebase Auth UIDs;
                                  // guestDeviceId is only the persistent device key.
                                  winnerUid = data['player2Uid'] as String?;
                                }
                                if (winnerUid != null && isCreator) {
                                  return Align(alignment: Alignment.centerRight, child: TextButton.icon(
                                    onPressed: null,
                                    icon: const Icon(Icons.verified_rounded, size: 17),
                                    label: const Text('Gerçek maç sonucunu işle'),
                                  ));
                                }
                                final isPlayer1 = data['player1Uid'] == widget.deviceId;
                                final isPlayer2 = data['player2Uid'] == widget.deviceId;
                                if (isPlayer2 && room != null &&
                                    !_joinedMatches.contains(doc.id) &&
                                    !_joiningMatches.contains(doc.id) &&
                                    ((room['roomStatus'] == 'waiting' && room['guestDeviceId'] == null) ||
                                     (room['roomStatus'] == 'active' && room['guestDeviceId'] == widget.playerDeviceId))) {
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    if (mounted) _joinTournamentMatch(doc.id, data['roomCode'] as String);
                                  });
                                }
                                final canReturnToRoom = winnerUid == null &&
                                    ((isPlayer1 && room?['hostDeviceId'] == widget.playerDeviceId) ||
                                     (isPlayer2 && room?['guestDeviceId'] == widget.playerDeviceId));
                                if (canReturnToRoom) {
                                  final myRoomDeviceId = isPlayer1
                                      ? room!['hostDeviceId'] as String
                                      : room!['guestDeviceId'] as String;
                                  return Align(
                                    alignment: Alignment.centerRight,
                                    child: Wrap(
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      spacing: 8,
                                      children: [
                                        Text(
                                          room['guestDeviceId'] != null
                                              ? 'RAKİP MASADA · Oda ${data['roomCode']}'
                                              : 'RAKİP BEKLENİYOR · Oda ${data['roomCode']}',
                                          style: const TextStyle(color: Color(0xFFFFE7A3),
                                            fontSize: 14, fontWeight: FontWeight.w800)),
                                        FilledButton.icon(
                                          onPressed: () => Navigator.push(context, MaterialPageRoute(
                                            builder: (_) => OnlineGameScreen(
                                              roomCode: data['roomCode'] as String,
                                              deviceId: myRoomDeviceId,
                                              isHost: isPlayer1,
                                              isTournamentMatch: true,
                                            ))),
                                          icon: const Icon(Icons.sports_esports_rounded, size: 17),
                                          label: const Text('MAÇA DÖN'),
                                          style: FilledButton.styleFrom(
                                            backgroundColor: const Color(0xFFFBBF24),
                                            foregroundColor: const Color(0xFF101827)),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                return Align(alignment: Alignment.centerRight, child: Text(
                                  winnerUid != null ? 'Maç tamamlandı · Sonuç otomatik işleniyor'
                                    : '${room?['guestDeviceId'] != null ? 'RAKİP MASADA · ' : 'RAKİP BEKLENİYOR · '}Oda ${data['roomCode']}',
                                  style: const TextStyle(color: Color(0xFFFFE7A3), fontSize: 16, fontWeight: FontWeight.w800)));
                              },
                            ),
                          if (ready && data['roomCode'] == null &&
                              data['player1Uid'] != widget.deviceId && !isCreator)
                            const Align(alignment: Alignment.centerRight, child: Text('İlk oyuncunun maç odasını açması bekleniyor',
                              style: TextStyle(color: Colors.white38, fontSize: 15))),
                          if (ready && isCreator && data['roomCode'] == null &&
                              data['player1Uid'] != widget.deviceId)
                            const Align(alignment: Alignment.centerRight, child: Text('İlk oyuncu maçı başlatabilir',
                              style: TextStyle(color: Colors.white38, fontSize: 15))),
                          if (!ready)
                            Align(alignment: Alignment.centerRight, child: Text(isBye ? 'Bay geçti' : 'Tamamlandı',
                              style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 15, fontWeight: FontWeight.w700))),
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
        fontWeight: winner ? FontWeight.w900 : FontWeight.w700,
        fontSize: 18))),
    if (isBye) const Text('BAY GEÇTİ', style: TextStyle(color: Colors.white60, fontSize: 14, fontWeight: FontWeight.w800)),
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
        Text(label, maxLines: 2, softWrap: true, overflow: TextOverflow.visible,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 12,
            fontWeight: FontWeight.w800)),
      ]),
    ),
  );
}

