import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../settings/strings.dart';

/// Art arda hamle avantajı (1/2/3 kart) kazanıldığında kısa süreliğine
/// beliren, avantaj arttıkça daha yoğun (daha çok parçacık, daha büyük)
/// bir kutlama efekti. Otomatik kapanır (onDone çağrılır).
class StreakCelebrationOverlay extends StatefulWidget {
  final int bonus; // 1, 2 ya da 3
  final VoidCallback onDone;

  const StreakCelebrationOverlay({
    super.key,
    required this.bonus,
    required this.onDone,
  });

  @override
  State<StreakCelebrationOverlay> createState() =>
      _StreakCelebrationOverlayState();
}

class _StreakCelebrationOverlayState extends State<StreakCelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1300 + widget.bonus * 250),
    )..forward();
    _controller.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _emoji {
    switch (widget.bonus) {
      case 1:
        return '🔥';
      case 2:
        return '🎉';
      default:
        return '🏆';
    }
  }

  @override
  Widget build(BuildContext context) {
    final particleCount = 4 + widget.bonus * 3;
    final spread = 55.0 + widget.bonus * 22;

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final progress = _controller.value;
          final popIn = (progress / 0.25).clamp(0.0, 1.0);
          final scale = Curves.elasticOut.transform(popIn);
          final fadeOut = progress > 0.72 ? (1 - (progress - 0.72) / 0.28) : 1.0;

          return Opacity(
            opacity: fadeOut.clamp(0.0, 1.0),
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  for (var i = 0; i < particleCount; i++)
                    Transform.translate(
                      offset: Offset(
                        spread * progress * math.cos(i * 2 * math.pi / particleCount),
                        spread * progress * math.sin(i * 2 * math.pi / particleCount),
                      ),
                      child: Opacity(
                        opacity: (1 - progress).clamp(0.0, 1.0),
                        child: Text(_emoji,
                            style: TextStyle(fontSize: 16.0 + widget.bonus * 3)),
                      ),
                    ),
                  Transform.scale(
                    scale: scale,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 22, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.amber, width: 2),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.amber.withOpacity(0.5),
                              blurRadius: 16,
                              spreadRadius: 2),
                        ],
                      ),
                      child: Text(
                        '$_emoji +${widget.bonus} ${t('streak_bonus_label')}',
                        style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 20,
                            fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
