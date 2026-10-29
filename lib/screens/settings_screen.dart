import 'package:flutter/material.dart';
import '../settings/app_settings.dart';
import '../settings/strings.dart';
import '../settings/moderation.dart';
import '../settings/share_helper.dart';
import '../settings/feedback.dart';
import '../settings/telemetry.dart';
import '../models/playing_card.dart';
import '../widgets/card_widget.dart';

// Tasarım dili: kullanıcının seçtiği tema rengi zemin olarak kalır; gruplar
// yarı saydam koyu paneller, ince çizgilerle ayrılan satırlar. Vurgu rengi
// (amber) yalnızca "açık/seçili" durumlarda kullanılır.
const Color _panelColor = Color(0x40000000);
const Color _hairline = Color(0x1FFFFFFF);
const Color _chipFill = Color(0x24FFFFFF);
const PlayingCard _demoCard = PlayingCard(Suit.hearts, 7);

const TextStyle _titleStyle =
    TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500);

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;
    return AnimatedBuilder(
      animation: Listenable.merge([settings, Moderation.instance]),
      builder: (context, _) {
        return Scaffold(
          backgroundColor: settings.themeColor,
          appBar: AppBar(title: Text(t('settings_title'))),
          body: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    _CardPreview(
                      scale: settings.cardScale,
                      theme: settings.cardTheme,
                      tableColor: settings.themeColor,
                    ),
                    const SizedBox(height: 20),
                    _Group(
                      title: t('settings_group_cards'),
                      children: [
                        _CardDesignRow(),
                        _SettingRow(
                          icon: Icons.flip,
                          title: t('settings_card_back'),
                          belowPadding: const EdgeInsets.fromLTRB(58, 12, 14, 0),
                          below: _SwatchRow(
                            colors: AppSettings.cardBackPresets,
                            selected: settings.cardBackColor,
                            onPick: settings.setCardBackColor,
                          ),
                        ),
                        _SettingRow(
                          icon: Icons.aspect_ratio,
                          title: t('settings_card_size'),
                          trailing:
                              _ValuePill('${(settings.cardScale * 100).round()}%'),
                          belowPadding: const EdgeInsets.only(top: 4),
                          below: _StyledSlider(
                            value: settings.cardScale,
                            min: 0.7,
                            max: 2.0,
                            divisions: 13,
                            onChanged: settings.setCardScale,
                          ),
                        ),
                      ],
                    ),
                    _Group(
                      title: t('settings_group_look'),
                      children: [
                        _SettingRow(
                          icon: Icons.palette_outlined,
                          title: t('settings_color'),
                          belowPadding: const EdgeInsets.fromLTRB(58, 12, 14, 0),
                          below: _SwatchRow(
                            colors: AppSettings.presetColors,
                            selected: settings.themeColor,
                            onPick: settings.setThemeColor,
                          ),
                        ),
                        _SettingRow(
                          icon: Icons.text_fields,
                          title: t('settings_font_size'),
                          trailing:
                              _ValuePill('${(settings.fontScale * 100).round()}%'),
                          belowPadding: const EdgeInsets.only(top: 4),
                          below: _StyledSlider(
                            value: settings.fontScale,
                            min: 0.8,
                            max: 1.6,
                            divisions: 8,
                            onChanged: settings.setFontScale,
                          ),
                        ),
                        _switchRow(
                          icon: Icons.contrast,
                          title: t('settings_high_contrast'),
                          value: settings.highContrast,
                          onChanged: settings.setHighContrast,
                        ),
                        _SettingRow(
                          icon: Icons.language,
                          title: t('settings_language'),
                          trailing: _ValueWithChevron(
                              _languageName(settings.language)),
                          onTap: () => _pickLanguage(context),
                        ),
                      ],
                    ),
                    _Group(
                      title: t('settings_group_game'),
                      children: [
                        _SettingRow(
                          icon: Icons.speed,
                          title: t('settings_animation_speed'),
                          below: _Segmented<double>(
                            values: const [0.5, 1.0, 1.6],
                            labels: [
                              t('speed_fast'),
                              t('speed_normal'),
                              t('speed_slow'),
                            ],
                            selected: settings.animationSpeed,
                            onChanged: settings.setAnimationSpeed,
                          ),
                        ),
                        _switchRow(
                          icon: Icons.tips_and_updates_outlined,
                          title: t('assisted_mode'),
                          value: settings.assistedMode,
                          onChanged: settings.setAssistedMode,
                        ),
                      ],
                    ),
                    _Group(
                      title: t('settings_group_audio'),
                      children: [
                        _switchRow(
                          icon: Icons.volume_up_outlined,
                          title: t('settings_sound'),
                          value: settings.soundEnabled,
                          onChanged: settings.setSoundEnabled,
                        ),
                        _switchRow(
                          icon: Icons.vibration,
                          title: t('settings_haptics'),
                          value: settings.hapticsEnabled,
                          onChanged: settings.setHapticsEnabled,
                        ),
                      ],
                    ),
                    _Group(
                      title: t('settings_group_privacy'),
                      children: [
                        _switchRow(
                          icon: Icons.analytics_outlined,
                          title: t('settings_telemetry'),
                          value: settings.telemetryEnabled,
                          onChanged: settings.setTelemetryEnabled,
                        ),
                        _SettingRow(
                          icon: Icons.block,
                          title: t('blocked_players'),
                          trailing: _ValueWithChevron(
                              '${Moderation.instance.blocked.length}'),
                          onTap: () => showBlockedPlayersDialog(context),
                        ),
                      ],
                    ),
                    _Group(
                      title: t('settings_group_support'),
                      children: [
                        _SettingRow(
                          icon: Icons.share_outlined,
                          title: t('invite_friends'),
                          onTap: shareApp,
                        ),
                        _SettingRow(
                          icon: Icons.star_border_rounded,
                          title: t('rate_app'),
                          onTap: openStoreReview,
                        ),
                        _SettingRow(
                          icon: Icons.chat_bubble_outline,
                          title: t('feedback_title'),
                          onTap: () => showFeedbackDialog(context),
                        ),
                      ],
                    ),
                    Center(
                      child: Text(
                        '${t('app_title')} ${Telemetry.appVersion}',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

String _languageName(AppLanguage lang) {
  switch (lang) {
    case AppLanguage.tr:
      return 'Türkçe';
    case AppLanguage.en:
      return 'English';
    case AppLanguage.ru:
      return 'Русский';
    case AppLanguage.zh:
      return '中文';
  }
}

Future<void> _pickLanguage(BuildContext context) {
  final settings = AppSettings.instance;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Color.lerp(settings.themeColor, Colors.black, 0.55),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          for (final lang in AppLanguage.values)
            ListTile(
              title: Text(_languageName(lang), style: _titleStyle),
              trailing: settings.language == lang
                  ? const Icon(Icons.check, color: Colors.amber)
                  : null,
              onTap: () {
                settings.setLanguage(lang);
                Navigator.pop(sheetContext);
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// Açık/kapalı satırı: satırın tamamı dokunulabilir.
Widget _switchRow({
  required IconData icon,
  required String title,
  required bool value,
  required ValueChanged<bool> onChanged,
}) {
  return _SettingRow(
    icon: icon,
    title: title,
    onTap: () => onChanged(!value),
    trailing: Switch(
      value: value,
      onChanged: onChanged,
      thumbColor: WidgetStateProperty.resolveWith<Color>(
        (states) => states.contains(WidgetState.selected)
            ? Colors.white
            : Colors.white70,
      ),
      trackColor: WidgetStateProperty.resolveWith<Color>(
        (states) => states.contains(WidgetState.selected)
            ? Colors.amber
            : const Color(0x33FFFFFF),
      ),
      trackOutlineColor:
          const WidgetStatePropertyAll<Color>(Colors.transparent),
    ),
  );
}

/// Üstteki canlı önizleme: kart tasarımı, arka yüz rengi ve boyut anında
/// görünür. Yükseklik sabit, böylece slider sürüklenirken sayfa kaymaz.
class _CardPreview extends StatelessWidget {
  final double scale;
  final CardFaceTheme theme;
  final Color tableColor;

  const _CardPreview(
      {required this.scale, required this.theme, required this.tableColor});

  @override
  Widget build(BuildContext context) {
    final s = (scale > 2.2 ? 2.2 : scale) * 0.75;
    final w = 64 * s;
    final h = 92 * s;
    return Container(
      height: 184,
      decoration: BoxDecoration(
        color: Color.lerp(tableColor, Colors.black, 0.28),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _hairline),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.translate(
            offset: Offset(-w * 0.38, 0),
            child: Transform.rotate(
              angle: -0.09,
              child: CardWidget(
                  card: _demoCard, faceDown: true, width: w, height: h),
            ),
          ),
          Transform.translate(
            offset: Offset(w * 0.38, 0),
            child: Transform.rotate(
              angle: 0.07,
              child: CardWidget(
                  card: _demoCard,
                  themeOverride: theme,
                  width: w,
                  height: h),
            ),
          ),
        ],
      ),
    );
  }
}

/// Başlık + yuvarlatılmış panel; satırlar ince çizgilerle ayrılır.
class _Group extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Group({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(const Padding(
          padding: EdgeInsets.only(left: 58),
          child: Divider(height: 1, thickness: 1, color: _hairline),
        ));
      }
      rows.add(children[i]);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              title,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600),
            ),
          ),
          Material(
            color: _panelColor,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: _hairline),
            ),
            child: Column(children: rows),
          ),
        ],
      ),
    );
  }
}

