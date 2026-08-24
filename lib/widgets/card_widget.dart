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
        faceDown || card == null ? _buildBack() : _buildFace(card!, context);

    final highContrast = AppSettings.instance.highContrast;
    final highlightColor = highContrast ? Colors.yellowAccent : Colors.amber;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: highlighted ? highlightColor : Colors.black26,
            width: highlighted ? (highContrast ? 4 : 3) : 1,
          ),
          boxShadow: [
            if (highlighted && highContrast)
              BoxShadow(
                color: highlightColor.withOpacity(0.6),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 3,
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
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Icon(Icons.style, color: Colors.white70, size: 22),
      ),
    );
  }

  Widget _buildFace(PlayingCard c, BuildContext context) {
    final color = c.isRed ? Colors.red.shade700 : Colors.black87;
    final rankFontSize = (height / 92) * 16;
    final suitFontSize = (height / 92) * 24;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            c.rankLabel,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: rankFontSize),
          ),
          Expanded(
            child: Center(
              child: Text(
                c.suitSymbol,
                style: TextStyle(color: color, fontSize: suitFontSize),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
