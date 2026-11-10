import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/playing_card.dart';
import '../settings/app_settings.dart';

class CardWidget extends StatefulWidget {
  final PlayingCard? card;
  final bool faceDown;
  final bool highlighted;
  final VoidCallback? onTap;
  final double width;
  final double height;
  /// Verilirse, AppSettings'teki kayıtlı tema yerine bunu kullanır —
  /// ayarlar ekranında "henüz kaydedilmemiş" bir temayı önizlemek için.
  final CardFaceTheme? themeOverride;
  /// null: geliş animasyonu yok (ör. ayarlar ekranındaki örnek kart).
  /// true: bu kolon "yukarıdaki" satırda — kart yukarıdan gelir gibi
  /// hafifçe kayarak belirir. false: "aşağıdaki" satırda — aşağıdan gelir.
  /// Bu, hangi tarafın (rakip/ben) deste bölgesinden kart geldiği
  /// hissini vermek için kullanılıyor.
  final bool? fromAbove;

  const CardWidget({
    super.key,
    this.card,
    this.faceDown = false,
    this.highlighted = false,
    this.onTap,
    this.width = 64,
    this.height = 92,
    this.themeOverride,
    this.fromAbove,
  });

  @override
  State<CardWidget> createState() => _CardWidgetState();
}

