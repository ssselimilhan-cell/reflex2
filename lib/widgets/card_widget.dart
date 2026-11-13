import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/playing_card.dart';
import '../settings/app_settings.dart';

/// Her kart koleksiyonunun kendi renk kimliği. Klasik destede oyuncunun seçtiği
/// arka plan rengi korunur; koleksiyon desteleri kendi sanat yönetimini kullanır.
class CardThemePalette {
  static Color primary(CardFaceTheme theme) => switch (theme) {
    CardFaceTheme.ottoman => const Color(0xFFE5AE35),
    CardFaceTheme.egypt => const Color(0xFFFFC247),
    CardFaceTheme.rome => const Color(0xFFD88945),
    CardFaceTheme.india => const Color(0xFFFF8A32),
    CardFaceTheme.germany => const Color(0xFFE2B64C),
    CardFaceTheme.france => const Color(0xFFE58AB2),
    CardFaceTheme.japan => const Color(0xFFFF7890),
    CardFaceTheme.persia => const Color(0xFF39BDB0),
    CardFaceTheme.russia => const Color(0xFF6FADEB),
    _ => const Color(0xFFD5B46A),
  };

  static Color background(CardFaceTheme theme) => switch (theme) {
    CardFaceTheme.ottoman => const Color(0xFF102F45),
    CardFaceTheme.egypt => const Color(0xFF123B55),
    CardFaceTheme.rome => const Color(0xFF4B2028),
    CardFaceTheme.india => const Color(0xFF5B241F),
    CardFaceTheme.germany => const Color(0xFF25283B),
    CardFaceTheme.france => const Color(0xFF45213C),
    CardFaceTheme.japan => const Color(0xFF4A1F32),
    CardFaceTheme.persia => const Color(0xFF0E4647),
    CardFaceTheme.russia => const Color(0xFF1C3558),
    _ => const Color(0xFF1E4D8C),
  };
}

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
    // Aktif kartlar oyun masasından net biçimde ayrılan parlak altın sarısı ile vurgulanır.
    const highlightColor = Color(0xFFFFD400);
    final borderWidth = widget.highlighted ? (highContrast ? 4.8 : 3.6) : 1.0;

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
                blurRadius: highContrast ? 22 : 14,
                spreadRadius: highContrast ? 3.5 : 2,
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
    final theme = widget.themeOverride ?? AppSettings.instance.cardTheme;
    final base = theme == CardFaceTheme.classic
        ? AppSettings.instance.cardBackColor
        : CardThemePalette.background(theme);
    final accent = theme == CardFaceTheme.classic
        ? const Color(0xFFE6C77A)
        : CardThemePalette.primary(theme);
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
        border: Border.all(color: accent.withOpacity(0.95), width: 1.5),
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
                CustomPaint(painter: _CardBackPatternPainter(theme: theme)),
                Center(
                  child: Container(
                    width: emblemSize * 1.65,
                    height: emblemSize * 1.65,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withOpacity(0.14),
                      border: Border.all(color: accent.withOpacity(0.88), width: 1.35),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.16), blurRadius: 8),
                      ],
                    ),
                    child: Icon(Icons.auto_awesome_rounded,
                        color: accent.withOpacity(0.98), size: emblemSize),
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
      CardFaceTheme.classic => widget.height * 0.30,
      _ => widget.height * 0.43,
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
                  width: centerSize * 1.68,
                  height: centerSize * 1.68,
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
    if (theme == CardFaceTheme.classic) {
      return Text(c.suitSymbol, style: TextStyle(
        color: color, fontSize: size,
        shadows: [Shadow(color: color.withOpacity(0.25), blurRadius: 2)],
      ));
    }
    if (theme == CardFaceTheme.fruit) {
      return _emojiWithBackdrop(_fruitForSuit(c.suit), size,
          backdropColor: color.withOpacity(0.10));
    }
    return CustomPaint(
      size: Size.square(size * 1.70),
      painter: _CivilizationEmblemPainter(theme: theme, suit: c.suit, ink: color),
    );
  }

  Widget _emojiWithBackdrop(String emoji, double size,
      {required Color backdropColor}) {
    return Stack(alignment: Alignment.center, children: [
      Container(
        width: size * 1.15, height: size * 1.15,
        decoration: BoxDecoration(shape: BoxShape.circle, color: backdropColor),
      ),
      Text(emoji, style: TextStyle(fontSize: size)),
    ]);
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


}


