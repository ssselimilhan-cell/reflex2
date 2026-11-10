import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../settings/app_settings.dart';
import '../settings/auth_service.dart';
import '../widgets/game_ui.dart';

class AdminThemeScreen extends StatefulWidget {
  const AdminThemeScreen({super.key});

  @override
  State<AdminThemeScreen> createState() => _AdminThemeScreenState();
}

class _AdminThemeScreenState extends State<AdminThemeScreen> {
  static const _themes = <int, String>{
    3: 'Osmanlı', 4: 'Mısır', 5: 'Roma', 10: 'Hindistan',
    11: 'Almanya', 12: 'Fransa', 13: 'Japonya', 14: 'Pers', 15: 'Rusya',
  };
  static const _descriptions = <int, String>{
    3: 'Osmanlı çini geometrisi, rumi kıvrımları ve zarif tezhip bordürlerinden ilham alan tasarım.',
    4: 'Nil mavisi, lotus çiçeği, güneş diski ve piramit siluetleriyle Antik Mısır estetiği.',
    5: 'Roma mermer mimarisi, sütun ritmi, defne ve mozaik detaylarından oluşan klasik tema.',
    10: 'Hint mandalaları, lotus katmanları ve tavus kuşu tüylerinin zengin renk ritmi.',
    11: 'Gotik mimari çizgileri, vitray geometrisi ve meşe yaprağı bezemelerinden ilham.',
    12: 'Fransız fleur-de-lis motifleri, zarif simetri ve Art Nouveau çizgileri.',
    13: 'Japon torii silueti, seigaiha dalga deseni ve sakura çiçekleri.',
    14: 'Pers girih geometrisi, yıldız rozetleri ve turkuaz çini bezemeleri.',
    15: 'Rus mimarisinin kubbe formları, mine renkleri ve geleneksel geometrik bordürler.',
  };

