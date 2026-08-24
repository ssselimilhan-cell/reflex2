# Stres (Refleks) Kart Oyunu — Flutter Projesi

## Oyun kuralları (uygulanan hali)

1. 52 kağıt karılır.
2. 26 kağıt Oyuncu 1'e, 26 kağıt Oyuncu 2'ye verilir.
3. Her oyuncunun 4 kağıdı oyun alanına yerleştirilir → toplam **8 kolon**.
   Kolon 0-3 Oyuncu 1'in önünde, Kolon 4-7 Oyuncu 2'nin önünde.
4. Kalan 22'şer kağıt her oyuncunun kapalı destesi (kaynak) olur.
5. 8 açık kart, ikişerli ve karşılıklı olacak şekilde 0.5 saniye
   aralıklarla açılır (toplam 2 saniye) — bu görsel animasyon uygulanmıştır.
6. Başlangıç düzeni tamamlanınca gerçek oyun başlar.
7. 8 kolonun üst kartları sürekli kontrol edilir.
8. Üst kartı aynı değere sahip **en az 2 kolon** varsa, bu kolonlar
   tıklanabilir (aktif) hale gelir.
9. **İki oyuncu da** tüm aktif kolonlara tıklayabilir — kolonun kime ait
   olduğu fark etmez.
10. Bir oyuncu aktif bir kolona tıklarsa: kendi kapalı destesinden bir kart
    çekilir, açılır ve tıklanan kolonun üzerine konur.
11-12. Kolonlar yeniden değerlendirilir; yeni eşleşme varsa oyun sürer.
13. Eşleşme kalmayınca: her oyuncu kendi 4 kolonundaki (0-3 / 4-7) TÜM
    kartları toplar, kendi kapalı destesine ekler.
14. Toplanan kartlar karılır (varsayım — rastgeleliği korumak için), yeniden
    4'er kart açılarak (2 saniyelik animasyonla) oyun devam eder.
15. Kapalı destesini ilk tamamen bitiren oyuncu kazanır.

**Önemli detay:** Kural 9 sayesinde bir oyuncu, kendi kartını KARŞI
oyuncunun kolonuna da koyabilir. Kilitlenme anında o kart karşı oyuncunun
kapalı destesine eklenir — yani rakibinizin önündeki aktif kolonlara oynamak,
elinizdeki kartı ona "hediye etmek" anlamına gelir. Bu, oyuna stratejik bir
boyut katıyor (kuralları birebir bu şekilde tarif ettiğiniz için bu yorum
üzerinden ilerledim; farklı bir davranış istersen `game_engine.dart`
dosyasındaki `attemptPlay` fonksiyonunu güncelleriz).

## Yeni: Ayarlar, Skor Tabelası, Dil Desteği

- `lib/settings/app_settings.dart` — kalıcı (cihazda saklanan) ayarlar: kart
  boyutu, yazı boyutu, arka plan rengi, kart arkası rengi, açılış animasyon
  hızı, yüksek kontrast, dil (TR/EN)
- `lib/settings/strings.dart` — basit çeviri sözlüğü
- `lib/settings/score_board.dart` — oturum boyunca kalan skor sayaçları
  (uygulama kapanınca sıfırlanır, kalıcı kaydedilmez)
- `lib/screens/settings_screen.dart` — ayarlar ekranı, ana menüden erişilir
- Bota karşı modda artık **Duraklat** düğmesi (bot durur, dokunuşlar kilitlenir)
  ve zorluk kaydırıcısında **yeşilden kırmızıya geçen renk + yüzde göstergesi** var

`shared_preferences` paketi eklendi — Codespace'te mutlaka:
```bash
flutter pub get
```
çalıştırman gerekiyor (yeni paketi indirmek için), sonra normal şekilde
`flutter build apk --debug`.

## Proje yapısı

- `lib/models/playing_card.dart` — kart modeli + Firestore için kod
  serileştirme (`toCode`/`fromCode`)
- `lib/game/game_engine.dart` — oyun motoru (8 kolon, eşleşme, toplama,
  yeniden dağıtım, kazanma kontrolü)
- `lib/game/bot_ai.dart` — zorluk ayarlanabilir basit bot
- `lib/screens/local_pvp_screen.dart` — aynı cihazda 2 kişilik mod (ekranın
  iki yarısında da 8 kolonun tamamı gösterilir, her yarı kendi kaynağıyla
  oynar)
- `lib/screens/vs_bot_screen.dart` — bilgisayara karşı mod
- `lib/screens/online_lobby_screen.dart` — oda kur / koda katıl
- `lib/screens/online_game_screen.dart` — Firestore ile senkronize online mod
- `lib/online/firestore_game_repository.dart` — oda oluşturma/katılma ve
  transaction ile çakışmasız hamle uygulama

## GitHub Codespaces ile SIFIRDAN kurulum (tarayıcıdan, kurulum gerektirmez)

### 1. Yeni bir GitHub deposu oluştur
- github.com'da sağ üstten "+" → "New repository" → isim ver (örn.
  `stres-kart-v2`) → oluştur.
