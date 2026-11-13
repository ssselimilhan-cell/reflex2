import 'package:flutter/material.dart';
import '../settings/progress.dart';
import '../settings/strings.dart';
import 'game_ui.dart';

/// Günlük hedefleri, seri durumunu ve kazanılabilir yıldızları ana ekranda
/// görünür tutar. İlerleme yalnızca gerçek oyun sonuçlarından beslenir.
class DailyCard extends StatelessWidget {
  const DailyCard({super.key});

  void _openMissions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: AnimatedBuilder(
          animation: Progress.instance,
          builder: (context, _) {
            final p = Progress.instance;
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.78,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF111C2D),
                borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                border: Border(top: BorderSide(color: Color(0x66FBBF24))),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Icon(Icons.local_fire_department_rounded,
                            color: GameUi.gold, size: 27),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text('Yıldız Kazan',
                              style: GameUi.display(20, color: Colors.white)),
                        ),
                        _StarReward(stars: p.stars),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(t('streak_hint'),
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 13, height: 1.4)),
                    const SizedBox(height: 18),
                    _StreakPanel(streak: p.activeStreak),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Text('Yıldız Kazan',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15)),
                        ),
                        Text('${p.doneToday}/${Progress.missions.length}',
                            style: const TextStyle(
                                color: GameUi.gold,
                                fontWeight: FontWeight.w900)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    for (var i = 0; i < Progress.missions.length; i++)
                      _MissionRow(index: i),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Progress.instance,
      builder: (context, _) {
        final p = Progress.instance;
        final total = Progress.missions.length;
        final done = p.doneToday;
        final ratio = total == 0 ? 0.0 : done / total;
        var nextMission = 0;
        while (nextMission < total && p.isClaimed(nextMission)) {
          nextMission++;
        }
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _openMissions(context),
            child: Ink(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xE62B3545), Color(0xE6121D2E)],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0x66FBBF24)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x26000000),
                    blurRadius: 18,
                    offset: Offset(0, 7),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 9, 11, 9),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: GameUi.gold.withOpacity(0.13),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.local_fire_department_rounded,
                            color: GameUi.gold,
                            size: 27,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Yıldız Kazan',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 3),
                              Text(t('streak_hint'),
                                  maxLines: 2,
                                  softWrap: true,
                                  overflow: TextOverflow.visible,
                                  style: const TextStyle(
                                      color: Colors.white60, fontSize: 10.5)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('🔥 ${p.activeStreak}',
                                style: GameUi.display(18, color: GameUi.gold)),
                            Text('${p.doneToday}/$total',
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.chevron_right,
                            color: Colors.white54, size: 20),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 5,
                        backgroundColor: Colors.white12,
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(GameUi.gold),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.stars_rounded,
                            color: GameUi.gold, size: 16),
                        const SizedBox(width: 5),
                        Text('${p.stars}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w800)),
                        const Spacer(),
                        Text(
                          done == total
                              ? t('mission_done')
                              : t(Progress.missions[nextMission].titleKey),
                          style: const TextStyle(
                              color: GameUi.gold,
                              fontSize: 10,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StreakPanel extends StatelessWidget {
  final int streak;
  const _StreakPanel({required this.streak});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.045),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            const Icon(Icons.local_fire_department_rounded,
                color: GameUi.gold, size: 34),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$streak',
                      style: GameUi.display(23, color: GameUi.gold)),
                  Text(t('streak_hint'),
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 11)),
                ],
              ),
            ),
            const Text('🔥',
                style: TextStyle(fontSize: 25)),
          ],
        ),
      );
}

class _StarReward extends StatelessWidget {
  final int stars;
  const _StarReward({required this.stars});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: GameUi.gold.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: GameUi.gold.withOpacity(0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded, color: GameUi.gold, size: 17),
            const SizedBox(width: 4),
            Text('$stars',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w900)),
          ],
        ),
      );
}

class _MissionRow extends StatelessWidget {
  final int index;
  const _MissionRow({required this.index});

  @override
  Widget build(BuildContext context) {
    final p = Progress.instance;
    final mission = Progress.missions[index];
    final done = p.isClaimed(index);
    final value = p.missionValue(index);
    final ratio = mission.target == 0
        ? 0.0
        : (value / mission.target).clamp(0.0, 1.0).toDouble();
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.045),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
            color: done ? GameUi.gold.withOpacity(0.45) : Colors.white10),
      ),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.circle_outlined,
            color: done ? GameUi.gold : Colors.white38,
            size: 22,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t(mission.titleKey),
                    style: TextStyle(
                        color: done ? Colors.white60 : Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 5,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        done ? GameUi.gold : const Color(0xFFF59E0B)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$value/${mission.target}',
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              const Text('+1 ⭐',
                  style: TextStyle(
                      color: GameUi.gold,
                      fontSize: 10,
                      fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      ),
    );
  }
}