/// Tek ayar satırı: simge, başlık, sağda isteğe bağlı değer/anahtar ve
/// altta isteğe bağlı kontrol (slider, renk seçici...).
class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final Widget? below;
  final EdgeInsets belowPadding;
  final VoidCallback? onTap;

  const _SettingRow({
    required this.icon,
    required this.title,
    this.trailing,
    this.below,
    this.belowPadding = const EdgeInsets.fromLTRB(14, 10, 14, 0),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _chipFill,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(icon, size: 18, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(title, style: _titleStyle)),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    trailing!,
                  ],
                ],
              ),
            ),
            if (below != null)
              Padding(
                padding: belowPadding,
                child: Align(alignment: Alignment.centerLeft, child: below!),
              ),
          ],
        ),
      ),
    );
  }
}

class _ValuePill extends StatelessWidget {
  final String text;
  const _ValuePill(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _chipFill,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
            color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ValueWithChevron extends StatelessWidget {
  final String text;
  const _ValueWithChevron(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text,
            style: const TextStyle(color: Colors.white70, fontSize: 15)),
        const SizedBox(width: 2),
        const Icon(Icons.chevron_right, color: Colors.white54, size: 22),
      ],
    );
  }
}

/// Zeminle aynı tonda kalmayan, okunaklı slider (amber iz, beyaz tutamaç).
class _StyledSlider extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  const _StyledSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 4,
        activeTrackColor: Colors.amber,
        inactiveTrackColor: const Color(0x33FFFFFF),
        thumbColor: Colors.white,
        overlayColor: const Color(0x29FFC107),
        activeTickMarkColor: Colors.transparent,
        inactiveTickMarkColor: Colors.transparent,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
      ),
      child: SizedBox(
        width: double.infinity,
        child: Slider(
          value: value.clamp(min, max).toDouble(),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _SwatchRow extends StatelessWidget {
  final List<Color> colors;
  final Color selected;
  final ValueChanged<Color> onPick;

  const _SwatchRow(
      {required this.colors, required this.selected, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final c in colors)
          _Swatch(color: c, selected: c == selected, onTap: () => onPick(c)),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _Swatch(
      {required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final light = ThemeData.estimateBrightnessForColor(color) == Brightness.light;
    return Semantics(
      button: true,
      selected: selected,
      child: InkResponse(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 40,
          height: 40,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? Colors.white : Colors.transparent,
              width: 2,
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0x33FFFFFF)),
            ),
            child: selected
                ? Icon(Icons.check,
                    size: 16, color: light ? Colors.black87 : Colors.white)
                : null,
          ),
        ),
      ),
    );
  }
}

