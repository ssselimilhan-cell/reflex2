import 'package:flutter/material.dart';
import '../settings/app_settings.dart';
import '../settings/strings.dart';

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
          body: ListView(
            padding: const EdgeInsets.all(20),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _SpeedChip(
                    label: t('theme_classic'),
                    selected: settings.cardTheme == CardFaceTheme.classic,
                    onTap: () => settings.setCardFaceTheme(CardFaceTheme.classic),
                  ),
                  _SpeedChip(
                    label: t('theme_fruit'),
                    selected: settings.cardTheme == CardFaceTheme.fruit,
                    onTap: () => settings.setCardFaceTheme(CardFaceTheme.fruit),
                  ),
                  _SpeedChip(
                    label: t('theme_figure'),
                    selected: settings.cardTheme == CardFaceTheme.figure,
                    onTap: () => settings.setCardFaceTheme(CardFaceTheme.figure),
                  ),
                ],
              ),
              const SizedBox(height: 20),
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
