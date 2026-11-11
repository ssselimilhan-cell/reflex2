import 'package:flutter/material.dart';

/// Premium warm felt: a brighter terracotta table with amber light and subtle suit texture.
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

    // The table itself is now visibly warm and luminous, not a dark overlay
    // on top of the old navy scaffold background.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFD98243),
            Color(0xFFC66A35),
            Color(0xFFAA512D),
            Color(0xFF8E4028),
          ],
          stops: [0.0, 0.38, 0.76, 1.0],
        ).createShader(rect),
    );

    // Soft amber light in the centre gives the felt depth without obscuring cards.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.18),
          radius: 0.92,
          colors: [
            const Color(0xFFFFD18A).withOpacity(0.30),
            const Color(0xFFF4A45E).withOpacity(0.10),
            Colors.transparent,
          ],
          stops: const [0.0, 0.58, 1.0],
        ).createShader(rect),
    );

    final style = TextStyle(fontSize: 30, color: Colors.white.withOpacity(0.075));
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

    // Keep only a gentle edge falloff; the previous heavy black vignette
    // was making the whole play area feel muddy and underexposed.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 1.12,
          colors: [Colors.transparent, const Color(0x33000000)],
          stops: const [0.70, 1.0],
        ).createShader(rect),
    );

    // A restrained inset seam makes the surface read as a finished game table.
    final inset = rect.deflate(10);
    canvas.drawRRect(
      RRect.fromRectAndRadius(inset, const Radius.circular(22)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0x35FFE4BD),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