/// Medeniyet temaları için emoji yerine ölçeklenebilir, baskı kalitesinde
/// vektör rozetler. İnsan figürü içermez; her tema kendi mimari/desen dilini taşır.
class _CivilizationEmblemPainter extends CustomPainter {
  final CardFaceTheme theme;
  final Suit suit;
  final Color ink;
  const _CivilizationEmblemPainter({required this.theme, required this.suit, required this.ink});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide * 0.43;
    final gold = _palette();
    final line = Paint()..style = PaintingStyle.stroke..strokeWidth = size.shortestSide * 0.032..strokeCap = StrokeCap.round..color = gold;
    final fill = Paint()..style = PaintingStyle.fill..color = gold.withOpacity(0.22);
    final solid = Paint()..style = PaintingStyle.fill..color = gold;
    final halo = Paint()..shader = RadialGradient(colors:[gold.withOpacity(0.25),gold.withOpacity(0.015)]).createShader(Rect.fromCircle(center:c,radius:r*1.12));
    canvas.drawCircle(c,r*1.10,halo);
    canvas.drawCircle(c, r, line);
    canvas.drawCircle(c, r * 0.88, Paint()..style=PaintingStyle.stroke..strokeWidth=size.shortestSide*0.012..color=gold.withOpacity(.75));
    canvas.drawCircle(c, r * 0.72, fill);
    for(var i=0;i<16;i++){final a=i*math.pi/8;final inner=r*.94;final outer=r*1.08;canvas.drawLine(Offset(c.dx+math.cos(a)*inner,c.dy+math.sin(a)*inner),Offset(c.dx+math.cos(a)*outer,c.dy+math.sin(a)*outer),line);}
    _rosette(canvas,c,r*.48,12,solid,line);
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final p = Offset(c.dx + math.cos(a) * r * 0.91, c.dy + math.sin(a) * r * 0.91);
      canvas.drawCircle(p, r * 0.045, solid);
    }
    switch (theme) {
      case CardFaceTheme.ottoman:
        _crescent(canvas, c, r * 0.52, gold);
        _star(canvas, Offset(c.dx + r * 0.25, c.dy - r * 0.23), r * 0.13, solid);
        _arabesque(canvas, c, r, line);
        break;
      case CardFaceTheme.egypt:
        _sun(canvas, c, r * 0.34, gold);
        final pyramid = Path()..moveTo(c.dx-r*0.52,c.dy+r*0.38)..lineTo(c.dx,c.dy-r*0.34)..lineTo(c.dx+r*0.52,c.dy+r*0.38)..close();
        canvas.drawPath(pyramid, fill); canvas.drawPath(pyramid, line);
        canvas.drawLine(Offset(c.dx,c.dy-r*0.34), Offset(c.dx,c.dy+r*0.38), line);
        break;
      case CardFaceTheme.rome:
        canvas.drawArc(Rect.fromCircle(center:c,radius:r*0.48), math.pi, math.pi, false, line);
        for (var i=-1;i<=1;i++) {
          final x=c.dx+i*r*0.28;
          canvas.drawRect(Rect.fromLTWH(x-r*0.075,c.dy-r*0.05,r*0.15,r*0.48), fill);
          canvas.drawRect(Rect.fromLTWH(x-r*0.075,c.dy-r*0.05,r*0.15,r*0.48), line);
          canvas.drawLine(Offset(x-r*0.12,c.dy-r*0.08),Offset(x+r*0.12,c.dy-r*0.08),line);
        }
        canvas.drawLine(Offset(c.dx-r*0.5,c.dy+r*0.45),Offset(c.dx+r*0.5,c.dy+r*0.45),line);
        break;
      case CardFaceTheme.india:
        _lotus(canvas,c,r*0.58,gold);
        _dotRing(canvas,c,r*0.62,solid,12);
        break;
      case CardFaceTheme.germany:
        final shield=Path()..moveTo(c.dx,c.dy-r*0.48)..lineTo(c.dx+r*0.39,c.dy-r*0.28)..lineTo(c.dx+r*0.31,c.dy+r*0.23)..lineTo(c.dx,c.dy+r*0.48)..lineTo(c.dx-r*0.31,c.dy+r*0.23)..lineTo(c.dx-r*0.39,c.dy-r*0.28)..close();
        canvas.drawPath(shield,fill); canvas.drawPath(shield,line);
        canvas.drawLine(Offset(c.dx,c.dy-r*0.35),Offset(c.dx,c.dy+r*0.35),line);
        canvas.drawLine(Offset(c.dx-r*0.24,c.dy),Offset(c.dx+r*0.24,c.dy),line);
        break;
      case CardFaceTheme.france:
        _fleur(canvas,c,r*0.58,gold);
        break;
      case CardFaceTheme.japan:
        final torii=Path()..moveTo(c.dx-r*0.48,c.dy-r*0.18)..lineTo(c.dx+r*0.48,c.dy-r*0.18)..lineTo(c.dx+r*0.38,c.dy-r*0.30)..lineTo(c.dx-r*0.38,c.dy-r*0.30)..close();
        canvas.drawPath(torii,solid);
        canvas.drawRect(Rect.fromLTWH(c.dx-r*0.30,c.dy-r*0.18,r*0.10,r*0.64),fill);
        canvas.drawRect(Rect.fromLTWH(c.dx+r*0.20,c.dy-r*0.18,r*0.10,r*0.64),fill);
        canvas.drawLine(Offset(c.dx-r*0.42,c.dy+r*0.48),Offset(c.dx+r*0.42,c.dy+r*0.48),line);
        _sakura(canvas,Offset(c.dx,c.dy-r*0.52),r*0.16,gold);
        break;
      case CardFaceTheme.persia:
        _star(canvas,c,r*0.52,solid,8);
        _dotRing(canvas,c,r*0.58,solid,16);
        break;
      case CardFaceTheme.russia:
        _dome(canvas,c,r,gold,line,fill);
        break;
      default:
        _star(canvas,c,r*0.4,solid);
    }
    // Kart takımına göre küçük, dengeli bir alt işaret.
    final suitGlyph = switch (suit) { Suit.spades => '♠', Suit.hearts => '♥', Suit.diamonds => '♦', Suit.clubs => '♣' };
    final tp=TextPainter(text:TextSpan(text:suitGlyph,style:TextStyle(color:ink.withOpacity(0.72),fontSize:size.shortestSide*0.13,fontWeight:FontWeight.w900)),textDirection:TextDirection.ltr)..layout();
    tp.paint(canvas,Offset(c.dx-tp.width/2,c.dy+r*0.53));
  }

  Color _palette() => switch(theme) {
    CardFaceTheme.ottoman => const Color(0xFFFFC247),
    CardFaceTheme.egypt => const Color(0xFFFFD166),
    CardFaceTheme.rome => const Color(0xFFFFA85C),
    CardFaceTheme.india => const Color(0xFFFF8B3D),
    CardFaceTheme.germany => const Color(0xFFFFD166),
    CardFaceTheme.france => const Color(0xFFFF9EC5),
    CardFaceTheme.japan => const Color(0xFFFF8FA3),
    CardFaceTheme.persia => const Color(0xFF54D4C5),
    CardFaceTheme.russia => const Color(0xFF8CC5FF),
    _ => const Color(0xFFB58A35),
  };

  void _crescent(Canvas canvas,Offset c,double r,Color color) {
    final p=Paint()..color=color..style=PaintingStyle.stroke..strokeWidth=r*0.22..strokeCap=StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center:c,radius:r),-math.pi*0.72,math.pi*1.44,false,p);
  }
  void _star(Canvas canvas,Offset c,double r,Paint p,[int points=5]) {
    final path=Path();
    for(var i=0;i<points*2;i++){final a=-math.pi/2+i*math.pi/points;final rr=i.isEven?r:r*0.43;final q=Offset(c.dx+math.cos(a)*rr,c.dy+math.sin(a)*rr);if(i==0)path.moveTo(q.dx,q.dy);else path.lineTo(q.dx,q.dy);}
    path.close();canvas.drawPath(path,p);
  }
  void _sun(Canvas canvas,Offset c,double r,Color color) {
    final p=Paint()..color=color..style=PaintingStyle.stroke..strokeWidth=r*0.12;
    canvas.drawCircle(c,r,p);for(var i=0;i<12;i++){final a=i*math.pi/6;canvas.drawLine(Offset(c.dx+math.cos(a)*r*1.25,c.dy+math.sin(a)*r*1.25),Offset(c.dx+math.cos(a)*r*1.65,c.dy+math.sin(a)*r*1.65),p);}
  }
  void _arabesque(Canvas canvas,Offset c,double r,Paint p) {
    for(var i=0;i<4;i++){final a=i*math.pi/2;final q=Offset(c.dx+math.cos(a)*r*0.48,c.dy+math.sin(a)*r*0.48);canvas.drawCircle(q,r*0.13,p);}
  }
  void _lotus(Canvas canvas,Offset c,double r,Color color) {
    final p=Paint()..color=color..style=PaintingStyle.stroke..strokeWidth=r*0.09;
    for(var i=-2;i<=2;i++){final x=c.dx+i*r*0.19;final path=Path()..moveTo(c.dx,c.dy+r*0.45)..quadraticBezierTo(x-r*0.12,c.dy-r*0.05,x,c.dy-r*(0.72-(i.abs()*0.10)))..quadraticBezierTo(x+r*0.12,c.dy-r*0.05,c.dx,c.dy+r*0.45);canvas.drawPath(path,p);}
  }
  void _fleur(Canvas canvas,Offset c,double r,Color color) {
    final p=Paint()..color=color..style=PaintingStyle.stroke..strokeWidth=r*0.10;
    canvas.drawOval(Rect.fromCenter(center:Offset(c.dx,c.dy-r*0.22),width:r*0.34,height:r*0.58),p);
    canvas.drawOval(Rect.fromCenter(center:Offset(c.dx-r*0.23,c.dy-r*0.02),width:r*0.32,height:r*0.52),p);
    canvas.drawOval(Rect.fromCenter(center:Offset(c.dx+r*0.23,c.dy-r*0.02),width:r*0.32,height:r*0.52),p);
    canvas.drawLine(Offset(c.dx,c.dy+r*0.04),Offset(c.dx,c.dy+r*0.5),p);
    canvas.drawLine(Offset(c.dx-r*0.28,c.dy+r*0.5),Offset(c.dx+r*0.28,c.dy+r*0.5),p);
  }
  void _sakura(Canvas canvas,Offset c,double r,Color color) {
    final p=Paint()..color=color..style=PaintingStyle.fill;
    for(var i=0;i<5;i++){final a=i*math.pi*2/5;canvas.drawCircle(Offset(c.dx+math.cos(a)*r*0.55,c.dy+math.sin(a)*r*0.55),r*0.42,p);}
    canvas.drawCircle(c,r*0.22,Paint()..color=const Color(0xFFE6B95C));
  }
  void _dotRing(Canvas canvas,Offset c,double r,Paint p,int n) {
    for(var i=0;i<n;i++){final a=i*math.pi*2/n;canvas.drawCircle(Offset(c.dx+math.cos(a)*r,c.dy+math.sin(a)*r),r*0.035,p);}
  }
  void _dome(Canvas canvas,Offset c,double r,Color gold,Paint line,Paint fill) {
    for(var i=-1;i<=1;i++){
      final x=c.dx+i*r*0.29;final w=r*0.25;final rect=Rect.fromLTWH(x-w/2,c.dy-r*0.02,w,r*0.42);
      canvas.drawRect(rect,fill);canvas.drawRect(rect,line);
      final dome=Path()..moveTo(x-w/2,c.dy-r*0.02)..quadraticBezierTo(x-w/2,c.dy-r*0.48,x,c.dy-r*0.48)..quadraticBezierTo(x+w/2,c.dy-r*0.48,x+w/2,c.dy-r*0.02)..close();
      canvas.drawPath(dome,fill);canvas.drawPath(dome,line);
      canvas.drawLine(Offset(x,c.dy-r*0.48),Offset(x,c.dy-r*0.62),line);
    }
  }

  void _rosette(Canvas canvas, Offset center, double radius, int points, Paint outer, Paint inner) {
    final path = Path();
    for (var i = 0; i < points * 2; i++) {
      final angle = -math.pi / 2 + i * math.pi / points;
      final distance = i.isEven ? radius : radius * 0.72;
      final point = Offset(center.dx + math.cos(angle) * distance,
          center.dy + math.sin(angle) * distance);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, outer);
    canvas.drawCircle(center, radius * 0.24, inner);
  }

  @override
  bool shouldRepaint(covariant _CivilizationEmblemPainter old) =>
      old.theme != theme || old.suit != suit || old.ink != ink;
}


