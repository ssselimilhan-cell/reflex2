import 'package:flutter/material.dart';
import '../settings/strings.dart';
import 'game_ui.dart';

/// Responsive result sheet shared by bot and online matches.
class GameResultOverlay extends StatelessWidget {
  final bool isWin;
  final String title;
  final VoidCallback onPlayAgain;
  final VoidCallback? onDismiss;

  const GameResultOverlay({
    super.key,
    required this.isWin,
    required this.title,
    required this.onPlayAgain,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isWin ? GameUi.rewardGold : const Color(0xFFFB7185);
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onDismiss,
        child: Container(
          color: const Color(0xD9091424),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 28),
                  child: Center(
                    child: GestureDetector(
                      onTap: () {},
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.94, end: 1),
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        builder: (context, scale, child) =>
                            Transform.scale(scale: scale, child: child),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 360),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF263D5B), Color(0xFF111D30), Color(0xFF101827)],
                              ),
                              borderRadius: BorderRadius.circular(26),
                              border: Border.all(color: accent.withOpacity(0.72), width: 1.4),
                              boxShadow: [
                                BoxShadow(color: accent.withOpacity(0.20), blurRadius: 34, spreadRadius: 1),
                                const BoxShadow(color: Color(0x99000000), blurRadius: 26, offset: Offset(0, 14)),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 78,
                                  height: 78,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [accent.withOpacity(0.28), accent.withOpacity(0.07)],
                                    ),
                                    border: Border.all(color: accent.withOpacity(0.55), width: 1.3),
                                  ),
                                  child: Icon(
                                    isWin ? Icons.emoji_events_rounded : Icons.bolt_rounded,
                                    color: accent,
                                    size: 44,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  title,
                                  textAlign: TextAlign.center,
                                  softWrap: true,
                                  style: GameUi.display(26, color: accent, spacing: 0.1),
                                ),
                                const SizedBox(height: 20),
                                GamePrimaryButton(
                                  label: t('play_again'),
                                  icon: Icons.replay_rounded,
                                  height: 56,
                                  onTap: onPlayAgain,
                                ),
                                if (onDismiss != null) ...[
                                  const SizedBox(height: 10),
                                  TextButton(
                                    onPressed: onDismiss,
                                    child: Text(t('close_invite'), style: const TextStyle(color: Colors.white70, fontSize: 15)),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
