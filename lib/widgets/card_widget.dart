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
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _arrivalController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _setupSlide();
  }

  void _setupSlide() {
    final dy = widget.fromAbove == true
        ? -0.45
        : (widget.fromAbove == false ? 0.45 : 0.0);
    _slide = Tween<Offset>(begin: Offset(0, dy), end: Offset.zero).animate(
      CurvedAnimation(parent: _arrivalController, curve: Curves.easeOutBack),
    );
  }

  @override
  void didUpdateWidget(covariant CardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _setupSlide();
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
    final content = widget.faceDown || widget.card == null
        ? _buildBack()
        : _buildFace(widget.card!);

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

    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.4, end: 1.0).animate(_arrivalController),
        child: cardBody,
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
          width: widget.width * 0.6,
          height: widget.height * 0.7,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white38, width: 1),
          ),
          child: Icon(Icons.style,
              color: Colors.white54,
              size: math.min(widget.width, widget.height) * 0.32),
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
    final color = c.isRed ? Colors.red.shade700 : Colors.black87;
    final cornerRankSize = widget.height * 0.16;
    final cornerSuitSize = widget.height * 0.11;
    final theme = widget.themeOverride ?? AppSettings.instance.cardTheme;
    final centerSize = switch (theme) {
      CardFaceTheme.figure => widget.height * 0.40, // "boydan" figür — en baskın
      CardFaceTheme.classic => widget.height * 0.30, // köşelerle dengeli kalsın
      _ => widget.height * 0.36, // diğer temalar daha canlı/büyük
    };

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
            style:
                TextStyle(color: color, fontSize: cornerSuitSize, height: 1.0),
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
            top: widget.height * 0.035,
            left: widget.width * 0.07,
            child: corner(),
          ),
          Positioned(
            bottom: widget.height * 0.035,
            right: widget.width * 0.07,
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
