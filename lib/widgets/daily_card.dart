import 'package:flutter/material.dart';
import '../settings/progress.dart';
import '../settings/strings.dart';

/// Ana ekranda küçük bir özet: günlük seri, yıldızlar ve görev durumu.
/// Dokununca görevlerin ayrıntılı listesi açılır.
class DailyCard extends StatelessWidget {
  const DailyCard({super.key});

  void _openMissions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1B1B1B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: AnimatedBuilder(
          animation: Progress.instance,
          builder: (context, _) {
            final p = Progress.instance;
            return Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('daily_title'),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('🔥 ${p.activeStreak}   ⭐ ${p.stars}',
                      style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(t('streak_hint'),
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 14),
                  for (var i = 0; i < Progress.missions.length; i++)
                    _MissionRow(index: i),
                ],
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
        return Material(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => _openMissions(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🔥 ${p.activeStreak}',
                      style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(width: 14),
                  Text('⭐ ${p.stars}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(width: 14),
                  const Icon(Icons.flag_outlined,
                      color: Colors.white70, size: 17),
                  const SizedBox(width: 4),
                  Text('${p.doneToday}/${Progress.missions.length}',
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MissionRow extends StatelessWidget {
  final int index;
  const _MissionRow({required this.index});

  @override
  Widget build(BuildContext context) {
    final p = Progress.instance;
    final m = Progress.missions[index];
    final done = p.isClaimed(index);
    final value = p.missionValue(index);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(done ? Icons.check_circle : Icons.radio_button_unchecked,
              color: done ? Colors.greenAccent : Colors.white38, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t(m.titleKey),
                    style: TextStyle(
                        color: done ? Colors.white54 : Colors.white,
                        fontSize: 14)),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: m.target == 0 ? 0 : value / m.target,
                  minHeight: 5,
                  backgroundColor: Colors.white12,
                  color: done ? Colors.greenAccent : Colors.amber,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text('$value/${m.target}',
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }
}
