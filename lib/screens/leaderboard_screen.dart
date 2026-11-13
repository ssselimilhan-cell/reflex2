import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../online/firestore_game_repository.dart';
import '../settings/app_settings.dart';
import '../settings/strings.dart';
import '../settings/user_profile.dart';
import '../widgets/profile_avatar.dart';

enum _Period { daily, weekly, monthly, yearly }

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _repo = OnlineRoomRepository();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  DateTime _periodStart(_Period p) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    switch (p) {
      case _Period.daily:
        return startOfToday;
      case _Period.weekly:
        // Pazartesi başlangıcı (ISO hafta).
        return startOfToday.subtract(Duration(days: now.weekday - 1));
      case _Period.monthly:
        return DateTime(now.year, now.month, 1);
      case _Period.yearly:
        return DateTime(now.year, 1, 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppSettings.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFB94E20),
          appBar: AppBar(
            title: Text(t('leaderboard_title')),
            bottom: TabBar(
              controller: _tabController,
              isScrollable: false,
              labelColor: Colors.amber,
              unselectedLabelColor: Colors.white,
              indicatorColor: Colors.amber,
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                  fontWeight: FontWeight.w900, fontSize: 14),
              unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14),
              dividerColor: Colors.transparent,
              tabs: [
                Tab(text: t('period_daily')),
                Tab(text: t('period_weekly')),
                Tab(text: t('period_monthly')),
                Tab(text: t('period_yearly')),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: _Period.values
                .map((p) => _buildList(_periodStart(p)))
                .toList(),
          ),
        );
      },
    );
  }

  Widget _buildList(DateTime since) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _repo.watchWinsSince(since),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(t('leaderboard_error'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 15, height: 1.4)),
                  const SizedBox(height: 10),
                  Text('${snapshot.error}',
                      textAlign: TextAlign.center,
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 10)),
                ],
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // İstemci tarafında kazanan bazında grupla ve say.
        final Map<String, Map<String, dynamic>> agg = {};
        for (final doc in snapshot.data!.docs) {
          final data = doc.data();
          if (data['won'] != true) continue; // sadece kazanılan oyunlar
          final id = data['deviceId'] as String?;
          if (id == null) continue;
          final entry = agg.putIfAbsent(
              id,
              () => {
                    'count': 0,
                    'displayName': data['displayName'],
                    'avatarIconIndex': data['avatarIconIndex'],
                    'avatarColorValue': data['avatarColorValue'],
                    'photoBase64': data['photoBase64'],
                  });
          entry['count'] = (entry['count'] as int) + 1;
        }
        // Stable tie-breakers keep equal-win rankings consistent.
        final sorted = agg.entries.toList()
          ..sort((a, b) {
            final winsCompare = (b.value['count'] as int)
                .compareTo(a.value['count'] as int);
            if (winsCompare != 0) return winsCompare;
            final nameA = (a.value['displayName'] as String? ?? '')
                .trim().toLowerCase();
            final nameB = (b.value['displayName'] as String? ?? '')
                .trim().toLowerCase();
            final nameCompare = nameA.compareTo(nameB);
            return nameCompare != 0 ? nameCompare : a.key.compareTo(b.key);
          });
        final top = sorted.take(30).toList();
        final myDeviceId = UserProfile.instance.deviceId;
        final myIndex = myDeviceId == null
            ? -1
            : sorted.indexWhere((entry) => entry.key == myDeviceId);
        final myEntry = myIndex >= 0 ? sorted[myIndex] : null;

        if (top.isEmpty) {
          return Center(
            child: Text(t('no_games_yet'),
                style: const TextStyle(color: Colors.white54)),
          );
        }

        final podium = <int>[2, 1, 3]
            .where((rank) => rank <= top.length)
            .map((rank) => top[rank - 1])
            .toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF263B55), Color(0xFF17263A)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0x66FBBF24)),
              ),
              child: Column(children: [
                const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD36A), size: 22),
                  SizedBox(width: 8),
                  Text('ŞAMPİYONLAR PODYUMU', style: TextStyle(
                    color: Color(0xFFFFE4A3), fontSize: 13,
                    fontWeight: FontWeight.w900, letterSpacing: 1)),
                ]),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final item in podium)
                      Expanded(child: _LeaderboardPodiumCard(
                        rank: top.indexOf(item) + 1,
                        name: item.value['displayName'] as String? ?? t('guest_label'),
                        wins: item.value['count'] as int,
                        photoBase64: item.value['photoBase64'] as String?,
                        iconIndex: item.value['avatarIconIndex'] as int?,
                        colorValue: item.value['avatarColorValue'] as int?,
                      )),
                  ],
                ),
              ]),
            ),
            if (myEntry != null) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 18, 4, 9),
                child: Row(children: [
                  Icon(Icons.person_pin_circle_rounded,
                      color: Color(0xFFFFD36A), size: 19),
                  SizedBox(width: 8),
                  Text('SENİN SIRALAMAN', style: TextStyle(
                    color: Colors.white, fontSize: 14,
                    fontWeight: FontWeight.w900, letterSpacing: .8)),
                ]),
              ),
              _LeaderboardRow(
                rank: myIndex + 1,
                name: myEntry.value['displayName'] as String? ?? t('guest_label'),
                wins: myEntry.value['count'] as int,
                photoBase64: myEntry.value['photoBase64'] as String?,
                iconIndex: myEntry.value['avatarIconIndex'] as int?,
                colorValue: myEntry.value['avatarColorValue'] as int?,
                isCurrentPlayer: true,
              ),
            ],
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 18, 4, 10),
              child: Row(children: [
                Icon(Icons.leaderboard_rounded, color: Color(0xFFFFD36A), size: 19),
                SizedBox(width: 8),
                Text('GENEL SIRALAMA', style: TextStyle(
                  color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900,
                  letterSpacing: .8)),
              ]),
            ),
            for (var i = 3; i < top.length; i++)
              _LeaderboardRow(
                rank: i + 1,
                name: top[i].value['displayName'] as String? ?? t('guest_label'),
                wins: top[i].value['count'] as int,
                photoBase64: top[i].value['photoBase64'] as String?,
                iconIndex: top[i].value['avatarIconIndex'] as int?,
                colorValue: top[i].value['avatarColorValue'] as int?,
              ),
          ],
        );
      },
    );
  }
}

