import 'package:flutter/material.dart';
import '../settings/strings.dart';

/// Bot Yolu'nda bir seviye bitince çıkan sonuç kutusu: kazanınca yıldız
/// ve "Sonraki Seviye", kaybedince "Tekrar Dene" + ipucu.
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
          color: Colors.black.withOpacity(0.72),
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.8, end: 1.0),
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutBack,
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 340),
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1B1B),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: accent, width: 2),
                    boxShadow: [
                      BoxShadow(
                          color: accent.withOpacity(0.35),
                          blurRadius: 28,
                          spreadRadius: 2),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isWin ? t('level_cleared') : t('level_failed'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: accent,
                            fontSize: 26,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text('${t('level')} $level',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 16)),
                      if (starsGained > 0) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0x33FFC107),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('+$starsGained ⭐',
                              style: const TextStyle(
                                  color: Colors.amber,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                      if (isWin && isLastLevel) ...[
                        const SizedBox(height: 14),
                        Text(t('ladder_complete'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 15)),
                      ],
                      if (!isWin && level >= 8) ...[
                        const SizedBox(height: 14),
                        Text(t('level_tip'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                height: 1.35)),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: primaryAction,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.black87,
                            minimumSize: const Size.fromHeight(48),
                          ),
                          child: Text(primaryLabel,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
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
    );
  }
}

Widget _ghost(String label, VoidCallback onTap) {
  return OutlinedButton(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      side: const BorderSide(color: Colors.white38),
      minimumSize: const Size.fromHeight(44),
    ),
    child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
  );
}
