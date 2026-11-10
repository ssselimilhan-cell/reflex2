import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
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
      _seedCatalog();
    }
  }

  Future<void> _seedCatalog() async {
    final batch = _db.batch();
    for (final entry in _themes.entries) {
      final ref = _db.collection('cosmetic_catalog').doc('card_theme_${entry.key}');
      final existing = await ref.get();
      if (!existing.exists) {
        batch.set(ref, {
          'themeIndex': entry.key,
          'name': entry.value,
          'description': _descriptions[entry.key] ?? 'Kültürel motiflerle hazırlanmış özel kart tasarımı.',
          'priceStars': null,
          'isPublished': false,
          'sortOrder': entry.key,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
    await batch.commit();
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

  @override
  Widget build(BuildContext context) {
    if (!AuthService.instance.isAdmin) {
      return const Scaffold(body: Center(child: Text('Bu alan yalnızca yetkili yönetici hesabına açıktır.')));
    }
    return Scaffold(
      backgroundColor: const Color(0xFF101827),
      appBar: AppBar(title: const Text('Tema Yönetimi')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _db.collection('cosmetic_catalog').orderBy('sortOrder').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Katalog yüklenemedi: ${snapshot.error}', style: const TextStyle(color: Colors.white70)));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Tema adını, açıklamasını ve yıldız fiyatını buradan belirleyebilirsin. Fiyatı olmayan temalar mağazada görünmez.', style: TextStyle(color: Colors.white70, height: 1.5)),
              const SizedBox(height: 14),
              for (final doc in snapshot.data!.docs)
                Card(
                  color: const Color(0xFF1B293D),
                  child: ListTile(
                    title: Text(doc.data()['name'] as String? ?? 'Tema', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    subtitle: Text(doc.data()['isPublished'] == true ? 'Yayında • ${doc.data()['priceStars']} yıldız' : 'Taslak / yayında değil', style: const TextStyle(color: Colors.white60)),
                    trailing: IconButton(icon: const Icon(Icons.edit_outlined, color: GameUi.gold), onPressed: () => _edit(doc)),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
