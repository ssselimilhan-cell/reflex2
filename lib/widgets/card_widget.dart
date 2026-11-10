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
      size: Size.square(size * 1.48),
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
    final line = Paint()..style = PaintingStyle.stroke..strokeWidth = size.shortestSide * 0.025..color = gold;
    final fill = Paint()..style = PaintingStyle.fill..color = gold.withOpacity(0.13);
    final solid = Paint()..style = PaintingStyle.fill..color = gold;
    canvas.drawCircle(c, r, line);
    canvas.drawCircle(c, r * 0.83, line..strokeWidth *= 0.55);
    canvas.drawCircle(c, r * 0.68, fill);
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final p = Offset(c.dx + math.cos(a) * r * 0.91, c.dy + math.sin(a) * r * 0.91);
      canvas.drawCircle(p, r * 0.045, solid);
    }
    switch (theme) {
      case CardFaceTheme.ottoman:
        _crescent(canvas, c, r * 0.40, gold);
        _star(canvas, Offset(c.dx + r * 0.25, c.dy - r * 0.23), r * 0.13, solid);
        _arabesque(canvas, c, r, line);
        break;
      case CardFaceTheme.egypt:
        _sun(canvas, c, r * 0.26, gold);
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
        _lotus(canvas,c,r*0.48,gold);
        _dotRing(canvas,c,r*0.62,solid,12);
        break;
      case CardFaceTheme.germany:
        final shield=Path()..moveTo(c.dx,c.dy-r*0.48)..lineTo(c.dx+r*0.39,c.dy-r*0.28)..lineTo(c.dx+r*0.31,c.dy+r*0.23)..lineTo(c.dx,c.dy+r*0.48)..lineTo(c.dx-r*0.31,c.dy+r*0.23)..lineTo(c.dx-r*0.39,c.dy-r*0.28)..close();
        canvas.drawPath(shield,fill); canvas.drawPath(shield,line);
        canvas.drawLine(Offset(c.dx,c.dy-r*0.35),Offset(c.dx,c.dy+r*0.35),line);
        canvas.drawLine(Offset(c.dx-r*0.24,c.dy),Offset(c.dx+r*0.24,c.dy),line);
        break;
      case CardFaceTheme.france:
        _fleur(canvas,c,r*0.48,gold);
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
        _star(canvas,c,r*0.42,solid,8);
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
    CardFaceTheme.ottoman => const Color(0xFFB58A35),
    CardFaceTheme.egypt => const Color(0xFFB78B28),
    CardFaceTheme.rome => const Color(0xFF9A6A38),
    CardFaceTheme.india => const Color(0xFFB56B35),
    CardFaceTheme.germany => const Color(0xFF9B783F),
    CardFaceTheme.france => const Color(0xFF9D6B8C),
    CardFaceTheme.japan => const Color(0xFFB45C58),
    CardFaceTheme.persia => const Color(0xFF348B83),
    CardFaceTheme.russia => const Color(0xFF527A9B),
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

  @override
  bool shouldRepaint(covariant _CivilizationEmblemPainter old) =>
      old.theme != theme || old.suit != suit || old.ink != ink;
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
