import 'package:flutter/material.dart';

/// Oyun masasına "kadife" hissi veren, hareketsiz (ucuz) bir katman:
/// ortada yumuşak bir ışık, kenarlara doğru koyulaşan vinyet ve çok silik,
/// eğik duran iskambil sembolleri (♠ ♥ ♦ ♣) deseni. Altındaki zemin rengini
/// (tema rengi) değiştirmez, sadece üstüne ince katmanlar ekler.
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

    // 1) Masanın ortasında yumuşak ışık.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.2),
          radius: 0.85,
          colors: [Colors.white.withOpacity(0.08), Colors.transparent],
        ).createShader(rect),
    );

    // 2) Silik iskambil sembolü deseni.
    final style = TextStyle(fontSize: 30, color: Colors.white.withOpacity(0.04));
    final painters = <TextPainter>[
      for (final s in _suits)
        TextPainter(
          text: TextSpan(text: s, style: style),
          textDirection: TextDirection.ltr,
        )..layout(),
    ];
    const step = 76.0;
    var row = 0;
    for (double y = 18; y < size.height; y += step) {
      final startX = row.isEven ? 18.0 : 18.0 + step / 2;
      for (double x = startX; x < size.width; x += step) {
        final tp = painters[(row * 2 + (x ~/ step)) % 4];
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(-0.21);
        tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
        canvas.restore();
      }
      row++;
    }

    // 3) Kenarlarda koyulaşan vinyet.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 0.95,
          colors: [Colors.transparent, Colors.black.withOpacity(0.38)],
          stops: const [0.55, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
