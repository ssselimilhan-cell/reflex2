import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../online/firestore_game_repository.dart';
import '../settings/app_settings.dart';
import '../settings/strings.dart';
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
          backgroundColor: AppSettings.instance.themeColor,
          appBar: AppBar(
            title: Text(t('leaderboard_title')),
            bottom: TabBar(
              controller: _tabController,
              isScrollable: false,
              labelColor: Colors.amber,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.amber,
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
              padding: const EdgeInsets.all(16),
              child: Text('${snapshot.error}',
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(color: Colors.redAccent, fontSize: 11)),
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
        final sorted = agg.entries.toList()
          ..sort((a, b) =>
              (b.value['count'] as int).compareTo(a.value['count'] as int));
        final top = sorted.take(30).toList();

        if (top.isEmpty) {
          return Center(
            child: Text(t('no_games_yet'),
                style: const TextStyle(color: Colors.white54)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: top.length,
          itemBuilder: (context, i) {
            final entry = top[i].value;
            return _LeaderboardRow(
              rank: i + 1,
              name: entry['displayName'] as String? ?? t('guest_label'),
              wins: entry['count'] as int,
              photoBase64: entry['photoBase64'] as String?,
              iconIndex: entry['avatarIconIndex'] as int?,
              colorValue: entry['avatarColorValue'] as int?,
            );
          },
        );
      },
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

  const _LeaderboardRow({
    required this.rank,
    required this.name,
    required this.wins,
    this.photoBase64,
    this.iconIndex,
    this.colorValue,
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
    final isTop3 = rank <= 3;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isTop3 ? Colors.amber.withOpacity(0.12) : Colors.black26,
        borderRadius: BorderRadius.circular(12),
        border: isTop3
            ? Border.all(color: Colors.amber.withOpacity(0.5), width: 1.2)
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              _rankBadge,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: isTop3 ? 22 : 15,
                  color: Colors.white70,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          ProfileAvatar.remote(
            radius: 18,
            photoBase64: photoBase64,
            iconIndex: iconIndex,
            color: colorValue != null ? Color(colorValue!) : Colors.white24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          Text('$wins',
              style: const TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.w900,
                  fontSize: 16)),
        ],
      ),
    );
  }
}
