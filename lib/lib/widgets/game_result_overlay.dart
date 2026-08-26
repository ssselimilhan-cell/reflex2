import 'package:flutter/material.dart';
import '../settings/strings.dart';

/// Oyun bittiğinde tüm ekranı kaplayan, gözden kaçmayacak kadar belirgin
/// bir sonuç bildirimi. "Tekrar Oyna" düğmesi her modda burada.
class GameResultOverlay extends StatelessWidget {
  final bool isWin;
  final String title;
  final VoidCallback onPlayAgain;

  const GameResultOverlay({
    super.key,
    required this.isWin,
    required this.title,
    required this.onPlayAgain,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isWin ? const Color(0xFFFFD54F) : const Color(0xFFEF5350);
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.72),
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.7, end: 1.0),
            duration: const Duration(milliseconds: 350),
            curve: Curves.elasticOut,
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1B1B),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: accent, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: accent.withOpacity(0.5),
                    blurRadius: 30,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isWin ? Icons.emoji_events : Icons.sentiment_dissatisfied,
                    color: accent,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: accent,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton.icon(
                    onPressed: onPlayAgain,
                    icon: const Icon(Icons.replay),
                    label: Text(t('play_again'),
                        style: const TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
