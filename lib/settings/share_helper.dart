import 'package:share_plus/share_plus.dart';
import 'app_links.dart';
import 'strings.dart';
import 'telemetry.dart';

/// Oda kodunu sistem paylaşım penceresiyle (WhatsApp vb.) gönderir.
Future<void> shareRoomCode(String code) async {
  Telemetry.log('share_room');
  try {
    await Share.share(t('share_room_text')
        .replaceAll('{code}', code)
        .replaceAll('{url}', kStoreUrl));
  } catch (_) {}
}

/// Uygulamayı (mağaza bağlantısıyla) arkadaşa önerir.
Future<void> shareApp() async {
  Telemetry.log('share_app');
  try {
    await Share.share(t('share_app_text').replaceAll('{url}', kStoreUrl));
  } catch (_) {}
}
