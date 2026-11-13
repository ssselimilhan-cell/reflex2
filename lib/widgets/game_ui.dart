import 'package:flutter/material.dart';
import '../settings/strings.dart';
import 'table_felt.dart';

/// STRES tasarım sistemi: altın vurgu, kadife zemin, cam yüzeyler ve
/// "Russo One" başlık yazı tipi. Ana ekran, harita, sonuç kutuları ve
/// ayarlar aynı bileşenleri kullanır, böylece oyun tek bir bütün gibi durur.
class GameUi {
  static const String displayFont = 'RussoOne';

  // Modern competitive palette. Existing aliases remain stable so this
  // foundation can be adopted screen-by-screen without changing game logic.
  static const Color background = Color(0xFFFF5A1F);
  static const Color surface = Color(0xFF1B293D);
  static const Color primary = Color(0xFFFFB000);
  static const Color cyan = Color(0xFFFFE08A);
  static const Color rewardGold = Color(0xFFFBBF24);

  static const Color gold = Color(0xFFFFD23F);
  static const Color goldLight = Color(0xFFFFE08A);
  static const Color goldDeep = Color(0xFFD9961A);
  static const Color goldEdge = Color(0xFF8F5B0A);
  static const Color ink = Color(0xFF1A1208);

  /// Fits a compact label without ever breaking a word across lines.
  /// The parent should provide enough width; if not, the complete label scales
  /// down as one unit instead of splitting a word (independent of locale).
  static Widget fitLabel(String value, {TextStyle? style, int maxLines = 1}) {
    return LayoutBuilder(builder: (context, constraints) {
      final maxWidth = constraints.hasBoundedWidth ? constraints.maxWidth : 480.0;
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Text(value, maxLines: 1, softWrap: false,
            textAlign: TextAlign.center, overflow: TextOverflow.visible, style: style),
        ),
      );
    });
  }

  static const Color glass = Color(0x40000000);
  static const Color hairline = Color(0x24FFFFFF);

  /// Başlık, düğme ve büyük sayılar için yazı stili.
  static TextStyle display(double size,
      {Color color = Colors.white, double spacing = 0.4}) {
    return TextStyle(
      fontFamily: displayFont,
      fontSize: size,
      color: color,
      letterSpacing: spacing,
      height: 1.1,
    );
  }
}

/// Tema renginden türetilen kadife zemin: ortası biraz açık, kenarları koyu;
/// üstüne [TableFelt] dokusu biner.
class FeltBackground extends StatelessWidget {
  final Color base;
  const FeltBackground({super.key, required this.base});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.35),
              radius: 1.15,
              colors: [
                Color.lerp(base, Colors.white, 0.10)!,
                base,
                Color.lerp(base, Colors.black, 0.6)!,
              ],
              stops: const [0.0, 0.55, 1.0],
            ),
          ),
        ),
        const TableFelt(),
      ],
    );
  }
}

/// Ana eylem düğmesi: altın, hafif parlak, basınca aşağı çöker.
/// [pulse] açıksa ışıltısı nefes alır gibi yanıp söner.
class GamePrimaryButton extends StatefulWidget {
  final String label;
  final String? subtitle;
  final IconData? icon;
  final VoidCallback onTap;
  final double height;
  final bool pulse;

  const GamePrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.icon,
    this.height = 60,
    this.pulse = false,
  });

  @override
  State<GamePrimaryButton> createState() => _GamePrimaryButtonState();
}

