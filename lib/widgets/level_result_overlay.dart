import 'package:flutter/material.dart';
import '../settings/strings.dart';
import 'game_ui.dart';

/// Responsive result sheet for the Reflex Journey levels.
class LevelResultOverlay extends StatelessWidget {
  final bool isWin;
  final int level;
  final int starsGained;
  final bool isLastLevel;
  final VoidCallback onRetry;
  final VoidCallback onBack;
  final VoidCallback? onNext;
  final VoidCallback? onDismiss;

  const LevelResultOverlay({
    super.key,
    required this.isWin,
    required this.level,
    required this.starsGained,
    required this.isLastLevel,
    required this.onRetry,
    required this.onBack,
    this.onNext,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isWin ? const Color(0xFFFFD54F) : const Color(0xFFEF5350);
    final hasNext = isWin && onNext != null;
    final primaryLabel = hasNext ? t('level_next') : t('level_retry');
    final VoidCallback primaryAction = hasNext ? onNext! : onRetry;

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onDismiss,
        child: Container(
          color: const Color(0xC9000000),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 24),
                  child: Center(
                    child: GestureDetector(
                      onTap: () {},
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.94, end: 1.0),
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        builder: (context, scale, child) =>
                            Transform.scale(scale: scale, child: child),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 360),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF283D58), Color(0xFF121E30)],
                              ),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: accent, width: 1.6),
                              boxShadow: [
                                BoxShadow(color: accent.withOpacity(0.24), blurRadius: 26, spreadRadius: 1),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(isWin ? Icons.emoji_events_rounded : Icons.replay_rounded,
                                    color: accent, size: 54),
                                const SizedBox(height: 10),
                                Text(
                                  isWin ? t('level_cleared') : t('level_failed'),
                                  textAlign: TextAlign.center,
                                  softWrap: true,
                                  style: TextStyle(color: accent, fontSize: 25, fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 5),
                                Text('${t('level')} $level',
                                    style: const TextStyle(color: Colors.white70, fontSize: 16)),
                                if (starsGained > 0) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: const Color(0x33FFC107),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text('+$starsGained ⭐',
                                        style: const TextStyle(color: Colors.amber, fontSize: 19, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                                if (isWin && isLastLevel) ...[
                                  const SizedBox(height: 12),
                                  Text(t('ladder_complete'),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.35)),
                                ],
                                if (!isWin && level >= 8) ...[
                                  const SizedBox(height: 12),
                                  Text(t('level_tip'),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.35)),
                                ],
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: GamePrimaryButton(
                                    label: primaryLabel,
                                    height: 58,
                                    onTap: primaryAction,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    if (hasNext) ...[
                                      Expanded(child: _ghost(t('level_retry'), onRetry)),
                                      const SizedBox(width: 8),
                                    ],
                                    Expanded(child: _ghost(t('level_back'), onBack)),
                                  ],
                                ),
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

Widget _ghost(String label, VoidCallback onTap) {
  return OutlinedButton(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      side: const BorderSide(color: Colors.white38),
      minimumSize: const Size.fromHeight(46),
      padding: const EdgeInsets.symmetric(horizontal: 8),
    ),
    child: Text(label, maxLines: 2, softWrap: true, textAlign: TextAlign.center,
        overflow: TextOverflow.visible),
  );
}
