import 'package:flutter/material.dart';
import '../models/playing_card.dart';
import '../settings/app_settings.dart';
import '../settings/progress.dart';
import '../settings/strings.dart';
import '../widgets/card_widget.dart';
import '../widgets/game_ui.dart';

class StarShopScreen extends StatelessWidget {
  const StarShopScreen({super.key});

  static const _items = <CardFaceTheme>[
    CardFaceTheme.ottoman,
    CardFaceTheme.egypt,
    CardFaceTheme.rome,
    CardFaceTheme.india,
    CardFaceTheme.germany,
    CardFaceTheme.france,
    CardFaceTheme.japan,
    CardFaceTheme.persia,
    CardFaceTheme.russia,
  ];

  String _name(CardFaceTheme theme) => t(switch (theme) {
    CardFaceTheme.ottoman => 'theme_ottoman',
    CardFaceTheme.egypt => 'theme_egypt',
    CardFaceTheme.rome => 'theme_rome',
    CardFaceTheme.animals => 'theme_animals',
    CardFaceTheme.chineseZodiac => 'theme_chinese_zodiac',
    CardFaceTheme.matryoshka => 'theme_matryoshka',
    CardFaceTheme.soviet => 'theme_soviet',
    CardFaceTheme.india => 'Hindistan',
    CardFaceTheme.germany => 'Almanya',
    CardFaceTheme.france => 'Fransa',
    CardFaceTheme.japan => 'Japonya',
    CardFaceTheme.persia => 'Pers',
    CardFaceTheme.russia => 'Rusya',
    _ => 'theme_classic',
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([Progress.instance, AppSettings.instance]),
      builder: (context, _) {
        final progress = Progress.instance;
        return Scaffold(
          backgroundColor: const Color(0xFF101827),
          appBar: AppBar(
            title: Text(t('star_shop_title'), style: GameUi.display(19)),
            backgroundColor: const Color(0xFF142238),
            foregroundColor: Colors.white,
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B2B12), Color(0xFF1B293D)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: GameUi.gold.withOpacity(0.55)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.stars_rounded, color: GameUi.gold, size: 38),
                      const SizedBox(width: 13),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t('star_shop_balance'), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          const SizedBox(height: 3),
                          Text('${progress.stars}', style: GameUi.display(27, color: GameUi.gold)),
                        ],
                      )),
                      const Icon(Icons.auto_awesome, color: GameUi.goldLight, size: 25),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(t('star_shop_subtitle'), style: const TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 8),
                Text(t('star_shop_free_note'), style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.4)),
                const SizedBox(height: 22),
                Text(t('settings_group_cards').toUpperCase(), style: GameUi.display(13, color: GameUi.gold)),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _items.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.82,
                  ),
                  itemBuilder: (context, index) {
                    final theme = _items[index];
                    final price = 0;
                    final owned = progress.isCardThemeUnlocked(theme.index);
                    final equipped = AppSettings.instance.cardTheme == theme;
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B293D),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: equipped ? GameUi.gold : Colors.white12, width: equipped ? 1.8 : 1),
                      ),
                      child: Column(
                        children: [
                          Expanded(child: Center(child: CardWidget(
                            card: const PlayingCard(Suit.hearts, 7),
                            themeOverride: theme, width: 62, height: 88,
                          ))),
                          const SizedBox(height: 8),
                          Text(_name(theme), maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity, height: 36,
                            child: owned
                              ? OutlinedButton(
                                  onPressed: equipped ? null : () => AppSettings.instance.setCardFaceTheme(theme),
                                  style: OutlinedButton.styleFrom(foregroundColor: GameUi.gold, side: const BorderSide(color: GameUi.gold)),
                                  child: Text(equipped ? t('star_shop_owned') : t('star_shop_equip'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                                )
                              : FilledButton(
                                  onPressed: null,
                                    if (!ok) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('star_shop_not_enough'))));
                                    }
                                  
                                  style: FilledButton.styleFrom(backgroundColor: GameUi.gold, foregroundColor: const Color(0xFF201707), disabledBackgroundColor: Colors.white12, disabledForegroundColor: Colors.white38),
                                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                    const Text('Yönetici fiyat belirleyecek', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 10)),
                                  ]),
                                ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