class _GamePrimaryButtonState extends State<GamePrimaryButton>
    with SingleTickerProviderStateMixin {
  bool _down = false;
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.pulse) _pulse.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) {
            final glow = widget.pulse ? 0.18 + 0.24 * _pulse.value : 0.18;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 80),
              transform: Matrix4.translationValues(0, _down ? 3 : 0, 0),
              height: widget.height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [GameUi.goldLight, GameUi.primary, GameUi.goldDeep],
                ),
                border: Border.all(color: GameUi.goldLight, width: 1.4),
                boxShadow: [
                  BoxShadow(
                      color: GameUi.goldEdge,
                      offset: Offset(0, _down ? 1 : 4)),
                  BoxShadow(
                      color: GameUi.cyan.withOpacity(glow),
                      blurRadius: 22,
                      spreadRadius: 1),
                ],
              ),
              child: child,
            );
          },
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: FractionallySizedBox(
                  heightFactor: 0.5,
                  widthFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(16)),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x59FFFFFF), Color(0x00FFFFFF)],
                      ),
                    ),
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(widget.icon, color: GameUi.ink, size: 28),
                          const SizedBox(width: 10),
                        ],
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(widget.label,
                                maxLines: 1,
                                style: GameUi.display(22, color: GameUi.ink)),
                            if (widget.subtitle != null)
                              Text(widget.subtitle!,
                                  maxLines: 1,
                                  style: const TextStyle(
                                      color: Color(0xDD1A1208),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cam görünümlü menü kutusu: renkli ikon rozeti, başlık, alt metin ve
/// isteğe bağlı alt bileşen (ilerleme çubuğu gibi).
class GameTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
  final Widget? footer;

  const GameTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xCC1B293D), Color(0xB3101827)],
          ),
          border: Border.all(color: GameUi.hairline),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [accent, Color.lerp(accent, Colors.black, 0.35)!],
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: accent.withOpacity(0.38), blurRadius: 14),
                    ],
                  ),
                  child: Icon(icon, color: GameUi.ink, size: 26),
                ),
                const SizedBox(height: 10),
                Text(title,
                    maxLines: 3,
                    softWrap: true,
                    overflow: TextOverflow.visible,
                    style: GameUi.display(16)),
                const SizedBox(height: 3),
                Text(subtitle,
                    maxLines: 3,
                    softWrap: true,
                    overflow: TextOverflow.visible,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 14, height: 1.3)),
                if (footer != null) ...[
                  const SizedBox(height: 10),
                  footer!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Küçük bilgi hapı (yıldız sayısı gibi).
class GamePill extends StatelessWidget {
  final Widget leading;
  final String text;
  final VoidCallback? onTap;

  const GamePill({super.key, required this.leading, required this.text, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: GameUi.glass,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: GameUi.hairline),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                leading,
                const SizedBox(width: 6),
                Text(text, style: GameUi.display(15)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Yuvarlak cam simge düğmesi (ayarlar gibi).
class GameIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  const GameIconButton(
      {super.key, required this.icon, required this.onTap, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: GameUi.glass,
            shape: BoxShape.circle,
            border: Border.all(color: GameUi.hairline),
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Icon(icon, color: Colors.white, size: 26),
          ),
        ),
      ),
    );
  }
}

/// STRES yazı logosu: altın degrade + yumuşak gölge, altında slogan.
class GameLogo extends StatelessWidget {
  const GameLogo({super.key});

  @override
  Widget build(BuildContext context) {
    final style = GameUi.display(68, spacing: 8);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Stack(
            children: [
              Transform.translate(
                offset: const Offset(0, 4),
                child: Text(t('app_title'),
                    style: style.copyWith(color: const Color(0x99000000))),
              ),
              ShaderMask(
                shaderCallback: (rect) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white, GameUi.cyan, GameUi.primary],
                ).createShader(rect),
                blendMode: BlendMode.srcIn,
                child: Text(t('app_title'), style: style),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(t('app_subtitle'),
            textAlign: TextAlign.center,
            style: GameUi.display(13, color: Colors.white70, spacing: 3)),
      ],
    );
  }
}

/// Ekrandaki öğeleri sırayla yumuşakça içeri alır (ilk açılışta bir kez).
class Reveal extends StatelessWidget {
  final int index;
  final Widget child;

  const Reveal({super.key, required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 380 + index * 90),
      curve: Curves.easeOutCubic,
      builder: (context, v, ch) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * 16), child: ch),
      ),
      child: child,
    );
  }
}
