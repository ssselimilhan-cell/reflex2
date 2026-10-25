import 'package:flutter/material.dart';

/// Oyun masasına "kadife" hissi veren, hareketsiz (ucuz) bir katman:
/// kenarlara doğru hafif koyulaşan vinyet + çok ince kumaş dokusu.
class TableFelt extends StatelessWidget {
  const TableFelt({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(painter: _FeltPainter(), size: Size.infinite),
      ),
    );
  }
}

class _FeltPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 0.95,
          colors: [Colors.transparent, Colors.black.withOpacity(0.30)],
          stops: const [0.6, 1.0],
        ).createShader(rect),
    );
    final line = Paint()
      ..color = Colors.white.withOpacity(0.022)
      ..strokeWidth = 1;
    for (double x = -size.height; x < size.width; x += 14) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), line);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
