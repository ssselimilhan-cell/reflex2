import 'package:flutter/material.dart';
import '../settings/strings.dart';
import '../settings/user_profile.dart';
import 'profile_avatar.dart';

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
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasProfile) ...[
                const ProfileAvatar(radius: 12),
                const SizedBox(width: 8),
              ],
              Text('${t('score')}: ',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
              Text('$leftLabel $leftScore',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              const Text('  -  ', style: TextStyle(color: Colors.white54)),
              Text('$rightScore $rightLabel',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              if (onReset != null) ...[
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: onReset,
                  child: const Icon(Icons.refresh,
                      color: Colors.white54, size: 16),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