  final _db = FirebaseFirestore.instance;
  bool _seeded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_seeded && AuthService.instance.isAdmin) {
      _seeded = true;
      _seedCatalogOnce();
    }
  }

  // Başlangıç kataloğu yalnızca bir kez hazırlanır. Yönetici tarafından
  // kaldırılan bir tema sonraki açılışta otomatik olarak geri eklenmez.
  Future<void> _seedCatalogOnce() async {
    final marker = _db.collection('app_config').doc('theme_catalog_initialized');
    final markerSnapshot = await marker.get();
    if (markerSnapshot.exists) return;

    final batch = _db.batch();
    for (final entry in _themes.entries) {
      final ref = _db.collection('cosmetic_catalog').doc('card_theme_${entry.key}');
      final existing = await ref.get();
      if (!existing.exists) {
        batch.set(ref, {
          'themeIndex': entry.key,
          'name': entry.value,
          'description': _descriptions[entry.key] ?? '',
          'priceStars': null,
          'isPublished': false,
          'sortOrder': entry.key,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
    batch.set(marker, {'initializedAt': FieldValue.serverTimestamp()});
    await batch.commit();
  }

  String _templateName(int index) {
    if (index >= 0 && index < CardFaceTheme.values.length) {
      return switch (CardFaceTheme.values[index]) {
        CardFaceTheme.classic => 'Klasik',
        CardFaceTheme.fruit => 'Meyve',
        CardFaceTheme.figure => 'Eski figür teması',
        CardFaceTheme.ottoman => 'Osmanlı motifleri',
        CardFaceTheme.egypt => 'Mısır motifleri',
        CardFaceTheme.rome => 'Roma motifleri',
        CardFaceTheme.animals => 'Eski hayvan teması',
        CardFaceTheme.chineseZodiac => 'Eski Çin teması',
        CardFaceTheme.matryoshka => 'Eski Matruşka teması',
        CardFaceTheme.soviet => 'Eski Sovyet teması',
        CardFaceTheme.india => 'Hindistan motifleri',
        CardFaceTheme.germany => 'Almanya motifleri',
        CardFaceTheme.france => 'Fransa motifleri',
        CardFaceTheme.japan => 'Japonya motifleri',
        CardFaceTheme.persia => 'Pers motifleri',
        CardFaceTheme.russia => 'Rusya motifleri',
      };
    }
    return 'Görsel şablon';
  }

  Future<void> _addTheme(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    final used = docs.map((d) => d.data()['themeIndex']).whereType<int>().toSet();
    final available = List.generate(CardFaceTheme.values.length, (i) => i)
        .where((i) => i >= 3 && !used.contains(i)).toList();
    if (available.isEmpty) {
      _message('Şu an tanımlı tüm görsel şablonlar katalogda. Yeni motif ailesi eklendiğinde burada seçilebilir olacak.');
      return;
    }

    int selected = available.first;
    final name = TextEditingController();
    final description = TextEditingController();
    final price = TextEditingController();
    final sortOrder = TextEditingController(text: '100');
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF17243A),
          title: const Text('Yeni tema ekle', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<int>(
                value: selected,
                dropdownColor: const Color(0xFF17243A),
                decoration: const InputDecoration(labelText: 'Görsel şablon', labelStyle: TextStyle(color: Colors.white70)),
                items: available.map((i) => DropdownMenuItem(value: i, child: Text(_templateName(i), style: const TextStyle(color: Colors.white)))).toList(),
                onChanged: (value) { if (value != null) setDialogState(() => selected = value); },
              ),
              TextField(controller: name, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Mağazada gösterilecek ad', labelStyle: TextStyle(color: Colors.white70))),
              TextField(controller: description, maxLines: 3, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Açıklama', labelStyle: TextStyle(color: Colors.white70))),
              TextField(controller: price, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Yıldız fiyatı', hintText: 'Boş bırak: taslak', hintStyle: TextStyle(color: Colors.white38), labelStyle: TextStyle(color: Colors.white70))),
              TextField(controller: sortOrder, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Mağaza sırası', labelStyle: TextStyle(color: Colors.white70))),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Ekle')),
          ],
        ),
      ),
    );
    if (saved != true) return;
    final cleanName = name.text.trim();
    if (cleanName.isEmpty) { _message('Tema adı boş bırakılamaz.'); return; }
    final parsedPrice = int.tryParse(price.text.trim());
    final doc = _db.collection('cosmetic_catalog').doc('card_theme_$selected');
    await doc.set({
      'themeIndex': selected,
      'name': cleanName,
      'description': description.text.trim(),
      'priceStars': parsedPrice != null && parsedPrice > 0 ? parsedPrice : null,
      'isPublished': false,
      'sortOrder': int.tryParse(sortOrder.text.trim()) ?? 100,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _edit(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data() ?? {};
    final name = TextEditingController(text: data['name'] as String? ?? '');
    final description = TextEditingController(text: data['description'] as String? ?? '');
    final price = TextEditingController(text: data['priceStars']?.toString() ?? '');
    final sortOrder = TextEditingController(text: (data['sortOrder'] as int? ?? 0).toString());
    var published = data['isPublished'] == true;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF17243A),
          title: Text('${name.text.isEmpty ? 'Tema' : name.text} ayarları', style: const TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Tema adı', labelStyle: TextStyle(color: Colors.white70))),
              TextField(controller: description, maxLines: 3, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Açıklama', labelStyle: TextStyle(color: Colors.white70))),
              TextField(controller: price, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Yıldız fiyatı', hintText: 'Boş bırak: satışa kapalı', hintStyle: TextStyle(color: Colors.white38), labelStyle: TextStyle(color: Colors.white70))),
              TextField(controller: sortOrder, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Mağaza sırası', helperText: 'Küçük sayı önce gösterilir', helperStyle: TextStyle(color: Colors.white54), labelStyle: TextStyle(color: Colors.white70))),
              SwitchListTile(
                value: published,
                onChanged: (v) => setDialogState(() => published = v),
                title: const Text('Mağazada yayınla', style: TextStyle(color: Colors.white)),
                activeThumbColor: GameUi.gold,
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Kaydet')),
          ],
        ),
      ),
    );
    if (saved != true) return;
    final parsedPrice = int.tryParse(price.text.trim());
    final validPrice = parsedPrice != null && parsedPrice > 0;
    await doc.reference.set({
      'name': name.text.trim(),
      'description': description.text.trim(),
      'priceStars': validPrice ? parsedPrice : null,
      'isPublished': published && validPrice && name.text.trim().isNotEmpty,
      'sortOrder': int.tryParse(sortOrder.text.trim()) ?? (data['sortOrder'] as int? ?? 0),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _remove(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final name = doc.data()?['name'] as String? ?? 'bu tema';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF17243A),
        title: const Text('Temayı katalogdan kaldır', style: TextStyle(color: Colors.white)),
        content: Text('"$name" mağazadan ve tema kataloğundan kaldırılacak. Daha önce açmış oyuncuların yerel tema kayıtları silinmez.', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), style: FilledButton.styleFrom(backgroundColor: const Color(0xFF9B3434)), child: const Text('Kaldır')),
        ],
      ),
    );
    if (confirmed == true) await doc.reference.delete();
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    if (!AuthService.instance.isAdmin) {
      return const Scaffold(body: Center(child: Text('Bu alan yalnızca yetkili yönetici hesabına açıktır.')));
    }
    return Scaffold(
      backgroundColor: const Color(0xFF101827),
      appBar: AppBar(
        title: const Text('Tema Yönetimi'),
        actions: [
          IconButton(
            tooltip: 'Yeni tema ekle',
            icon: const Icon(Icons.add_circle_outline, color: GameUi.gold),
            onPressed: () async {
              final snapshot = await _db.collection('cosmetic_catalog').get();
              if (mounted) await _addTheme(snapshot.docs);
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _db.collection('cosmetic_catalog').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Katalog yüklenemedi: ${snapshot.error}', style: const TextStyle(color: Colors.white70)));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs.toList()
            ..sort((a, b) => ((a.data()['sortOrder'] as int?) ?? 0).compareTo((b.data()['sortOrder'] as int?) ?? 0));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Tema ekleyebilir, düzenleyebilir, yayına alabilir veya katalogdan kaldırabilirsin. Fiyatı olmayan temalar mağazada görünmez. Yeni görsel motif aileleri eklendikçe ekleme seçenekleri de genişletilecek.', style: TextStyle(color: Colors.white70, height: 1.5)),
              const SizedBox(height: 14),
              if (docs.isEmpty)
                const Padding(padding: EdgeInsets.all(24), child: Text('Henüz tema yok. Sağ üstteki + düğmesiyle tema ekleyebilirsin.', style: TextStyle(color: Colors.white60))),
              for (final doc in docs)
                Card(
                  color: const Color(0xFF1B293D),
                  child: ListTile(
                    title: Text(doc.data()['name'] as String? ?? 'Tema', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    subtitle: Text(doc.data()['isPublished'] == true ? 'Yayında • ${doc.data()['priceStars']} yıldız' : 'Taslak / yayında değil', style: const TextStyle(color: Colors.white60)),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(icon: const Icon(Icons.edit_outlined, color: GameUi.gold), onPressed: () => _edit(doc)),
                      IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => _remove(doc)),
                    ]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
