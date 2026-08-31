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
  /// döndürülmüş) sağ-alt köşelerde değer+sembol, ortada seçili temaya
  /// göre bir sembol (klasik iskambil sembolü, meyve ya da figür emojisi).
  ///
  /// NOT: Köşe boyutları ve konumları BİLEREK küçük/oransal tutuluyor —
  /// önceki sürümde köşeler sabit piksel (4-5px) offset ile ve nispeten
  /// büyük punto ile konumlandığı için, küçük kartlarda (ör. aynı cihazda
  /// 2 kişilik moddaki çift pano) köşe metni ile ortadaki büyük sembol
  /// görsel olarak üst üste biniyordu ("iki farklı ikon" hatası). Şimdi
  /// hem köşeler küçültüldü hem de offset'ler kart boyutuyla orantılı.
  Widget _buildFace(PlayingCard c) {
    final color = c.isRed ? Colors.red.shade700 : Colors.black87;
    final cornerRankSize = height * 0.16;
    final cornerSuitSize = height * 0.11;
    final theme = AppSettings.instance.cardTheme;
    final centerSize = theme == CardFaceTheme.figure
        ? height * 0.40 // "boydan" figür isteği için daha büyük/baskın
        : height * 0.30;

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
          Positioned(
            top: height * 0.035,
            left: width * 0.07,
            child: corner(),
          ),
          Positioned(
            bottom: height * 0.035,
            right: width * 0.07,
            child: Transform.rotate(angle: math.pi, child: corner()),
          ),
          Center(child: _buildCenterSymbol(c, color, centerSize, theme)),
        ],
      ),
    );
  }

  Widget _buildCenterSymbol(
      PlayingCard c, Color color, double size, CardFaceTheme theme) {
    switch (theme) {
      case CardFaceTheme.classic:
        return Text(
          c.suitSymbol,
          style: TextStyle(
            color: color,
            fontSize: size,
            shadows: [
              Shadow(
                  color: color.withOpacity(0.25),
                  blurRadius: 2,
                  offset: const Offset(0.5, 0.5)),
            ],
          ),
        );
      case CardFaceTheme.fruit:
        // Renkli emoji beyaz zeminde biraz "havada" duruyor — hafif bir
        // arka plan dairesi estetik/görünürlük için ekleniyor.
        return _emojiWithBackdrop(_fruitForSuit(c.suit), size,
            backdropColor: color.withOpacity(0.06));
      case CardFaceTheme.figure:
        return _emojiWithBackdrop(_figureForSuit(c.suit), size,
            backdropColor: color.withOpacity(0.08));
    }
  }

  /// Emojinin altına, kartla aynı renk tonunda hafif bir daire koyarak
  /// hem estetik bir "sahne" etkisi verir hem de emoji ile arka plan
  /// arasındaki kontrastı artırır.
  Widget _emojiWithBackdrop(String emoji, double size,
      {required Color backdropColor}) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: size * 1.15,
          height: size * 1.15,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: backdropColor,
          ),
        ),
        Text(emoji, style: TextStyle(fontSize: size)),
      ],
    );
  }

  String _fruitForSuit(Suit s) {
    switch (s) {
      case Suit.spades:
        return '🍇';
      case Suit.hearts:
        return '🍓';
      case Suit.diamonds:
        return '🍊';
      case Suit.clubs:
        return '🍒';
    }
  }

  /// "Boydan" ve daha iddialı/hareketli figürler için: statik yüz
  /// emojileri (👧👦) yerine, tam vücut ve daha "gösterişli" duran dans
  /// emojileri kullanılıyor — kırmızı takımlar (kupa/karo) için parlak
  /// elbiseli kadın dansçı, siyah takımlar (maça/sinek) için şık takım
  /// elbiseli erkek dansçı.
  String _figureForSuit(Suit s) {
    final isRed = s == Suit.hearts || s == Suit.diamonds;
    return isRed ? '💃' : '🕺';
  }
}
