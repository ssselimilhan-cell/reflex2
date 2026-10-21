import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Edvard Munch'ın "Çığlık" tablosundaki gerilimli, dalgalanan, "eriyen
/// gökyüzü" hissinden esinlenen — ama tabloyu KOPYALAMAYAN, tamamen
/// orijinal, sade geometrik şekillerle (renk geçişi + dalgalı çizgiler)
/// oluşturulmuş hareketli bir arka plan. "Stres/Refleks" temasına uygun
/// olarak durağan değil, sürekli kıvranan/nefes alan bir doku veriyor.
class ScreamBackground extends StatefulWidget {
  const ScreamBackground({super.key});

  @override
  State<ScreamBackground> createState() => _ScreamBackgroundState();
}

class _ScreamBackgroundState extends State<ScreamBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Dokunuşlar arkadaki bu dekora takılmasın; RepaintBoundary sayesinde
    // bu sürekli animasyon, üstteki düğmelerin yeniden çizilmesini
    // tetiklemez.
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: _ScreamPainter(_controller.value),
              size: Size.infinite,
            );
          },
        ),
      ),
    );
  }
}

class _ScreamPainter extends CustomPainter {
  final double t; // 0..1, sürekli döngü

  _ScreamPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    // 1) Sürekli hafifçe kayan, gerilimli (turuncu-kırmızı-mor arası)
    //    gradyan arka plan — "huzursuz gökyüzü" hissi.
    final wave1 = (math.sin(t * 2 * math.pi) + 1) / 2;
    final wave2 = (math.cos(t * 2 * math.pi * 0.7) + 1) / 2;
    final topColor = Color.lerp(
        const Color(0xFFBF360C), const Color(0xFF880E4F), wave1)!;
    final bottomColor = Color.lerp(
        const Color(0xFF4A148C), const Color(0xFF1A1A4A), wave2)!;

    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [topColor, bottomColor],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // 2) Dalgalanan, "eriyen" çizgiler — ekranın her yerinde sürekli
    //    kıvranan, birbirinden farklı fazda birkaç eğri.
    const lineCount = 8;
    for (var i = 0; i < lineCount; i++) {
      final opacity = 0.05 + 0.025 * (i % 3);
      final paint = Paint()
        ..color = Colors.white.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2;
      final path = Path();
      final baseY = size.height * (0.08 + i * 0.115);
      final phase = t * 2 * math.pi + i * 0.65;
      final amplitude = 14.0 + (i % 4) * 5;
      var started = false;
      for (double x = 0; x <= size.width; x += 16) {
        final y = baseY +
            amplitude * math.sin((x / size.width) * 3.5 * math.pi + phase);
        if (!started) {
          path.moveTo(x, y);
          started = true;
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);
    }

    // 3) Ekranın alt yarısında, hafifçe nefes alan bir "gerilim" halesi
    //    (ortadan dışa doğru yumuşak bir radial gradyan).
    final pulse = 0.5 + 0.5 * math.sin(t * 2 * math.pi * 1.3);
    final haloPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.deepOrangeAccent.withOpacity(0.10 + 0.05 * pulse),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
          center: Offset(size.width / 2, size.height * 0.62),
          radius: size.width * 0.75));
    canvas.drawRect(Offset.zero & size, haloPaint);
  }

  @override
  bool shouldRepaint(covariant _ScreamPainter oldDelegate) =>
      oldDelegate.t != t;
}