- Önceki denemede karışıklık olduysa **yeni bir depo** açman en temizi.

### 2. Proje dosyalarını yükle
- Sana verdiğim zip'i bilgisayarında bir klasöre çıkart.
- Depo sayfasında "uploading an existing file" linkine tıkla.
- **`stres_kart` klasörünün İÇİNDEKİ** tüm dosya ve klasörleri (pubspec.yaml,
  lib, README.md — ama `.devcontainer` klasörünü değil, bir sonraki adımda
  onu elle ekleyeceğiz çünkü tarayıcıdan sürükle-bırak gizli/nokta ile
  başlayan klasörleri bazen atlıyor) oraya sürükle-bırak, "Commit changes"
  de.

### 3. .devcontainer dosyasını elle ekle (önemli — bir önceki denemede eksik kalan buydu)
- Depo sayfasında "Add file" → "Create new file".
- Dosya adı kutusuna tam olarak şunu yaz: `.devcontainer/devcontainer.json`
- İçeriğe şunu yapıştır:
```json
{
  "name": "Flutter Dev Ortamı",
  "image": "ghcr.io/cirruslabs/flutter:stable",
  "features": {
    "ghcr.io/devcontainers/features/java:1": { "version": "17" }
  },
  "postCreateCommand": "flutter pub get"
}
```
- "Commit changes" de.
- Depo ana sayfasına dönüp dosya listesinde `.devcontainer` klasörünün
  göründüğünü DOĞRULA — bu sefer görünmeli.

### 4. Codespace'i başlat
- Yeşil "Code" butonu → "Codespaces" sekmesi → "Create codespace on main".
- İlk açılışta Flutter + Android SDK içeren imaj indirileceği için 3-5 dakika
  sürebilir.

### 5. Eksik Android proje dosyalarını oluştur (bir önceki hatanın çözümü)
Terminalde:
```bash
flutter create --project-name stres_kart --org com.example .
flutter pub get
```
Bu komut var olan `lib/` ve `pubspec.yaml`'a dokunmaz, sadece eksik olan
`android/` klasörünü ekler.

### 6. Derle
```bash
flutter build apk --debug
```
Bitince sol panelde `build/app/outputs/flutter-apk/app-debug.apk` dosyasını
bulup sağ tık → Download ile bilgisayarına indirebilirsin. Sonra bu dosyayı
telefonuna aktarıp (WhatsApp/Drive/USB) kurup test edebilirsin.

## Online mod için Firebase kurulumu

Online mod kodu hazır ama çalışması için kendi Firebase projeni bağlaman
gerekiyor:

1. https://console.firebase.google.com → "Add project" → isim ver → oluştur.
2. Sol menüden "Firestore Database" → "Create database" → "Start in test
   mode" seç (geliştirme için yeterli; yayına almadan önce güvenlik
   kurallarını sıkılaştır — aşağıda örnek var).
3. Codespace terminalinde:
   ```bash
   dart pub global activate flutterfire_cli
   npm install -g firebase-tools
   firebase login --no-localhost
   ```
   (`firebase login --no-localhost` tarayıcı linki verir, o linke tıklayıp
   giriş yaptıktan sonra çıkan kodu terminale yapıştırırsın — Codespaces
   gibi tarayıcı tabanlı ortamlarda normal `firebase login` yerine bunu
   kullanmak gerekir.)
4. Proje klasöründe:
   ```bash
   flutterfire configure
   ```
   Firebase projeni seç, platform olarak "android" işaretle. Bu komut
   `lib/firebase_options.dart` dosyasını otomatik, gerçek bilgilerinle
   yeniden yazacak.
5. `flutter pub get` sonra `flutter build apk --debug` ile tekrar derle.
6. İki farklı cihazda (ya da emülatör + telefon) test et: birinde "Yeni Oda
   Kur", diğerinde çıkan 4 haneli kodla "Odaya Katıl".

### Güvenlik kuralı örneği (yayına almadan önce)
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /rooms/{roomId} {
      allow read: if true;
      allow create: if true;
      allow update: if true;
    }
  }
}
```

## Play Store'a yayınlama (özet)

1. Google Play Console hesabı aç (~25 USD tek seferlik):
   https://play.google.com/console
2. `android/app/build.gradle` içinde `applicationId`'yi kendine özgü bir
   değere çevir (örn. `com.senin_adin.streskart`).
3. İmzalama anahtarı oluştur, `android/key.properties` ile tanımla (Flutter
   dokümantasyonu "Sign the app" bölümü adım adım anlatıyor).
4. Yayınlanabilir paket:
   ```bash
   flutter build appbundle --release
   ```
5. Play Console'da yeni uygulama oluştur, mağaza bilgilerini doldur
   (açıklama, kategori: Oyun > Kart, içerik derecelendirme anketi, bir
   gizlilik politikası linki), `.aab` dosyasını yükle.

## Henüz yapılmadı

- Firebase Anonymous Auth ile daha güvenli oyuncu kimliği
- Ses efektleri, animasyonlar, skor tablosu
- Uygulama ikonu ve splash screen