/// İnce çapraz çizgiler ve köşe motifleri, kapalı kartın arkasına
/// baskılı oyun kartı hissi verir. Çizim tamamen vektöreldir.
class _CardBackPatternPainter extends CustomPainter {
  final CardFaceTheme theme;
  const _CardBackPatternPainter({required this.theme});

  @override
  void paint(Canvas canvas, Size size) {
    final accent = CardThemePalette.primary(theme);
    final center = Offset(size.width / 2, size.height / 2);
    final short = size.shortestSide;
    final thin = Paint()..color = accent.withOpacity(0.30)..style = PaintingStyle.stroke..strokeWidth = math.max(0.65, short * 0.009);
    final bold = Paint()..color = accent.withOpacity(0.72)..style = PaintingStyle.stroke..strokeWidth = math.max(1.0, short * 0.018);
    final soft = Paint()..color = accent.withOpacity(0.12)..style = PaintingStyle.fill;
    final r = short * 0.31;

    // Çift çerçeve ve köşe rozetleri: küçük kartta dahi koleksiyon hissi.
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(short * 0.035, short * 0.035, size.width - short * 0.07, size.height - short * 0.07), Radius.circular(short * 0.045)), thin);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(short * 0.085, short * 0.085, size.width - short * 0.17, size.height - short * 0.17), Radius.circular(short * 0.035)), bold);
    for (final x in [size.width * 0.16, size.width * 0.84]) {
      for (final y in [size.height * 0.12, size.height * 0.88]) {
        canvas.drawCircle(Offset(x, y), short * 0.025, bold);
      }
    }

    switch (theme) {
      case CardFaceTheme.ottoman:
        _rosette(canvas, center, r, 8, bold, thin);
        for (var i = 0; i < 4; i++) {
          final a = i * math.pi / 2;
          final p = Offset(center.dx + math.cos(a) * r * 1.42, center.dy + math.sin(a) * r * 1.42);
          canvas.drawCircle(p, r * 0.22, thin);
          canvas.drawCircle(p, r * 0.08, soft);
        }
        break;
      case CardFaceTheme.egypt:
        _sun(canvas, center, r * 0.43, bold);
        final pyramid = Path()..moveTo(center.dx-r*1.1,center.dy+r*0.72)..lineTo(center.dx,center.dy-r*0.72)..lineTo(center.dx+r*1.1,center.dy+r*0.72)..close();
        canvas.drawPath(pyramid, soft); canvas.drawPath(pyramid, bold);
        canvas.drawLine(Offset(center.dx,center.dy-r*0.72),Offset(center.dx,center.dy+r*0.72),thin);
        break;
      case CardFaceTheme.rome:
        for (var i=-1;i<=1;i++) {
          final x=center.dx+i*r*0.58;
          canvas.drawRect(Rect.fromLTWH(x-r*0.16,center.dy-r*0.25,r*0.32,r*1.25),soft);
          canvas.drawRect(Rect.fromLTWH(x-r*0.16,center.dy-r*0.25,r*0.32,r*1.25),thin);
          canvas.drawLine(Offset(x-r*0.22,center.dy-r*0.3),Offset(x+r*0.22,center.dy-r*0.3),bold);
        }
        canvas.drawArc(Rect.fromCenter(center:Offset(center.dx,center.dy-r*0.15),width:r*2.25,height:r*1.4),math.pi,math.pi,false,bold);
        canvas.drawLine(Offset(center.dx-r*1.1,center.dy+r*1.08),Offset(center.dx+r*1.1,center.dy+r*1.08),bold);
        break;
      case CardFaceTheme.india:
        _rosette(canvas, center, r*0.88, 12, bold, thin);
        for (var i=0;i<8;i++) {
          final a=i*math.pi/4;
          final p=Offset(center.dx+math.cos(a)*r*1.38,center.dy+math.sin(a)*r*1.38);
          canvas.drawOval(Rect.fromCenter(center:p,width:r*0.25,height:r*0.48),thin);
        }
        break;
      case CardFaceTheme.germany:
        for (var i=-2;i<=2;i++) {
          final x=center.dx+i*r*0.42;
          canvas.drawLine(Offset(x,center.dy-r*1.05),Offset(x,center.dy+r*1.05),thin);
        }
        final shield=Path()..moveTo(center.dx,center.dy-r*1.05)..lineTo(center.dx+r*0.85,center.dy-r*0.65)..lineTo(center.dx+r*0.65,center.dy+r*0.55)..lineTo(center.dx,center.dy+r*1.08)..lineTo(center.dx-r*0.65,center.dy+r*0.55)..lineTo(center.dx-r*0.85,center.dy-r*0.65)..close();
        canvas.drawPath(shield,soft); canvas.drawPath(shield,bold);
        break;
      case CardFaceTheme.france:
        canvas.drawArc(Rect.fromCenter(center:center,width:r*2.0,height:r*2.0),math.pi,math.pi,false,bold);
        canvas.drawLine(Offset(center.dx,center.dy-r),Offset(center.dx,center.dy+r),thin);
        _fleur(canvas,center,r*0.72,accent);
        break;
      case CardFaceTheme.japan:
        for (var row=0;row<4;row++) {
          final y=center.dy-r*0.95+row*r*0.62;
          for (var col=-1;col<=1;col++) {
            final x=center.dx+col*r*0.72+(row.isOdd?r*0.36:0);
            canvas.drawArc(Rect.fromCenter(center:Offset(x,y),width:r*0.82,height:r*0.48),math.pi,math.pi,false,thin);
          }
        }
        _sakura(canvas,center,r*0.36,accent);
        break;
      case CardFaceTheme.persia:
        _rosette(canvas,center,r,8,bold,thin);
        _rosette(canvas,center,r*0.55,8,thin,bold);
        for (var i=0;i<8;i++) {
          final a=i*math.pi/4;
          canvas.drawLine(Offset(center.dx+math.cos(a)*r*1.05,center.dy+math.sin(a)*r*1.05),Offset(center.dx+math.cos(a)*r*1.42,center.dy+math.sin(a)*r*1.42),thin);
        }
        break;
      case CardFaceTheme.russia:
        for (var i=-1;i<=1;i++) {
          final x=center.dx+i*r*0.72;
          final dome=Path()..moveTo(x-r*0.32,center.dy+r*0.45)..quadraticBezierTo(x-r*0.32,center.dy-r*0.62,x,center.dy-r*0.62)..quadraticBezierTo(x+r*0.32,center.dy-r*0.62,x+r*0.32,center.dy+r*0.45)..close();
          canvas.drawPath(dome,soft); canvas.drawPath(dome,bold);
          canvas.drawLine(Offset(x,center.dy-r*0.62),Offset(x,center.dy-r*0.86),thin);
        }
        canvas.drawLine(Offset(center.dx-r*1.15,center.dy+r*0.48),Offset(center.dx+r*1.15,center.dy+r*0.48),bold);
        break;
      default:
        _rosette(canvas,center,r,8,bold,thin);
    }
  }

  void _rosette(Canvas canvas, Offset c, double r, int points, Paint outer, Paint inner) {
    final path=Path();
    for(var i=0;i<points*2;i++) {
      final a=-math.pi/2+i*math.pi/points;
      final rr=i.isEven?r:r*0.68;
      final p=Offset(c.dx+math.cos(a)*rr,c.dy+math.sin(a)*rr);
      if(i==0) path.moveTo(p.dx,p.dy); else path.lineTo(p.dx,p.dy);
    }
    path.close(); canvas.drawPath(path,outer);
    canvas.drawCircle(c,r*0.24,inner);
  }

  void _sun(Canvas canvas, Offset c, double r, Paint p) {
    canvas.drawCircle(c,r,p);
    for(var i=0;i<16;i++) {
      final a=i*math.pi/8;
      canvas.drawLine(Offset(c.dx+math.cos(a)*r*1.25,c.dy+math.sin(a)*r*1.25),Offset(c.dx+math.cos(a)*r*1.65,c.dy+math.sin(a)*r*1.65),p);
    }
  }

  void _fleur(Canvas canvas, Offset c, double r, Color color) {
    final p=Paint()..color=color.withOpacity(0.9)..style=PaintingStyle.stroke..strokeWidth=r*0.10;
    for(final dx in [-0.32,0.0,0.32]) {
      canvas.drawOval(Rect.fromCenter(center:Offset(c.dx+dx*r,c.dy-r*0.18),width:r*0.34,height:r*0.72),p);
    }
    canvas.drawLine(Offset(c.dx,c.dy+r*0.1),Offset(c.dx,c.dy+r*0.72),p);
    canvas.drawLine(Offset(c.dx-r*0.42,c.dy+r*0.65),Offset(c.dx+r*0.42,c.dy+r*0.65),p);
  }

  void _sakura(Canvas canvas, Offset c, double r, Color color) {
    final p=Paint()..color=color.withOpacity(0.92);
    for(var i=0;i<5;i++) {
      final a=i*math.pi*2/5-math.pi/2;
      canvas.drawOval(Rect.fromCenter(center:Offset(c.dx+math.cos(a)*r*0.55,c.dy+math.sin(a)*r*0.55),width:r*0.72,height:r*0.72),p);
    }
    canvas.drawCircle(c,r*0.2,Paint()..color=const Color(0xFFFFD77A));
  }

  @override
  bool shouldRepaint(covariant _CardBackPatternPainter oldDelegate) => oldDelegate.theme != theme;
}