class _CardWidgetState extends State<CardWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _arrivalController;
  late Animation<double> _shake;

  @override
  void initState() {
    super.initState();
    _arrivalController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _setupShake();
  }

  /// Kart kapatıldığında oynanan ÇOK HAFİF, YERİNDE bir titreşim —
  /// kart hiçbir yöne kaymaz/itilmez, sadece "hızlıca kondu" hissi
  /// versin diye küçük bir sallanma yapar.
  void _setupShake() {
    _shake = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.045), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.045, end: -0.03), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.03, end: 0.012), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.012, end: 0.0), weight: 1),
    ]).animate(
        CurvedAnimation(parent: _arrivalController, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(covariant CardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _setupShake();
    // Sadece "zaten açık olan bir kart, BAŞKA bir açık kartla
    // değiştirildiğinde" (yani gerçek bir hamle/kapatma anında) tetiklenir
    // — ilk açılış (reveal) animasyonuyla karışmaması için.
    final wasFaceUp = !oldWidget.faceDown;
    final isFaceUp = !widget.faceDown;
    final cardChanged = widget.card != null &&
        oldWidget.card != null &&
        (oldWidget.card!.suit != widget.card!.suit ||
            oldWidget.card!.rank != widget.card!.rank);
    if (wasFaceUp && isFaceUp && cardChanged && widget.fromAbove != null) {
      _arrivalController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _arrivalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isBack = widget.faceDown || widget.card == null;
    // Kapalıdan açığa geçerken kart yatay eksende "çevrilir".
    final content = AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      transitionBuilder: (child, animation) {
        final angle = Tween<double>(begin: math.pi / 2, end: 0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOut));
        return AnimatedBuilder(
          animation: angle,
          child: child,
          builder: (context, w) => Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle.value),
            child: w,
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey<bool>(isBack),
        child: isBack ? _buildBack() : _buildFace(widget.card!),
      ),
    );

    final highContrast = AppSettings.instance.highContrast;
    // Yüksek kontrast varsayılan açık: aktif kartlar parlak sarı/turkuaz
    // kalın kenarlık + belirgin parıltı ile öne çıkar.
    final highlightColor =
        highContrast ? const Color(0xFFFFEA00) : Colors.amber;
    final borderWidth = widget.highlighted ? (highContrast ? 5.0 : 3.0) : 1.0;

    final cardBody = GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: widget.highlighted ? highlightColor : Colors.black26,
            width: borderWidth,
          ),
          boxShadow: [
            if (widget.highlighted)
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

    if (widget.fromAbove == null) return cardBody;

    return AnimatedBuilder(
      animation: _shake,
      builder: (context, child) =>
          Transform.rotate(angle: _shake.value, child: child),
      child: cardBody,
    );
  }

  Widget _buildBack() {
    final base = AppSettings.instance.cardBackColor;
    final emblemSize = math.min(widget.width, widget.height) * 0.30;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(base, Colors.white, 0.16)!,
            base,
            Color.lerp(base, Colors.black, 0.30)!,
          ],
        ),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
      ),
      child: Padding(
        padding: EdgeInsets.all(widget.width * 0.055),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0x99FFFFFF), width: 0.9),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(painter: _CardBackPatternPainter()),
                Center(
                  child: Container(
                    width: emblemSize * 1.65,
                    height: emblemSize * 1.65,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.10),
                      border: Border.all(color: Colors.white.withOpacity(0.58), width: 1.1),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.16), blurRadius: 8),
                      ],
                    ),
                    child: Icon(Icons.auto_awesome_rounded,
                        color: Colors.white.withOpacity(0.92), size: emblemSize),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Gerçek iskambil kağıtlarına benzeyen tasarım: sol-üst ve (180°
  /// döndürülmüş) sağ-alt köşelerde değer+sembol, ortada seçili temaya
  /// göre bir sembol (klasik iskambil sembolü, meyve, figür ya da tarihi
  /// tema emojisi).
  ///
  /// NOT: Köşe boyutları ve konumları BİLEREK küçük/oransal tutuluyor —
  /// önceki sürümde köşeler sabit piksel offset ile ve nispeten büyük
  /// punto ile konumlandığı için küçük kartlarda köşe metni ile ortadaki
  /// büyük sembol görsel olarak üst üste biniyordu. Şimdi hem köşeler
  /// küçültüldü hem de offset'ler kart boyutuyla orantılı.
  Widget _buildFace(PlayingCard c) {
    final color = c.isRed ? const Color(0xFFBE2638) : const Color(0xFF172235);
    final cornerRankSize = widget.height * 0.155;
    final cornerSuitSize = widget.height * 0.105;
    final theme = widget.themeOverride ?? AppSettings.instance.cardTheme;
    final centerSize = switch (theme) {
      CardFaceTheme.figure => widget.height * 0.40,
      CardFaceTheme.classic => widget.height * 0.30,
      _ => widget.height * 0.36,
    };

    Widget corner() {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(c.rankLabel,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontFamily: 'Roboto',
                fontSize: cornerRankSize,
                height: 0.98,
              )),
          Text(c.suitSymbol,
              style: TextStyle(color: color, fontSize: cornerSuitSize, height: 1.0)),
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFFFFDF7), Color(0xFFF1F0E9)],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD7D9DE), width: 0.9),
        boxShadow: const [
          BoxShadow(color: Color(0x180B1424), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(widget.width * 0.045),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: const Color(0x1C64748B), width: 0.65),
          ),
          child: Stack(
            children: [
              Positioned(
                top: widget.height * 0.018,
                left: widget.width * 0.025,
                child: corner(),
              ),
              Positioned(
                bottom: widget.height * 0.018,
                right: widget.width * 0.025,
                child: Transform.rotate(angle: math.pi, child: corner()),
              ),
              Center(
                child: Container(
                  width: centerSize * 1.42,
                  height: centerSize * 1.42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        color.withOpacity(theme == CardFaceTheme.classic ? 0.09 : 0.13),
                        color.withOpacity(0.025),
                      ],
                    ),
                    border: Border.all(color: color.withOpacity(0.10), width: 0.8),
                  ),
                  child: Center(child: _buildCenterSymbol(c, color, centerSize, theme)),
                ),
              ),
            ],
          ),
        ),
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
        // Renkli emoji beyaz zeminde biraz "havada" duruyor — daha
        // belirgin/canlı bir arka plan dairesi ekleniyor.
        return _emojiWithBackdrop(_emojiForTheme(theme, c.suit), size,
            backdropColor: color.withOpacity(0.10));
      default:
        return _emojiWithBackdrop(_emojiForTheme(theme, c.suit), size,
            backdropColor: color.withOpacity(0.08));
    }
  }

  /// Her tema için 4 takıma (♠♥♦♣) karşılık gelen temsili emoji seti.
  /// NOT: Flutter/Dart'ta özel çizim (illüstrasyon) varlığı üretemediğim
  /// için temalar Unicode emoji ile temsil ediliyor — her biri kendi
  /// motifine en yakın, en canlı emoji ile eşleştirildi.
  String _emojiForTheme(CardFaceTheme theme, Suit s) {
    switch (theme) {
      case CardFaceTheme.classic:
        return '';
      case CardFaceTheme.fruit:
        return _fruitForSuit(s);
      case CardFaceTheme.figure:
        return _figureForSuit(s);
      case CardFaceTheme.ottoman:
        return switch (s) {
          Suit.spades => '⚔️',
          Suit.hearts => '🏹',
          Suit.diamonds => '🛡️',
          Suit.clubs => '🥁',
        };
      case CardFaceTheme.egypt:
        return switch (s) {
          Suit.spades => '👑',
          Suit.hearts => '🐫',
          Suit.diamonds => '🏺',
          Suit.clubs => '🦅',
        };
      case CardFaceTheme.rome:
        return switch (s) {
          Suit.spades => '🏛️',
          Suit.hearts => '⚔️',
          Suit.diamonds => '🦅',
          Suit.clubs => '🍷',
        };
      case CardFaceTheme.animals:
        return switch (s) {
          Suit.spades => '🦁',
          Suit.hearts => '🐯',
          Suit.diamonds => '🦅',
          Suit.clubs => '🐺',
        };
      case CardFaceTheme.chineseZodiac:
        return switch (s) {
          Suit.spades => '🐉',
          Suit.hearts => '🐍',
          Suit.diamonds => '🐯',
          Suit.clubs => '🐰',
        };
      case CardFaceTheme.matryoshka:
        return switch (s) {
          Suit.spades => '🪆',
          Suit.hearts => '🪆',
          Suit.diamonds => '❄️',
          Suit.clubs => '❄️',
        };
      case CardFaceTheme.soviet:
        return switch (s) {
          Suit.spades => '⭐',
          Suit.hearts => '⭐',
          Suit.diamonds => '🏰',
          Suit.clubs => '🏰',
        };
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
  /// emojileri yerine, tam vücut ve daha "gösterişli" duran dans
  /// emojileri kullanılıyor — kırmızı takımlar için parlak elbiseli kadın
  /// dansçı, siyah takımlar için şık takım elbiseli erkek dansçı.
  String _figureForSuit(Suit s) {
    final isRed = s == Suit.hearts || s == Suit.diamonds;
    return isRed ? '💃' : '🕺';
  }
}


/// İnce çapraz çizgiler ve köşe motifleri, kapalı kartın arkasına
/// baskılı oyun kartı hissi verir. Çizim tamamen vektöreldir.
class _CardBackPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Colors.white.withOpacity(0.13)
      ..strokeWidth = 0.65
      ..style = PaintingStyle.stroke;
    final step = math.max(8.0, size.shortestSide * 0.22);
    for (double x = -size.height; x < size.width + size.height; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), line);
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), line);
    }
    final dot = Paint()
      ..color = Colors.white.withOpacity(0.22)
      ..style = PaintingStyle.fill;
    final radius = math.max(0.8, size.shortestSide * 0.018);
    for (final x in [size.width * 0.16, size.width * 0.84]) {
      for (final y in [size.height * 0.12, size.height * 0.88]) {
        canvas.drawCircle(Offset(x, y), radius, dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CardBackPatternPainter oldDelegate) => false;
}
