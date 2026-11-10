import 'package:flutter/material.dart';
import '../settings/strings.dart';
import 'game_ui.dart';

/// Oyun sonu bildirimi. Oyun durumunu değiştirmez; yalnızca sonucu sunar.
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
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.82, end: 1),
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOutBack,
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: Container(
                  width: 340,
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF263D5B), Color(0xFF111D30), Color(0xFF101827)],
                    ),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: accent.withOpacity(0.72), width: 1.4),
                    boxShadow: [
                      BoxShadow(color: accent.withOpacity(0.20), blurRadius: 38, spreadRadius: 2),
                      const BoxShadow(color: Color(0x99000000), blurRadius: 28, offset: Offset(0, 16)),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 94,
                            height: 94,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [accent.withOpacity(0.28), accent.withOpacity(0.07)],
                              ),
                              border: Border.all(color: accent.withOpacity(0.55), width: 1.3),
                              boxShadow: [BoxShadow(color: accent.withOpacity(0.16), blurRadius: 24)],
                            ),
                            child: Icon(
                              isWin ? Icons.emoji_events_rounded : Icons.bolt_rounded,
                              color: accent,
                              size: 52,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            isWin ? 'VICTORY' : 'MATCH COMPLETE',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.8,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: GameUi.display(27, color: accent, spacing: 0.2),
                          ),
                          const SizedBox(height: 24),
                          GamePrimaryButton(
                            label: t('play_again'),
                            icon: Icons.replay_rounded,
                            height: 56,
                            onTap: onPlayAgain,
                          ),
                        ],
                      ),
                      if (onDismiss != null)
                        Positioned(
                          top: -10,
                          right: -10,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: onDismiss,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                              ),
                            ),
                          ),
                        ),
                    ],
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
