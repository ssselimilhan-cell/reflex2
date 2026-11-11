import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../settings/app_settings.dart';
import '../settings/strings.dart';
import '../settings/moderation.dart';
import '../settings/share_helper.dart';
import '../settings/feedback.dart';
import '../settings/telemetry.dart';
import '../settings/progress.dart';
import 'star_shop_screen.dart';
import 'profile_screen.dart';
import '../models/playing_card.dart';
import '../widgets/card_widget.dart';
import '../widgets/profile_avatar.dart';

// Preview milestone: privacy controls now require explicit telemetry opt-in.
// Settings are organized around frequent account actions first; infrequent
// visual/game preferences stay collapsed until the player asks for them.
const Color _chipFill = Color(0x24FFFFFF);
// Shared subtle divider/border tone for compact settings surfaces.
const Color _hairline = Color(0x26FFFFFF);
const PlayingCard _demoCard = PlayingCard(Suit.hearts, 7);

const TextStyle _titleStyle =
    TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500);

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;
    return AnimatedBuilder(
      animation: Listenable.merge([settings, Moderation.instance, Progress.instance]),
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF101827),
          appBar: AppBar(
            title: Text(t('settings_title'), style: const TextStyle(fontWeight: FontWeight.w800)),
            backgroundColor: const Color(0xFF142238),
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                  children: [
                    const Text('HESAP VE PROFİL',
                      style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                    const SizedBox(height: 10),
                    _QuickActionGrid(children: [
                      _QuickAction(icon: Icons.person_outline_rounded, leading: const ProfileAvatar(radius: 18), title: t('profile'), subtitle: 'Fotoğrafını ve profilini düzenle',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()))),
                      _QuickAction(icon: Icons.group_add_outlined, title: t('invite_friends'), onTap: shareApp),
                      _QuickAction(icon: Icons.chat_bubble_outline_rounded, title: t('feedback_title'),
                        onTap: () => showFeedbackDialog(context)),
                      _QuickAction(icon: Icons.language_rounded, title: _languageName(settings.language),
                        subtitle: 'Dil seçimi', onTap: () => _pickLanguage(context)),
                    ]),
                    const SizedBox(height: 16),
                    Material(
                      color: const Color(0xFF202D42),
                      borderRadius: BorderRadius.circular(18),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StarShopScreen())),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                          child: Row(children: [
                            Container(width: 44, height: 44,
                              decoration: BoxDecoration(color: Colors.amber.withOpacity(.14), borderRadius: BorderRadius.circular(13)),
                              child: const Icon(Icons.storefront_rounded, color: Colors.amber, size: 25)),
                            const SizedBox(width: 13),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Text('TEMA MAĞAZASI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                              const SizedBox(height: 3),
                              Text('Kart tasarımlarını keşfet • ${Progress.instance.stars} ⭐',
                                style: const TextStyle(color: Colors.white60, fontSize: 12)),
                            ])),
                            const Icon(Icons.chevron_right_rounded, color: Colors.amber, size: 26),
                          ]),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text('KİŞİSELLEŞTİRME',
                      style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                    const SizedBox(height: 8),
                    _SettingsExpansion(
                      icon: Icons.style_outlined,
                      title: 'Kart ve görünüm',
                      subtitle: 'Kart teması, arka yüz, masa rengi ve yazı boyutu',
                      children: [
                        _CardDesignRow(),
                        _SettingRow(icon: Icons.flip, title: t('settings_card_back'),
                          belowPadding: const EdgeInsets.fromLTRB(58, 8, 14, 0),
                          below: _SwatchRow(colors: AppSettings.cardBackPresets,
                            selected: settings.cardBackColor, onPick: settings.setCardBackColor)),
                        _SettingRow(icon: Icons.aspect_ratio, title: t('settings_card_size'),
                          trailing: _ValuePill('${(settings.cardScale * 100).round()}%'),
                          belowPadding: const EdgeInsets.only(top: 2),
                          below: _StyledSlider(value: settings.cardScale, min: .7, max: 2, divisions: 13, onChanged: settings.setCardScale)),
                        _SettingRow(icon: Icons.palette_outlined, title: t('settings_color'),
                          belowPadding: const EdgeInsets.fromLTRB(58, 8, 14, 0),
                          below: _SwatchRow(colors: AppSettings.presetColors,
                            selected: settings.themeColor, onPick: settings.setThemeColor)),
                        _SettingRow(icon: Icons.text_fields_rounded, title: t('settings_font_size'),
                          trailing: _ValuePill('${(settings.fontScale * 100).round()}%'),
                          belowPadding: const EdgeInsets.only(top: 2),
                          below: _StyledSlider(value: settings.fontScale, min: .8, max: 1.6, divisions: 8, onChanged: settings.setFontScale)),
                        _switchRow(icon: Icons.contrast, title: t('settings_high_contrast'),
                          value: settings.highContrast, onChanged: settings.setHighContrast),
                      ],
                    ),
                    _SettingsExpansion(
                      icon: Icons.sports_esports_outlined,
                      title: 'Oyun tercihleri',
                      subtitle: 'Animasyon ve oyun içi yardımcılar',
                      children: [
                        _SettingRow(icon: Icons.speed, title: t('settings_animation_speed'),
                          below: _Segmented<double>(values: const [.5, 1, 1.6],
                            labels: [t('speed_fast'), t('speed_normal'), t('speed_slow')],
                            selected: settings.animationSpeed, onChanged: settings.setAnimationSpeed)),
                        _switchRow(icon: Icons.tips_and_updates_outlined, title: t('assisted_mode'),
                          value: settings.assistedMode, onChanged: settings.setAssistedMode),
                      ],
                    ),
                    _SettingsExpansion(
                      icon: Icons.volume_up_outlined,
                      title: 'Ses ve dokunma',
                      subtitle: 'Ses efektleri ve titreşim',
                      children: [
                        _switchRow(icon: Icons.volume_up_outlined, title: t('settings_sound'),
                          value: settings.soundEnabled, onChanged: settings.setSoundEnabled),
                        _switchRow(icon: Icons.vibration, title: t('settings_haptics'),
                          value: settings.hapticsEnabled, onChanged: settings.setHapticsEnabled),
                      ],
                    ),
                    _SettingsExpansion(
                      icon: Icons.shield_outlined,
                      title: 'Gizlilik ve güvenlik',
                      subtitle: 'İsteğe bağlı kullanım ve hata ölçümü • varsayılan kapalı',
                      children: [
                        _switchRow(icon: Icons.analytics_outlined, title: t('settings_telemetry'),
                          value: settings.telemetryEnabled, onChanged: settings.setTelemetryEnabled),
                        _SettingRow(icon: Icons.block, title: t('blocked_players'),
                          trailing: _ValueWithChevron('${Moderation.instance.blocked.length}'),
                          onTap: () => showBlockedPlayersDialog(context)),
                      ],
                    ),
                    _SettingsExpansion(
                      icon: Icons.help_outline_rounded,
                      title: 'Destek ve uygulama',
                      subtitle: 'Uygulamayı değerlendir ve yardım al',
                      children: [
                        _SettingRow(icon: Icons.star_border_rounded, title: t('rate_app'), onTap: openStoreReview),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Center(child: Text('${t('app_title')}  •  ${Telemetry.appVersion}',
                      style: const TextStyle(color: Colors.white38, fontSize: 11))),
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

class _QuickActionGrid extends StatelessWidget {
  final List<Widget> children;
  const _QuickActionGrid({required this.children});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
    final width = (constraints.maxWidth - 10) / 2;
    return Wrap(spacing: 10, runSpacing: 10,
      children: [for (final child in children) SizedBox(width: width, child: child)]);
  });
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final Widget? leading;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, this.leading, required this.title, this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFF202D42),
    borderRadius: BorderRadius.circular(15),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: SizedBox(height: 76,
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            leading ?? Icon(icon, color: Colors.amber, size: 22),
            const SizedBox(width: 9),
            Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
              if (subtitle != null) Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white54, fontSize: 10)),
            ])),
            const Icon(Icons.chevron_right, color: Colors.white38, size: 18),
          ]),
        ),
      ),
    ),
  );
}

