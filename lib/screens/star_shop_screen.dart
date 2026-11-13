import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
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

  // Temel koleksiyon uygulamayla birlikte gelir; Firestore boş veya çevrimdışı olsa da görünür.
  static const List<Map<String, dynamic>> _builtInCatalog = [
    {'id':'card_theme_5','themeIndex':5,'visualStyleIndex':5,'name':'Roma','description':'Mermer beyazı, imparatorluk kızılı ve görkemli sütunlarla Roma arenalarının asaleti.','priceStars':100,'sortOrder':1},
    {'id':'card_theme_11','themeIndex':11,'visualStyleIndex':11,'name':'Almanya','description':'Kömür grisi, eski altın, Gotik kemerler ve vitraydan ilham alan keskin çizgiler.','priceStars':100,'sortOrder':2},
    {'id':'card_theme_12','themeIndex':12,'visualStyleIndex':12,'name':'Fransa','description':'Mücevher moru, gül kurusu ve fleur-de-lis motifleriyle zarif Fransız saray stili.','priceStars':100,'sortOrder':3},
    {'id':'card_theme_10','themeIndex':10,'visualStyleIndex':10,'name':'Hindistan','description':'Safran, yakut ve zümrüt tonlarında lotuslar ve katmanlı mandala geometrisi.','priceStars':150,'sortOrder':4},
    {'id':'card_theme_15','themeIndex':15,'visualStyleIndex':15,'name':'Rusya','description':'Gece mavisi, buz mavisi ve renkli kubbe siluetleriyle Rus mimari ihtişamı.','priceStars':150,'sortOrder':5},
    {'id':'card_theme_4','themeIndex':4,'visualStyleIndex':4,'name':'Firavun','description':'Nil turkuazı, güneş diski ve piramit çizgileriyle çölün görkemli altın çağı.','priceStars':200,'sortOrder':6},
    {'id':'card_theme_14','themeIndex':14,'visualStyleIndex':14,'name':'Pers','description':'Derin turkuaz, lapis mavisi ve iç içe geçen Pers yıldız geometrisi.','priceStars':200,'sortOrder':7},
    {'id':'card_theme_3','themeIndex':3,'visualStyleIndex':3,'name':'Osmanlı','description':'Gece laciverti, altın tezhip, hilal ve sekiz kollu çini rozetleriyle saray ihtişamı.','priceStars':250,'sortOrder':8},
    {'id':'card_theme_13','themeIndex':13,'visualStyleIndex':13,'name':'Japonya','description':'Gece kirazı, ipek pembesi, torii kapısı ve sakura çiçekleriyle Japon dinginliği.','priceStars':250,'sortOrder':9},
  ];

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([Progress.instance, AppSettings.instance]),
    builder: (context, _) {
      final progress = Progress.instance;
      return Scaffold(
        backgroundColor: GameUi.background,
        appBar: AppBar(
          title: Text(t('star_shop_title'), style: GameUi.display(19)),
          backgroundColor: const Color(0xFF713116),
          foregroundColor: Colors.white,
          actions: [if (AuthService.instance.isAdmin) IconButton(
            tooltip: 'Tema yönetimi',
            icon: const Icon(Icons.admin_panel_settings_outlined, color: GameUi.gold),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminThemeScreen())),
          )],
        ),
        body: SafeArea(child: ListView(
          padding: const EdgeInsets.fromLTRB(16,16,16,28),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors:[Color(0xFF713116),Color(0xFF34251F)],begin:Alignment.topLeft,end:Alignment.bottomRight),
                borderRadius: BorderRadius.circular(20), border: Border.all(color:GameUi.gold.withOpacity(.65)),
              ),
              child: Row(children:[
                const Icon(Icons.stars_rounded,color:GameUi.gold,size:38), const SizedBox(width:13),
                Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Text(t('star_shop_balance'),style:const TextStyle(color:Colors.white70,fontSize:16)),
                  const SizedBox(height:3), Text('${progress.stars}',style:GameUi.display(27,color:GameUi.gold)),
                ])),
                const Icon(Icons.auto_awesome,color:GameUi.goldLight,size:25),
              ]),
            ),
            const SizedBox(height:14),
            Text(t('star_shop_subtitle'),style:const TextStyle(color:Colors.white,fontSize:14,fontWeight:FontWeight.w600)),
            const SizedBox(height:16),
            Text(t('settings_group_cards').toUpperCase(),style:GameUi.display(13,color:const Color(0xFFFFD18A))),
            const SizedBox(height:12),
            StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
              stream: Firebase.apps.isNotEmpty
                ? FirebaseFirestore.instance.collection('cosmetic_catalog').where('isPublished',isEqualTo:true).snapshots()
                : const Stream<QuerySnapshot<Map<String,dynamic>>>.empty(),
              builder:(context,snapshot){
                final catalog=<String,Map<String,dynamic>>{for(final item in _builtInCatalog) item['id'] as String:item};
                if(snapshot.hasData){for(final doc in snapshot.data!.docs){catalog[doc.id]=doc.data();}}
                final entries=catalog.entries.where((entry){
                  final d=entry.value;
                  final i=d['visualStyleIndex'] is int ? d['visualStyleIndex'] as int : d['themeIndex'];
                  return d['priceStars'] is int && (d['priceStars'] as int)>0 && i is int && i>=0 && i<CardFaceTheme.values.length;
                }).toList()..sort((a,b)=>((a.value['sortOrder'] as int?)??0).compareTo((b.value['sortOrder'] as int?)??0));
                if(!snapshot.hasData && !snapshot.hasError && snapshot.connectionState!=ConnectionState.done){
                  return const Padding(padding:EdgeInsets.all(24),child:Center(child:CircularProgressIndicator()));
                }
                return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
                  if(snapshot.hasError) const Padding(padding:EdgeInsets.only(bottom:10),child:Text('Çevrimiçi katalog yüklenemedi. Hazır temalar kullanılabilir.',style:TextStyle(color:Colors.white70,fontSize:12))),
                  GridView.builder(
                    shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),itemCount:entries.length,
                    gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:2,crossAxisSpacing:12,mainAxisSpacing:12,childAspectRatio:.70),
                    itemBuilder:(context,index){
                      final entry=entries[index]; final data=entry.value;
                      final styleIndex=data['visualStyleIndex'] is int ? data['visualStyleIndex'] as int : data['themeIndex'] as int;
                      final theme=CardFaceTheme.values[styleIndex]; final price=data['priceStars'] as int;
                      final id=entry.key; final name=data['name'] as String? ?? 'Tema';
                      final owned=progress.isCatalogThemeUnlocked(id,styleIndex);
                      final equipped=AppSettings.instance.selectedThemeId==id || (AppSettings.instance.selectedThemeId.startsWith('builtin_') && AppSettings.instance.cardTheme==theme);
                      return Container(
                        padding:const EdgeInsets.all(12),
                        decoration:BoxDecoration(color:const Color(0xFF26313A),borderRadius:BorderRadius.circular(18),
                          border:Border.all(color:equipped?GameUi.gold:Colors.white24,width:equipped?1.8:1),
                          boxShadow:[BoxShadow(color:Colors.black.withOpacity(.16),blurRadius:10,offset:const Offset(0,4))]),
                        child:Column(children:[
                          Expanded(child:Center(child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[
                            CardWidget(card:const PlayingCard(Suit.hearts,7),themeOverride:theme,width:54,height:78),
                            const SizedBox(width:7),
                            CardWidget(card:const PlayingCard(Suit.spades,12),faceDown:true,themeOverride:theme,width:54,height:78),
                          ]))),
                          const SizedBox(height:8),
                          Text(name,maxLines:2,softWrap:true,overflow:TextOverflow.visible,textAlign:TextAlign.center,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w800,fontSize:15,height:1.15)),
                          if((data['description'] as String? ?? '').isNotEmpty) Padding(padding:const EdgeInsets.only(top:3),child:Text(data['description'] as String,maxLines:3,softWrap:true,overflow:TextOverflow.visible,textAlign:TextAlign.center,style:const TextStyle(color:Colors.white70,fontSize:11,height:1.2))),
                          const SizedBox(height:8),
                          SizedBox(width:double.infinity,height:36,child:owned
                            ? OutlinedButton(onPressed:equipped?null:()=>AppSettings.instance.setCatalogTheme(id:id,name:name,visualStyle:theme),
                                style:OutlinedButton.styleFrom(foregroundColor:GameUi.gold,side:const BorderSide(color:GameUi.gold)),
                                child:GameUi.fitLabel(equipped?'Kullanılıyor':t('star_shop_equip'),style:const TextStyle(fontSize:13,fontWeight:FontWeight.w900),maxLines:2))
                            : FilledButton(onPressed:progress.stars>=price?(){
                                final ok=progress.purchaseCatalogTheme(id,styleIndex,price);
                                if(!ok) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(t('star_shop_not_enough'))));
                              }:null,
                                style:FilledButton.styleFrom(backgroundColor:GameUi.gold,foregroundColor:const Color(0xFF201707),disabledBackgroundColor:Colors.white24,disabledForegroundColor:Colors.white60),
                                child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[const Icon(Icons.star_rounded,size:15),const SizedBox(width:4),Text('$price',style:const TextStyle(fontWeight:FontWeight.w900,fontSize:14))])),
                          ),
                        ]),
                      );
                    },
                  ),
                ]);
              },
            ),
          ],
        )),
      );
    },
  );
}
