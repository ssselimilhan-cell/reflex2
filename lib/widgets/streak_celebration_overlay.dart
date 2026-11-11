import 'package:flutter/material.dart';
import '../settings/strings.dart';

/// Compact, non-blocking reward feedback. It is intentionally kept away
/// from the card columns so match play remains fully visible.
class StreakCelebrationOverlay extends StatefulWidget {
  final int bonus;
  final VoidCallback onDone;

  const StreakCelebrationOverlay({
    super.key,
    required this.bonus,
    required this.onDone,
  });

  @override
  State<StreakCelebrationOverlay> createState() => _StreakCelebrationOverlayState();
}

class _StreakCelebrationOverlayState extends State<StreakCelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final fade = _controller.value < 0.72
              ? 1.0
              : (1 - (_controller.value - 0.72) / 0.28).clamp(0.0, 1.0);
          final slide = (1 - Curves.easeOutCubic.transform(
              (_controller.value / 0.24).clamp(0.0, 1.0))) * -10;
          return Opacity(
            opacity: fade,
            child: Transform.translate(
              offset: Offset(0, slide),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xEE263A50),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.amber.withOpacity(0.72)),
                  boxShadow: const [
                    BoxShadow(color: Color(0x44000000), blurRadius: 12, offset: Offset(0, 4)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_fire_department_rounded,
                        color: Colors.amber, size: 18),
                    const SizedBox(width: 7),
                    Text(
                      '+${widget.bonus} ${t('streak_bonus_label')}',
                      style: const TextStyle(
                          color: Colors.amber, fontSize: 14, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