class _LeaderboardPodiumCard extends StatelessWidget {
  final int rank;
  final String name;
  final int wins;
  final String? photoBase64;
  final int? iconIndex;
  final int? colorValue;

  const _LeaderboardPodiumCard({
    required this.rank, required this.name, required this.wins,
    this.photoBase64, this.iconIndex, this.colorValue,
  });

  @override
  Widget build(BuildContext context) {
    final first = rank == 1;
    final accent = rank == 1 ? const Color(0xFFFFD36A)
        : rank == 2 ? const Color(0xFFD7E0EA) : const Color(0xFFD99A68);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Container(
        constraints: BoxConstraints(minHeight: first ? 144 : 126),
        padding: const EdgeInsets.fromLTRB(5, 10, 5, 10),
        decoration: BoxDecoration(
          color: accent.withOpacity(first ? .18 : .10),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: accent.withOpacity(first ? .85 : .45), width: first ? 1.8 : 1.1),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
          Text(rank == 1 ? '👑' : rank == 2 ? '🥈' : '🥉',
            style: TextStyle(fontSize: first ? 27 : 23)),
          const SizedBox(height: 5),
          ProfileAvatar.remote(
            radius: first ? 25 : 21,
            photoBase64: photoBase64,
            iconIndex: iconIndex,
            color: colorValue != null ? Color(colorValue!) : Colors.white24,
          ),
          const SizedBox(height: 6),
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text('$wins galibiyet', maxLines: 1,
            style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w900)),
        ]),
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final int rank;
  final String name;
  final int wins;
  final String? photoBase64;
  final int? iconIndex;
  final int? colorValue;
  final bool isCurrentPlayer;

  const _LeaderboardRow({
    required this.rank,
    required this.name,
    required this.wins,
    this.photoBase64,
    this.iconIndex,
    this.colorValue,
    this.isCurrentPlayer = false,
  });

  String get _rankBadge {
    switch (rank) {
      case 1:
        return '👑';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '#$rank';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cv = colorValue; // public alan terfi etmez, yerel kopya şart
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: isCurrentPlayer
            ? const Color(0xFF70431F)
            : const Color(0xFF263B55).withOpacity(.82),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrentPlayer
              ? const Color(0xFFFFD36A)
              : Colors.white.withOpacity(.09),
          width: isCurrentPlayer ? 1.6 : 1,
        ),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              _rankBadge,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFFFFD27A),
                  fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 8),
          ProfileAvatar.remote(
            radius: 18,
            photoBase64: photoBase64,
            iconIndex: iconIndex,
            color: cv != null ? Color(cv) : Colors.white24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          if (isCurrentPlayer) ...[
            const SizedBox(width: 6),
            const Text('SEN', style: TextStyle(
              color: Color(0xFFFFE4A3), fontSize: 10,
              fontWeight: FontWeight.w900)),
            const SizedBox(width: 8),
          ],
          Text('$wins',
              style: const TextStyle(
                  color: Color(0xFFFFD27A),
                  fontWeight: FontWeight.w900,
                  fontSize: 16)),
        ],
      ),
    );
  }
}
