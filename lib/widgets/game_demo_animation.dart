import 'package:flutter/material.dart';

/// Oynanışı ~4 saniyelik bir döngüde anlatan demo: 4 mini sütun, ikisi
/// bir değerde (kırmızı vurgulu), ikisi başka bir değerde (sarı vurgulu)
/// — AYNI ANDA FARKLI eşleşmelerin farklı renklerle vurgulanabileceğini
/// gösteriyor. Sonra kırmızı eşleşmelerden biri kapatılıyor (kapalı
/// desteden kart kayarak geliyor), o eşleşme kayboluyor, tekrar başa
/// dönülüyor.
class GameDemoAnimation extends StatefulWidget {
  final double height;

  const GameDemoAnimation({super.key, this.height = 190});

  @override
  State<GameDemoAnimation> createState() => _GameDemoAnimationState();
}

class _GameDemoAnimationState extends State<GameDemoAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 260,
        height: widget.height,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value; // 0..1, döngü boyunca
            // Aşama 1 (0.0-0.40): 4 sütun, 2 farklı eşleşme aynı anda
            //   farklı renklerle (kırmızı: 7-7, sarı: K-K) vurgulu.
            // Aşama 2 (0.40-0.72): kırmızı eşleşmelerden biri kapatılıyor
            //   (kart kayarak geliyor) — sadece o eşleşme kayboluyor.
            // Aşama 3 (0.72-1.0): kısa bekleme, tekrar başa dön.
            final bothMatched = t < 0.40;
            final sliding = t >= 0.40 && t < 0.70;
            final redCovered = t >= 0.62;
            final slideProgress =
                ((t - 0.40) / 0.28).clamp(0.0, 1.0).toDouble();

            return Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Positioned(
                  top: 6,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _miniCard('7', bothMatched ? Colors.redAccent : null),
                      const SizedBox(width: 10),
                      _miniCard(redCovered ? 'Q' : '7',
                          (bothMatched && !redCovered) ? Colors.redAccent : null),
                      const SizedBox(width: 22),
                      _miniCard('K', bothMatched ? Colors.amber : null),
                      const SizedBox(width: 10),
                      _miniCard('K', bothMatched ? Colors.amber : null),
                    ],
                  ),
                ),
                if (sliding)
                  Positioned(
                    left: 62,
                    bottom: 34 + (76 * slideProgress),
                    child: Opacity(
                      opacity:
                          slideProgress < 0.92 ? 1 : (1 - slideProgress) * 12,
                      child: _miniCard('Q', null, small: true),
                    ),
                  ),
                Positioned(
                  bottom: 0,
                  child: Container(
                    width: 46,
                    height: 22,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E4D8C),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white24, width: 1),
                    ),
                    child: const Center(
                      child: Icon(Icons.style, color: Colors.white54, size: 12),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _miniCard(String rank, Color? glow, {bool small = false}) {
    final w = small ? 32.0 : 46.0;
    final h = small ? 46.0 : 66.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: glow ?? Colors.black12,
          width: glow != null ? 3 : 1,
        ),
        boxShadow: glow != null
            ? [
                BoxShadow(
                    color: glow.withOpacity(0.65), blurRadius: 11, spreadRadius: 2),
              ]
            : const [],
      ),
      alignment: Alignment.center,
      child: Text(
        rank,
        style: TextStyle(
            fontSize: h * 0.42,
            fontWeight: FontWeight.bold,
            color: Colors.black87),
      ),
    );
  }
}
