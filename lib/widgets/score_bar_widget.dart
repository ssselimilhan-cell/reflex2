import 'package:flutter/material.dart';
import '../settings/strings.dart';
import '../settings/user_profile.dart';
import 'profile_avatar.dart';
import 'game_ui.dart';

class ScoreBarWidget extends StatelessWidget {
  final String leftLabel;
  final int leftScore;
  final String rightLabel;
  final int rightScore;
  final VoidCallback? onReset;

  const ScoreBarWidget({
    super.key,
    required this.leftLabel,
    required this.leftScore,
    required this.rightLabel,
    required this.rightScore,
    this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: UserProfile.instance,
      builder: (context, _) {
        final hasProfile = UserProfile.instance.hasProfile;
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 7, 12, 5),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xE6223B59), Color(0xE6111D30)],
            ),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: GameUi.cyan.withOpacity(0.20)),
            boxShadow: const [
              BoxShadow(color: Color(0x30000000), blurRadius: 14, offset: Offset(0, 5)),
            ],
          ),
          child: Row(
            children: [
              if (hasProfile) ...[
                const ProfileAvatar(radius: 13),
                const SizedBox(width: 7),
              ],
              Expanded(
                child: _ScoreSide(label: leftLabel, score: leftScore, alignEnd: true),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 13),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(t('score').toUpperCase(),
                        style: const TextStyle(color: Colors.white38, fontSize: 8, letterSpacing: 1.5, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 1),
                    Text('VS', style: GameUi.display(13, color: GameUi.cyan, spacing: 1.8)),
                  ],
                ),
              ),
              Expanded(
                child: _ScoreSide(label: rightLabel, score: rightScore),
              ),
              if (onReset != null) ...[
                const SizedBox(width: 5),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints.tightFor(width: 30, height: 30),
                  padding: EdgeInsets.zero,
                  tooltip: 'Sıfırla',
                  onPressed: onReset,
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white54, size: 17),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ScoreSide extends StatelessWidget {
  final String label;
  final int score;
  final bool alignEnd;
  const _ScoreSide({required this.label, required this.score, this.alignEnd = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label.toUpperCase(),
            maxLines: 2,
            softWrap: true,
            overflow: TextOverflow.visible,
            style: const TextStyle(color: Colors.white60, fontSize: 9, letterSpacing: 1.0, fontWeight: FontWeight.w700)),
        const SizedBox(height: 1),
        Text('$score',
            style: GameUi.display(22, color: Colors.white, spacing: 0.2)),
      ],
    );
  }
}
