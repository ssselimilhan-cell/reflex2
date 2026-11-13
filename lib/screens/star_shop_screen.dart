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

  // Tema mağazası test süresince tüm yayınlanmış temaları 1 yıldızdan sunar.
  static const int _testThemePrice = 1;

  // Temel koleksiyon uygulamayla birlikte gelir; Firestore boş veya çevrimdışı olsa da görünür.
  static const List<Map<String, dynamic>> _builtInCatalog = [
    {'id':'card_theme_5','themeIndex':5,'visualStyleIndex':5,'name':'Roma','description':'Defne çelengi, mermer sütunlar, Roma kartalı ve imparatorluk madalyonları.','priceStars':1,'sortOrder':1},
    {'id':'card_theme_11','themeIndex':11,'visualStyleIndex':11,'name':'Alman','description':'Kara Orman meşesi, Gotik katedral pencereleri, kartal arması ve dövme demir işçiliğinden ilham alan görkemli Alman estetiği.','priceStars':1,'sortOrder':2},
    {'id':'card_theme_12','themeIndex':12,'visualStyleIndex':12,'name':'Fransız','description':'Fleur-de-lis, kraliyet tacı, Versailles süslemeleri ve altın varaklı rokoko ayrıntıları.','priceStars':1,'sortOrder':3},
    {'id':'card_theme_10','themeIndex':10,'visualStyleIndex':10,'name':'Hint','description':'Tavus kuşu tüyleri, lotus, mücevher işlemeli Babür kemerleri ve katmanlı mandala bezemeleri.','priceStars':1,'sortOrder':4},
    {'id':'card_theme_15','themeIndex':15,'visualStyleIndex':15,'name':'Rus','description':'Soğan kubbeli katedraller, mine işi renkler, Fabergé esintili mücevher bezemeleri ve çift başlı kartal silueti.','priceStars':1,'sortOrder':5},
    {'id':'card_theme_4','themeIndex':4,'visualStyleIndex':4,'name':'Mısır','description':'Nil turkuazı, güneş diski ve piramit çizgileriyle çölün görkemli altın çağı.','priceStars':1,'sortOrder':6},
    {'id':'card_theme_14','themeIndex':14,'visualStyleIndex':14,'name':'Pers','description':'Şahname minyatürlerinden ilham alan simurg, aslan-güneş rozeti, firuze çiniler ve ince halı bordürleri.','priceStars':1,'sortOrder':7},
    {'id':'card_theme_3','themeIndex':3,'visualStyleIndex':3,'name':'Osmanlı','description':'İznik çinileri, lale ve karanfil motifleri, tuğra kıvrımları, hilal ve altın tezhip bezemeleri.','priceStars':1,'sortOrder':8},
    {'id':'card_theme_13','themeIndex':13,'visualStyleIndex':13,'name':'Japon','description':'Samuray zırhı silueti, kırmızı torii, sakura dalları, seigaiha dalgaları ve altın kintsugi çizgileri.','priceStars':1,'sortOrder':9},
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
                  return i is int && i>=0 && i<CardFaceTheme.values.length;
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
                      final theme=CardFaceTheme.values[styleIndex]; final price=_testThemePrice;
                      final id=entry.key; final name=data['name'] as String? ?? 'Tema';
                      final owned=progress.isCatalogThemeUnlocked(id,styleIndex);
                      final equipped=AppSettings.instance.selectedThemeId==id || (AppSettings.instance.selectedThemeId.startsWith('builtin_') && AppSettings.instance.cardTheme==theme);
                      return Container(
                        padding:const EdgeInsets.all(12),
                        decoration:BoxDecoration(color:const Color(0xFF26313A),borderRadius:BorderRadius.circular(18),
                          border:Border.all(color:equipped?const Color(0xFFFFD54A):Colors.white24,width:equipped?3.2:1),
                          gradient:equipped?const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[Color(0xFF5A3B18),Color(0xFF26313A),Color(0xFF26313A)]):null,
                          boxShadow:[if(equipped) BoxShadow(color:const Color(0xFFFFC928).withOpacity(.55),blurRadius:22,spreadRadius:2),BoxShadow(color:Colors.black.withOpacity(.16),blurRadius:10,offset:const Offset(0,4))]),
                        child:Column(children:[
                          if(equipped) const Align(alignment:Alignment.topRight,child:Padding(padding:EdgeInsets.only(bottom:2),child:Row(mainAxisSize:MainAxisSize.min,children:[Icon(Icons.verified_rounded,color:Color(0xFFFFD54A),size:15),SizedBox(width:4),Text('SEÇİLİ TEMA',style:TextStyle(color:Color(0xFFFFD54A),fontSize:10,fontWeight:FontWeight.w900,letterSpacing:.6))]))),
                          Expanded(child:Center(child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[
                            CardWidget(card:const PlayingCard(Suit.hearts,7),themeOverride:theme,width:62,height:90),
                            const SizedBox(width:7),
                            CardWidget(card:const PlayingCard(Suit.spades,12),faceDown:true,themeOverride:theme,width:62,height:90),
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
