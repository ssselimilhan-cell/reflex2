import 'package:flutter/material.dart';
import '../game/bot_profile.dart';
import '../settings/app_settings.dart';
import '../settings/ladder.dart';
import '../settings/strings.dart';
import '../widgets/game_ui.dart';
import 'vs_bot_screen.dart';

const Color _panelColor = Color(0x40000000);
const Color _hairline = Color(0x1FFFFFFF);

/// Her diyarın (10 seviye) vurgu rengi.
const List<Color> _realmColors = [
  Color(0xFF66BB6A),
  Color(0xFFFFA726),
  Color(0xFFAB47BC),
  Color(0xFFFFCA28),
  Color(0xFFEF5350),
  Color(0xFF26A69A),
  Color(0xFFFF7043),
  Color(0xFF5C6BC0),
  Color(0xFF8D6E63),
  Color(0xFFFFD54F),
];

/// Bot Yolu: 100 seviyelik harita. 10 seviyelik 10 diyar; her diyarın
/// son seviyesi patron. Bir seviyeyi yenince sonrakinin kilidi açılır.
class LadderScreen extends StatefulWidget {
  const LadderScreen({super.key});

  @override
  State<LadderScreen> createState() => _LadderScreenState();
}

class _LadderScreenState extends State<LadderScreen> {
  void _play(int level) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => VsBotScreen(level: level, autoStart: true)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;
    final ladder = LadderProgress.instance;
    return AnimatedBuilder(
      animation: Listenable.merge([settings, ladder]),
      builder: (context, _) {
        final next = ladder.unlockedLevel;
        final cleared = ladder.highestCleared;
        return Scaffold(
          backgroundColor: const Color(0xFFB94E20),
          appBar: AppBar(title: Text(t('menu_ladder'))),
          body: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    _HeroCard(
                      next: next,
                      cleared: cleared,
                      onPlay: () => _play(next),
                    ),
                    const SizedBox(height: 12),
                    Material(
                      color: _panelColor,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: _hairline),
                      ),
                      child: InkWell(
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const VsBotScreen())),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                          child: Row(
                            children: [
                              const Icon(Icons.tune, color: Colors.white70),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  t('ladder_free_play'),
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 15),
                                ),
                              ),
                              const Icon(Icons.chevron_right,
                                  color: Colors.white54),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    for (var r = 0; r < 10; r++)
                      _RealmSection(
                        realm: r,
                        cleared: cleared,
                        next: next,
                        onPlay: _play,
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

class _HeroCard extends StatelessWidget {
  final int next;
  final int cleared;
  final VoidCallback onPlay;

  const _HeroCard(
      {required this.next, required this.cleared, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    final realm = (next - 1) ~/ 10;
    final allDone = cleared >= LadderProgress.maxLevel;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _panelColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${t('level')} $next',
            style: const TextStyle(
                color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            t('realm_${realm + 1}'),
            style: TextStyle(
                color: _realmColors[realm],
                fontSize: 16,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            '${t('ladder_bot_speed')}: ~${BotProfile.forLevel(next).meanReactionMs} ms',
            style: const TextStyle(color: Colors.white60, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: cleared / LadderProgress.maxLevel,
              minHeight: 8,
              backgroundColor: const Color(0x33FFFFFF),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$cleared / ${LadderProgress.maxLevel}',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          if (allDone) ...[
            const SizedBox(height: 10),
            Text(t('ladder_complete'),
                style: const TextStyle(color: Colors.white, fontSize: 14)),
          ],
          const SizedBox(height: 16),
          GamePrimaryButton(
            label: t('ladder_continue'),
            icon: Icons.play_arrow_rounded,
            height: 58,
            onTap: onPlay,
          ),
        ],
      ),
    );
  }
}

class _RealmSection extends StatelessWidget {
  final int realm;
  final int cleared;
  final int next;
  final void Function(int level) onPlay;

  const _RealmSection({
    required this.realm,
    required this.cleared,
    required this.next,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _realmColors[realm];
    final start = realm * 10 + 1;
    final done = (cleared - realm * 10).clamp(0, 10).toInt();
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                  child: Text('${realm + 1}',
                      style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    t('realm_${realm + 1}'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                Text('$done/10',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _panelColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _hairline),
            ),
            child: GridView.count(
              crossAxisCount: 5,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: [
                for (var l = start; l < start + 10; l++)
                  _LevelNode(
                    level: l,
                    cleared: l <= cleared,
                    current: l == next && cleared < LadderProgress.maxLevel,
                    locked: l > next,
                    accent: accent,
                    onTap: () {
                      if (l > next) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(t('ladder_locked'))),
                        );
                      } else {
                        onPlay(l);
                      }
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelNode extends StatelessWidget {
  final int level;
  final bool cleared;
  final bool current;
  final bool locked;
  final Color accent;
  final VoidCallback onTap;

  const _LevelNode({
    required this.level,
    required this.cleared,
    required this.current,
    required this.locked,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final boss = level % 10 == 0;
    final Color fill;
    final Color fg;
    if (cleared) {
      fill = accent;
      fg = Colors.black87;
    } else if (current) {
      fill = Colors.white;
      fg = Colors.black87;
    } else {
      fill = const Color(0x33000000);
      fg = Colors.white38;
    }
    final Widget label = locked
        ? Icon(boss ? Icons.emoji_events_outlined : Icons.lock_outline,
            size: 18, color: fg)
        : (boss
            ? Icon(Icons.emoji_events, size: 22, color: fg)
            : Text('$level',
                style: TextStyle(
                    color: fg, fontSize: 16, fontWeight: FontWeight.bold)));
    return Semantics(
      button: true,
      label: '${t('level')} $level',
      child: Material(
        color: fill,
        shape: CircleBorder(
          side: BorderSide(
            color: current
                ? accent
                : (boss ? const Color(0x80FFC107) : _hairline),
            width: current ? 3 : 1.5,
          ),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Center(child: label),
        ),
      ),
    );
  }
}