/// Üç seçenekli, tek satırlık seçici (iOS tarzı).
class _Segmented<T> extends StatelessWidget {
  final List<T> values;
  final List<String> labels;
  final T selected;
  final ValueChanged<T> onChanged;

  const _Segmented({
    required this.values,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0x33000000),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: values[i] == selected,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(values[i]),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    height: 38,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: values[i] == selected
                          ? Colors.white
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        labels[i],
                        maxLines: 1,
                        style: TextStyle(
                          color: values[i] == selected
                              ? Colors.black87
                              : Colors.white,
                          fontSize: 14,
                          fontWeight: values[i] == selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Kart tasarımı seçimi: tek satır (seçili tasarımın küçük örneği ve adı),
/// dokununca açılan ızgarada bir tasarıma dokunmak sadece "adaylığa" alır;
/// gerçekten uygulanması için "Kaydet" basılmalıdır.
class _CardDesignRow extends StatefulWidget {
  _CardDesignRow();

  @override
  State<_CardDesignRow> createState() => _CardDesignRowState();
}

class _CardDesignRowState extends State<_CardDesignRow> {
  bool _expanded = false;
  late CardFaceTheme _pending;

  @override
  void initState() {
    super.initState();
    _pending = AppSettings.instance.cardTheme;
  }

  String _labelFor(CardFaceTheme theme) {
    switch (theme) {
      case CardFaceTheme.classic:
        return t('theme_classic');
      case CardFaceTheme.fruit:
        return t('theme_fruit');
      case CardFaceTheme.figure:
        return t('theme_figure');
      case CardFaceTheme.ottoman:
        return t('theme_ottoman');
      case CardFaceTheme.egypt:
        return t('theme_egypt');
      case CardFaceTheme.rome:
        return t('theme_rome');
      case CardFaceTheme.animals:
        return t('theme_animals');
      case CardFaceTheme.chineseZodiac:
        return t('theme_chinese_zodiac');
      case CardFaceTheme.matryoshka:
        return t('theme_matryoshka');
      case CardFaceTheme.soviet:
        return t('theme_soviet');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPendingChange = _pending != AppSettings.instance.cardTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  height: 44,
                  child: CardWidget(
                      card: _demoCard,
                      themeOverride: _pending,
                      width: 32,
                      height: 44),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(t('settings_card_theme'), style: _titleStyle)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _labelFor(_pending),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.expand_more, color: Colors.white54),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: _expanded
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                  child: Column(
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          const gap = 8.0;
                          final tileWidth =
                              (constraints.maxWidth - gap * 2) / 3;
                          return Wrap(
                            spacing: gap,
                            runSpacing: gap,
                            children: [
                              for (final theme in CardFaceTheme.values)
                                SizedBox(
                                  width: tileWidth,
                                  child: _ThemeTile(
                                    label: _labelFor(theme),
                                    theme: theme,
                                    selected: theme == _pending,
                                    onTap: () =>
                                        setState(() => _pending = theme),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: hasPendingChange
                              ? () {
                                  AppSettings.instance
                                      .setCardFaceTheme(_pending);
                                  setState(() => _expanded = false);
                                }
                              : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.black87,
                            disabledBackgroundColor: const Color(0x1FFFFFFF),
                            disabledForegroundColor: Colors.white38,
                            minimumSize: const Size.fromHeight(46),
                          ),
                          child: Text(t('save')),
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _ThemeTile extends StatelessWidget {
  final String label;
  final CardFaceTheme theme;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeTile({
    required this.label,
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.fromLTRB(6, 10, 6, 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0x1FFFFFFF) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? Colors.amber : _hairline,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              SizedBox(
                width: 44,
                height: 62,
                child: CardWidget(
                    card: _demoCard, themeOverride: theme, width: 44, height: 62),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
