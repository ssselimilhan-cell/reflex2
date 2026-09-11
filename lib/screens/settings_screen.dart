import 'package:flutter/material.dart';
import '../settings/app_settings.dart';
import '../settings/strings.dart';
import '../models/playing_card.dart';
import '../widgets/card_widget.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: settings.themeColor,
          appBar: AppBar(title: Text(t('settings_title'))),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
              children: [
                _SectionLabel(t('settings_card_size')),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: settings.cardScale,
                      min: 0.7,
                      max: 2.0,
                      divisions: 13,
                      onChanged: settings.setCardScale,
                    ),
                  ),
                  SizedBox(
                    width: 52,
                    child: Text(
                      '${(settings.cardScale * 100).round()}%',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _SectionLabel(t('settings_font_size')),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: settings.fontScale,
                      min: 0.8,
                      max: 1.6,
                      divisions: 8,
                      onChanged: settings.setFontScale,
                    ),
                  ),
                  SizedBox(
                    width: 52,
                    child: Text(
                      '${(settings.fontScale * 100).round()}%',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _SectionLabel(t('settings_color')),
              const SizedBox(height: 8),
              _ColorRow(
                colors: AppSettings.presetColors,
                selected: settings.themeColor,
                onPick: settings.setThemeColor,
              ),
              const SizedBox(height: 24),
              _SectionLabel(t('settings_card_back')),
              const SizedBox(height: 8),
              _ColorRow(
                colors: AppSettings.cardBackPresets,
                selected: settings.cardBackColor,
                onPick: settings.setCardBackColor,
              ),
              const SizedBox(height: 24),
              _SectionLabel(t('settings_animation_speed')),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _SpeedChip(
                    label: t('speed_fast'),
                    selected: settings.animationSpeed == 0.5,
                    onTap: () => settings.setAnimationSpeed(0.5),
                  ),
                  _SpeedChip(
                    label: t('speed_normal'),
                    selected: settings.animationSpeed == 1.0,
                    onTap: () => settings.setAnimationSpeed(1.0),
                  ),
                  _SpeedChip(
                    label: t('speed_slow'),
                    selected: settings.animationSpeed == 1.6,
                    onTap: () => settings.setAnimationSpeed(1.6),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _SectionLabel(t('settings_card_theme')),
              const SizedBox(height: 8),
              const _ThemePickerTile(),
              const SizedBox(height: 20),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: Colors.amber,
                title: Text(t('assisted_mode'),
                    style: const TextStyle(color: Colors.white)),
                value: settings.assistedMode,
                onChanged: settings.setAssistedMode,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: Colors.amber,
                title: Text(t('settings_high_contrast'),
                    style: const TextStyle(color: Colors.white)),
                value: settings.highContrast,
                onChanged: settings.setHighContrast,
              ),
              const SizedBox(height: 12),
              _SectionLabel(t('settings_language')),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  ChoiceChip(
                    label: const Text('Türkçe'),
                    selected: settings.language == AppLanguage.tr,
                    onSelected: (_) => settings.setLanguage(AppLanguage.tr),
                  ),
                  ChoiceChip(
                    label: const Text('English'),
                    selected: settings.language == AppLanguage.en,
                    onSelected: (_) => settings.setLanguage(AppLanguage.en),
                  ),
                  ChoiceChip(
                    label: const Text('Русский'),
                    selected: settings.language == AppLanguage.ru,
                    onSelected: (_) => settings.setLanguage(AppLanguage.ru),
                  ),
                  ChoiceChip(
                    label: const Text('中文'),
                    selected: settings.language == AppLanguage.zh,
                    onSelected: (_) => settings.setLanguage(AppLanguage.zh),
                  ),
                ],
              ),
            ],
          ),
          ),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold));
  }
}

class _ColorRow extends StatelessWidget {
  final List<Color> colors;
  final Color selected;
  final void Function(Color) onPick;

  const _ColorRow(
      {required this.colors, required this.selected, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: colors.map((c) {
        final isSelected = c.value == selected.value;
        return GestureDetector(
          onTap: () => onPick(c),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.white : Colors.white24,
                width: isSelected ? 3 : 1,
              ),
            ),
            child: isSelected
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : null,
          ),
        );
      }).toList(),
    );
  }
}

class _SpeedChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SpeedChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

/// Kart temasını seçmek için: tek satır (o an seçili/kaydedilmiş temanın
/// küçük bir örneğiyle), dokununca aşağı doğru AÇILAN bir liste. Listede
/// bir temaya dokunmak sadece "adaylığa" alır (üstteki önizleme anında
/// güncellenir) — gerçekten uygulanması için "Kaydet" basılması gerekir.
class _ThemePickerTile extends StatefulWidget {
  const _ThemePickerTile();

  @override
  State<_ThemePickerTile> createState() => _ThemePickerTileState();
}

class _ThemePickerTileState extends State<_ThemePickerTile> {
  bool _expanded = false;
  late CardFaceTheme _pending;

  static const _demoCard = PlayingCard(Suit.hearts, 7);

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
    return Container(
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    height: 56,
                    child: CardWidget(
                        card: _demoCard,
                        themeOverride: _pending,
                        width: 40,
                        height: 56),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _labelFor(_pending),
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.white70),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(color: Colors.white24, height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Column(
                children: CardFaceTheme.values.map((theme) {
                  final selected = theme == _pending;
                  return InkWell(
                    onTap: () => setState(() => _pending = theme),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? Colors.white12 : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: selected
                            ? Border.all(color: Colors.amber, width: 1.4)
                            : null,
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 30,
                            height: 42,
                            child: CardWidget(
                                card: _demoCard,
                                themeOverride: theme,
                                width: 30,
                                height: 42),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(_labelFor(theme),
                                style:
                                    const TextStyle(color: Colors.white)),
                          ),
                          if (selected)
                            const Icon(Icons.check,
                                color: Colors.amber, size: 18),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 14, top: 4),
              child: ElevatedButton.icon(
                onPressed: hasPendingChange
                    ? () {
                        AppSettings.instance.setCardFaceTheme(_pending);
                        setState(() => _expanded = false);
                      }
                    : null,
                icon: const Icon(Icons.check),
                label: Text(t('save')),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
