// BU DOSYA GEÇİCİDİR.
// Aşağıdaki komutu proje klasöründe çalıştırdığında bu dosya senin
// gerçek Firebase proje bilgilerinle OTOMATİK olarak yeniden oluşturulacak:
//
//   flutterfire configure
//
// O komutu çalıştırmadan önce uygulamayı derlemeye çalışırsan hata alırsın,
// bu normaldir. README.md'deki "Online mod için Firebase kurulumu"
// bölümünü takip et.

import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    throw UnsupportedError(
      'DefaultFirebaseOptions henüz ayarlanmadı. '
      'Proje klasöründe "flutterfire configure" komutunu çalıştır.',
    );
  }
}
