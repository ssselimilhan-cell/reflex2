# STRES – Play Store'a Yayın Rehberi (adım adım)

Tüm komutlar **Codespace terminalinde, proje klasöründe** çalıştırılır. Gerçek derlemeyi sen yapıyorsun; kodu yalnızca yapı olarak kontrol edebildim.

## 0. Önce karar ver
- **Uygulama adı:** `STRES - Refleks Kart Oyunu` (istersen değiştir, en fazla 30 karakter).
- **Paket adı:** `com.seninadin.stres` gibi, **küçük harf**, nokta ayrımlı. `com.example` ile başlayamaz. **Yayından sonra değiştirilemez**, iyi düşün.

## 1. Kodu al ve ikonları üret
```
git pull
flutter pub get
dart run flutter_launcher_icons
```
(Yeni ikon `assets/icon/` içinde hazır. Komut, android klasöründeki ikonları üretir.)

## 2. Android ayarlarını tek komutla hazırla
```
bash tools/prepare_android_release.sh "STRES - Refleks Kart Oyunu" com.seninadin.stres
```
Bu komut: uygulama adını ve paket adını değiştirir, **internet iznini ekler** (bu olmadan yayın sürümünde online mod çalışmaz), imza ayarını ekler. Dosyaların yedeği `.bak-release` olarak kalır. Hata verirse mesajı bana yapıştır.

## 3. Firebase tarafı
1. **Kurallar:** Firebase Console → Firestore → Rules. `store/firestore.rules` dosyasının **tamamını** yapıştır → Publish. (Liderlik tablosu ve şikayet koleksiyonları için gerekli.)
2. **Dizin:** liderlik tablosu ilk açılışta "index gerekli" derse mesajdaki linke tıkla → Create. Elle: koleksiyon `game_results`, alanlar `won` (Artan) + `playedAt` (Artan).
3. **Yeni paket adı için Firebase kaydı (önerilir):** `flutterfire configure` komutunu yeniden çalıştır, `stres-card` projesini seç, Android için yeni paket adını gir (sormazsa `flutterfire configure --android-package-name=com.seninadin.stres`). Bu `lib/firebase_options.dart` dosyasını günceller. Atlarsan oyun çoğunlukla yine çalışır ama Firebase'deki kayıtlı uygulama adı eski kalır.

## 4. Yükleme anahtarı (imza) oluştur
```
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
Sorulan şifreyi ve bilgileri bir yere yaz. Sonra `android/key.properties` dosyasını oluştur (parolaları kendinle değiştir):
```
cat > android/key.properties << 'KEY'
storePassword=ŞİFREN
keyPassword=ŞİFREN
keyAlias=upload
storeFile=/home/vscode/upload-keystore.jks
KEY
```
`storeFile` yolunu `echo ~` çıktına göre ayarla. `key.properties` ve `.jks` dosyaları Flutter'ın `.gitignore`'ı sayesinde GitHub'a gitmez; **gitmemeli**.

**ÇOK ÖNEMLİ:** `upload-keystore.jks` dosyasını Codespace'ten **kendi bilgisayarına indir ve iki yerde yedekle**. Codespace silinirse anahtar da gider, uygulamayı bir daha güncelleyemezsin (Google desteğiyle sıfırlama mümkün ama zahmetli).

## 5. Önce yayın APK'sını telefonda dene
```
flutter build apk --release
```
`build/app/outputs/flutter-apk/app-release.apk` dosyasını kur. Online mod, lobi, liderlik tablosu ve sesleri dene. **Yayın sürümü hata mantığı debug'dan farklıdır**, bu adımı atlama.

## 6. Mağaza paketini derle
```
flutter build appbundle --release
```
Dosya: `build/app/outputs/bundle/release/app-release.aab`. Bir sonraki sürümde `pubspec.yaml` içindeki `version: 1.0.0+1` satırında `+` sonrasını artır (`1.0.1+2`).

## 7. Gizlilik politikasını yayınla
`store/privacy_policy.html` içindeki sarı yerleri doldur (tarih, adın, e-posta). Play'in **herkese açık bir URL** istiyor. Kodun GitHub'da özel (private) ise Pages ücretsiz çalışmaz. En kolayı: yeni, **herkese açık** bir depo aç (örn. `stres-gizlilik`), bu tek dosyayı `index.html` adıyla yükle, Settings → Pages → main / root. Adres: `https://KULLANICIADIN.github.io/stres-gizlilik/`.

## 8. Play Console
1. play.google.com/console → **Uygulama oluştur** (ad, dil Türkçe, Uygulama, Ücretsiz).
2. **Mağaza girişi:** `store/STORE_LISTING.md` metinleri + `play_store_icon_512.png` + `feature_graphic_1024x500.png` + en az 2 gerçek ekran görüntüsü.
3. **Uygulama içeriği:** gizlilik politikası URL'si, reklam yok, içerik derecelendirme anketi, hedef kitle, **Veri güvenliği** formu (cevaplar STORE_LISTING.md'de).
4. **Test → Kapalı test:** `.aab` dosyasını yükle, **en az 12 test kullanıcısı** ekle (e-posta listesi ya da Google grubu) ve **14 gün** bekle (bireysel hesaplarda şart).
5. 14 gün sonra **Üretim için başvur** → onaydan sonra Üretim sürümü.
6. İlk inceleme birkaç gün sürebilir.

## 9. Bilmen gereken eksikler ve riskler (dürüstçe)
- **Kullanıcı engelleme yok.** Şikayet var (online ekranda bayrak ikonu), ama Google, kullanıcıların birbirine yazdığı uygulamalarda engelleme de bekleyebilir. İncelemede takılırsa söyle, sohbeti gizleme/engelleme ekleriz.
- **Ekran görüntülerini ben üretemem**, gerçek telefondan alınmalı.
- **Liderlik tablosu maliyeti:** her açılışta ilgili dönemdeki tüm kazanma kayıtlarını okur. Oyuncu sayısı büyüyünce Firestore ücretsiz kotası (günlük 50 bin okuma) aşılabilir. Büyürsen günlük özet kayıtlarına geçmek gerekir.
- **Silme:** Profili Sil, profil kaydını siler; `game_results` kayıtları istemciden silinemez, politika bunu e-posta talebiyle karşılar.
- **Ses:** bazı telefonlarda efekt çalarken arka plandaki müzik kısılabilir/duraklayabilir. Olursa söyle.
- **Firebase App Check** açık değil; ileride kötüye kullanıma karşı eklenebilir.
- Kart temaları emoji ile gösteriliyor; emoji görünümü telefon markasına göre biraz değişir.
