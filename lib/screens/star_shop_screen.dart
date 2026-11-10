import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/playing_card.dart';
import '../settings/app_settings.dart';
import '../settings/auth_service.dart';
import '../settings/progress.dart';
import '../settings/strings.dart';
import '../widgets/card_widget.dart';
import '../widgets/game_ui.dart';
import 'admin_theme_screen.dart';

class StarShopScreen extends StatelessWidget {
  const StarShopScreen({super.key});

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
            actions: [
              if (AuthService.instance.isAdmin)
                IconButton(
                  tooltip: 'Tema yönetimi',
                  icon: const Icon(Icons.admin_panel_settings_outlined, color: GameUi.gold),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminThemeScreen())),
                ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF3B2B12), Color(0xFF1B293D)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: GameUi.gold.withOpacity(0.55)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.stars_rounded, color: GameUi.gold, size: 38),
                    const SizedBox(width: 13),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t('star_shop_balance'), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 3),
                      Text('${progress.stars}', style: GameUi.display(27, color: GameUi.gold)),
                    ])),
                    const Icon(Icons.auto_awesome, color: GameUi.goldLight, size: 25),
                  ]),
                ),
                const SizedBox(height: 14),
                Text(t('star_shop_subtitle'), style: const TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 22),
                Text(t('settings_group_cards').toUpperCase(), style: GameUi.display(13, color: GameUi.gold)),
                const SizedBox(height: 12),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance.collection('cosmetic_catalog').where('isPublished', isEqualTo: true).snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return const Padding(padding: EdgeInsets.all(18), child: Text('Mağaza şu anda yüklenemiyor. Daha sonra tekrar dene.', style: TextStyle(color: Colors.white70)));
                    if (!snapshot.hasData) return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
                    final docs = snapshot.data!.docs.where((d) => d.data()['priceStars'] is int && (d.data()['priceStars'] as int) > 0 && d.data()['themeIndex'] is int).toList()..sort((a, b) => ((a.data()['sortOrder'] as int?) ?? 0).compareTo((b.data()['sortOrder'] as int?) ?? 0));
                    if (docs.isEmpty) return Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(color: const Color(0xFF1B293D), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white12)),
                      child: const Column(children: [
                        Icon(Icons.auto_awesome, color: GameUi.gold, size: 34),
                        SizedBox(height: 10),
                        Text('Yeni temalar hazırlanıyor', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                        SizedBox(height: 5),
                        Text('Yeni tasarımlar mağazada yayınlandığında burada görünecek.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, height: 1.4)),
                      ]),
                    );
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: docs.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.78),
                      itemBuilder: (context, index) {
                        final data = docs[index].data();
                        final themeIndex = data['themeIndex'] as int;
                        if (themeIndex < 0 || themeIndex >= CardFaceTheme.values.length) return const SizedBox.shrink();
                        final theme = CardFaceTheme.values[themeIndex];
                        final price = data['priceStars'] as int;
                        final owned = progress.isCardThemeUnlocked(themeIndex);
                        final equipped = AppSettings.instance.cardTheme == theme;
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: const Color(0xFF1B293D), borderRadius: BorderRadius.circular(18), border: Border.all(color: equipped ? GameUi.gold : Colors.white12, width: equipped ? 1.8 : 1)),
                          child: Column(children: [
                            Expanded(child: Center(child: CardWidget(card: const PlayingCard(Suit.hearts, 7), themeOverride: theme, width: 62, height: 88))),
                            const SizedBox(height: 8),
                            Text(data['name'] as String? ?? 'Tema', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                            if ((data['description'] as String? ?? '').isNotEmpty)
                              Padding(padding: const EdgeInsets.only(top: 3), child: Text(data['description'] as String, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 10))),
                            const SizedBox(height: 8),
                            SizedBox(width: double.infinity, height: 36, child: owned
                              ? OutlinedButton(onPressed: equipped ? null : () => AppSettings.instance.setCardFaceTheme(theme), style: OutlinedButton.styleFrom(foregroundColor: GameUi.gold, side: const BorderSide(color: GameUi.gold)), child: Text(equipped ? 'Kullanılıyor' : t('star_shop_equip'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)))
                              : FilledButton(
                                  onPressed: progress.stars >= price ? () {
                                    final ok = progress.purchaseCardTheme(themeIndex, price);
                                    if (!ok) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('star_shop_not_enough'))));
                                  } : null,
                                  style: FilledButton.styleFrom(backgroundColor: GameUi.gold, foregroundColor: const Color(0xFF201707), disabledBackgroundColor: Colors.white12, disabledForegroundColor: Colors.white38),
                                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.star_rounded, size: 15), const SizedBox(width: 4), Text('$price', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12))]),
                                )),
                          ]),
                        );
                      },
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
