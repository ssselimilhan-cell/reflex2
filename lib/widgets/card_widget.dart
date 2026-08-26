import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/playing_card.dart';
import '../settings/app_settings.dart';

class CardWidget extends StatelessWidget {
  final PlayingCard? card;
  final bool faceDown;
  final bool highlighted;
  final VoidCallback? onTap;
  final double width;
  final double height;

  const CardWidget({
    super.key,
    this.card,
    this.faceDown = false,
    this.highlighted = false,
    this.onTap,
    this.width = 64,
    this.height = 92,
  });

  @override
  Widget build(BuildContext context) {
    final content =
        faceDown || card == null ? _buildBack() : _buildFace(card!);

    final highContrast = AppSettings.instance.highContrast;
    // Yüksek kontrast varsayılan açık: aktif kartlar parlak sarı/turkuaz
    // kalın kenarlık + belirgin parıltı ile öne çıkar.
    final highlightColor =
        highContrast ? const Color(0xFFFFEA00) : Colors.amber;
    final borderWidth = highlighted ? (highContrast ? 5.0 : 3.0) : 1.0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: highlighted ? highlightColor : Colors.black26,
            width: borderWidth,
          ),
          boxShadow: [
            if (highlighted)
              BoxShadow(
                color: highlightColor.withOpacity(highContrast ? 0.85 : 0.5),
                blurRadius: highContrast ? 14 : 8,
                spreadRadius: highContrast ? 2.5 : 1,
              ),
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(1, 2),
            ),
          ],
        ),
        child: content,
      ),
    );
  }

  Widget _buildBack() {
    return Container(
      decoration: BoxDecoration(
        color: AppSettings.instance.cardBackColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24, width: 1.5),
      ),
      child: Center(
        child: Container(
          width: width * 0.6,
          height: height * 0.7,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white38, width: 1),
          ),
          child: Icon(Icons.style,
              color: Colors.white54, size: math.min(width, height) * 0.32),
        ),
      ),
    );
  }

  /// Gerçek iskambil kağıtlarına benzeyen tasarım: sol-üst ve (180°
  /// döndürülmüş) sağ-alt köşelerde küçük değer+sembol, ortada büyük,
  /// baskın bir sembol.
  Widget _buildFace(PlayingCard c) {
    final color = c.isRed ? Colors.red.shade700 : Colors.black87;
    final cornerRankSize = height * 0.19;
    final cornerSuitSize = height * 0.14;
    final centerSuitSize = height * 0.50;

    Widget corner() {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            c.rankLabel,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: cornerRankSize,
              height: 1.0,
            ),
          ),
          Text(
            c.suitSymbol,
            style: TextStyle(color: color, fontSize: cornerSuitSize, height: 1.0),
          ),
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12, width: 1),
      ),
      child: Stack(
        children: [
          Positioned(top: 4, left: 5, child: corner()),
          Positioned(
            bottom: 4,
            right: 5,
            child: Transform.rotate(angle: math.pi, child: corner()),
          ),
          Center(
            child: Text(
              c.suitSymbol,
              style: TextStyle(
                color: color,
                fontSize: centerSuitSize,
                shadows: [
                  Shadow(
                      color: color.withOpacity(0.25),
                      blurRadius: 2,
                      offset: const Offset(0.5, 0.5)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