class _SettingsExpansion extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;
  const _SettingsExpansion({required this.icon, required this.title, required this.subtitle, required this.children});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 9),
    decoration: BoxDecoration(color: const Color(0xFF1A273A), borderRadius: BorderRadius.circular(15),
      border: Border.all(color: Colors.white.withOpacity(.07))),
    child: Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent, splashColor: Colors.white10),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 1),
        childrenPadding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
        leading: Icon(icon, color: Colors.amber, size: 22),
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        iconColor: Colors.amber,
        collapsedIconColor: Colors.white54,
        children: children,
      ),
    ),
  );
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
  const _CardDesignRow();

  @override
  State<_CardDesignRow> createState() => _CardDesignRowState();
}

class _CardDesignRowState extends State<_CardDesignRow> {
  bool _expanded = false;
  late String _pendingId;
  late CardFaceTheme _pendingStyle;

  @override
  void initState() {
    super.initState();
    final settings = AppSettings.instance;
    _pendingId = settings.selectedThemeId;
    _pendingStyle = settings.cardTheme;
  }

  CardFaceTheme _styleFromIndex(dynamic value) {
    final index = value is int ? value : CardFaceTheme.classic.index;
    if (index < 0 || index >= CardFaceTheme.values.length) {
      return CardFaceTheme.classic;
    }
    final style = CardFaceTheme.values[index];
    const hidden = {
      CardFaceTheme.figure,
      CardFaceTheme.animals,
      CardFaceTheme.chineseZodiac,
      CardFaceTheme.matryoshka,
      CardFaceTheme.soviet,
    };
    return hidden.contains(style) ? CardFaceTheme.classic : style;
  }

