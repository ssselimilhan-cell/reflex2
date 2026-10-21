import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'strings.dart';

/// Google Play "Kullanıcı Tarafından Oluşturulan İçerik" politikası için:
/// kullanım koşullarının kabulü ve oyuncu engelleme. Veriler cihazda tutulur.
class Moderation extends ChangeNotifier {
  Moderation._();
  static final Moderation instance = Moderation._();

  bool termsAccepted = false;

  /// deviceId -> görünen ad (engellenenler listesinde göstermek için).
  final Map<String, String> blocked = {};

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      termsAccepted = prefs.getBool('termsAccepted') ?? false;
      for (final e
          in prefs.getStringList('blockedPlayers') ?? const <String>[]) {
        final i = e.indexOf('|');
        if (i <= 0) continue;
        blocked[e.substring(0, i)] = e.substring(i + 1);
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('termsAccepted', termsAccepted);
      await prefs.setStringList('blockedPlayers',
          blocked.entries.map((e) => '${e.key}|${e.value}').toList());
    } catch (_) {}
  }

  bool isBlocked(String? deviceId) =>
      deviceId != null && blocked.containsKey(deviceId);

  Future<void> block(String deviceId, String? name) async {
    blocked[deviceId] = (name == null || name.isEmpty) ? '?' : name;
    notifyListeners();
    await _persist();
  }

  Future<void> unblock(String deviceId) async {
    blocked.remove(deviceId);
    notifyListeners();
    await _persist();
  }

  Future<void> acceptTerms() async {
    termsAccepted = true;
    notifyListeners();
    await _persist();
  }
}

/// Online özelliklere (lobi, liderlik tablosu) ve profil oluşturmaya
/// girmeden önce kullanım koşullarının kabulünü ister. Kabul edildiyse
/// ya da daha önce kabul edilmişse true döner.
Future<bool> ensureTermsAccepted(BuildContext context) async {
  if (Moderation.instance.termsAccepted) return true;
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: Text(t('terms_title')),
      content: SingleChildScrollView(child: Text(t('terms_body'))),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(t('decline')),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(t('accept')),
        ),
      ],
    ),
  );
  if (ok == true) {
    await Moderation.instance.acceptTerms();
    return true;
  }
  return false;
}

/// Engellenen oyuncuların listesi; buradan engel kaldırılabilir.
Future<void> showBlockedPlayersDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(t('blocked_players')),
      content: SizedBox(
        width: double.maxFinite,
        child: AnimatedBuilder(
          animation: Moderation.instance,
          builder: (context, _) {
            final entries = Moderation.instance.blocked.entries.toList();
            if (entries.isEmpty) return Text(t('blocked_empty'));
            return ListView(
              shrinkWrap: true,
              children: entries
                  .map((e) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(e.value),
                        trailing: TextButton(
                          onPressed: () => Moderation.instance.unblock(e.key),
                          child: Text(t('unblock')),
                        ),
                      ))
                  .toList(),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(t('close_invite')),
        ),
      ],
    ),
  );
}
