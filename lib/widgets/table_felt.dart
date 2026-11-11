import 'package:flutter/material.dart';

/// A brighter, textured felt surface with a restrained edge vignette.
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
  static const List<String> _suits = ['♠', '♥', '♦', '♣'];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.2),
          radius: 0.95,
          colors: [
            const Color(0xFF526B70).withOpacity(0.30),
            const Color(0xFF253B43).withOpacity(0.10),
            Colors.transparent,
          ],
          stops: const [0, 0.62, 1],
        ).createShader(rect),
    );

    final style = TextStyle(fontSize: 30, color: Colors.white.withOpacity(0.055));
    final painters = <TextPainter>[
      for (final suit in _suits)
        TextPainter(
          text: TextSpan(text: suit, style: style),
          textDirection: TextDirection.ltr,
        )..layout(),
    ];
    const step = 76.0;
    var row = 0;
    for (double y = 18; y < size.height; y += step) {
      final startX = row.isEven ? 18.0 : 18.0 + step / 2;
      for (double x = startX; x < size.width; x += step) {
        final painter = painters[(row * 2 + (x ~/ step)) % 4];
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(-0.21);
        painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
        canvas.restore();
      }
      row++;
    }

    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 1.0,
          colors: [Colors.transparent, Colors.black.withOpacity(0.18)],
          stops: const [0.64, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