  String _builtinLabel(CardFaceTheme theme) => switch (theme) {
    CardFaceTheme.classic => t('theme_classic'),
    CardFaceTheme.fruit => t('theme_fruit'),
    _ => t('theme_classic'),
  };

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;
    final hasPendingChange = _pendingId != settings.selectedThemeId;
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
                  child: CardWidget(card: _demoCard, themeOverride: _pendingStyle, width: 32, height: 44),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(t('settings_card_theme'), style: _titleStyle)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _pendingId.startsWith('builtin_')
                        ? _builtinLabel(_pendingStyle)
                        : '$_pendingId',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
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
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('cosmetic_catalog')
                        .where('isPublished', isEqualTo: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Text(
                          'Temalar yüklenemedi: ${snapshot.error}',
                          style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Padding(
                          padding: EdgeInsets.all(18),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final docs = snapshot.data!.docs
                          .where((doc) {
                            final data = doc.data();
                            final price = data['priceStars'];
                            final rawStyle = data['visualStyleIndex'] ?? data['themeIndex'];
                            if (price is! int || price <= 0 || rawStyle is! int) return false;
                            return Progress.instance.isCatalogThemeUnlocked(doc.id, rawStyle);
                          })
                          .toList()
                        ..sort((a, b) => ((a.data()['sortOrder'] as int?) ?? 0)
                            .compareTo((b.data()['sortOrder'] as int?) ?? 0));

                      final tiles = <Widget>[
                        _ThemeTile(
                          label: _builtinLabel(CardFaceTheme.classic),
                          theme: CardFaceTheme.classic,
                          selected: _pendingId == 'builtin_classic',
                          locked: false,
                          onTap: () => setState(() {
                            _pendingId = 'builtin_classic';
                            _pendingStyle = CardFaceTheme.classic;
                          }),
                        ),
                        _ThemeTile(
                          label: _builtinLabel(CardFaceTheme.fruit),
                          theme: CardFaceTheme.fruit,
                          selected: _pendingId == 'builtin_fruit',
                          locked: false,
                          onTap: () => setState(() {
                            _pendingId = 'builtin_fruit';
                            _pendingStyle = CardFaceTheme.fruit;
                          }),
                        ),
                        for (final doc in docs)
                          _ThemeTile(
                            label: (doc.data()['name'] as String?)?.trim().isNotEmpty == true
                                ? (doc.data()['name'] as String).trim()
                                : 'Tema',
                            theme: _styleFromIndex(doc.data()['visualStyleIndex'] ?? doc.data()['themeIndex']),
                            selected: _pendingId == doc.id,
                            locked: false,
                            onTap: () => setState(() {
                              _pendingId = doc.id;
                              _pendingStyle = _styleFromIndex(doc.data()['visualStyleIndex'] ?? doc.data()['themeIndex']);
                            }),
                          ),
                      ];

                      return Column(
                        children: [
                          LayoutBuilder(
                            builder: (context, constraints) {
                              const gap = 8.0;
                              final tileWidth = (constraints.maxWidth - gap * 2) / 3;
                              return Wrap(
                                spacing: gap,
                                runSpacing: gap,
                                children: [
                                  for (final tile in tiles)
                                    SizedBox(width: tileWidth, child: tile),
                                ],
                              );
                            },
                          ),
                          if (docs.isEmpty) ...[
                            const SizedBox(height: 10),
                            const Text('Yeni temaları yıldız mağazasından açabilirsin.', style: TextStyle(color: Colors.white60, fontSize: 12)),
                          ],
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StarShopScreen())),
                              icon: const Icon(Icons.storefront_outlined),
                              label: const Text('Tema mağazasını aç'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.amber,
                                side: const BorderSide(color: Colors.amber),
                                minimumSize: const Size.fromHeight(42),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: hasPendingChange
                                  ? () {
                                      if (_pendingId.startsWith('builtin_')) {
                                        settings.setCardFaceTheme(_pendingStyle);
                                      } else {
                                        final selectedDocs = snapshot.data!.docs.where((d) => d.id == _pendingId);
                                        final selectedDoc = selectedDocs.isEmpty ? null : selectedDocs.first;
                                        settings.setCatalogTheme(id: _pendingId, name: (selectedDoc?.data()['name'] as String?) ?? 'Tema', visualStyle: _pendingStyle);
                                      }
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
                      );
                    },
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
  final bool locked;
  final VoidCallback onTap;

  const _ThemeTile({
    required this.label,
    required this.theme,
    required this.selected,
    required this.locked,
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
              if (locked) const Icon(Icons.lock_rounded, color: Colors.amber, size: 15),
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
