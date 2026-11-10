# Firebase Authentication ve güvenli kanal kurulumu

Bu dalda kanal üyeliği cihaz kimliği yerine Firebase Authentication UID'siyle yapılır. Misafirler diğer oyun modlarını kullanabilir; oyuncu kanalları için hesap gerekir.

## 1. Firebase Authentication sağlayıcıları

Firebase Console → **stres-card** → Authentication → Sign-in method:

- **Email/Password** sağlayıcısını etkinleştir.
- **Google** sağlayıcısını etkinleştir ve destek e-posta adresini seç.
- Authentication ayarlarında projenin yetkili alan adlarını kontrol et.

E-posta ile hesap oluşturma kodu doğrulama e-postasını otomatik gönderir. Kullanıcı e-posta ile oturum açabilir; yönetici yetkisi için e-posta doğrulanmış olmalıdır.

## 2. Android Google OAuth istemcileri

Projede iki Android applicationId kullanılıyor:

- Geliştirme/önizleme: `com.example.stres_kart`
- Mağaza paketi: `com.selimilhan.stres` (release.config)

Firebase Console → Project settings → Your apps bölümünde bu iki Android uygulamasının da kayıtlı olması gerekir. Her uygulama için ilgili imza sertifikalarının **SHA-1 ve SHA-256** parmak izlerini ekle:

- Debug/önizleme APK'sının debug signing SHA parmak izleri.
- Yayın AAB'sini imzalayan upload key SHA parmak izleri.
- Google Play App signing sertifikasının SHA-1 ve SHA-256 parmak izleri (Play Console → App integrity).

Google sağlayıcısını etkinleştirdikten sonra Android uygulamasına ait güncel `google-services.json` dosyasını indirip `android/app/google-services.json` ile değiştir. Dosyanın `oauth_client` alanları boş olmamalı; Firebase'in Android ve Web OAuth istemcilerini üretmiş olması gerekir. Bu dosya güncellendikten sonra yeni APK derlenmelidir.

> Depodaki mevcut google-services.json dosyasında `oauth_client` ve `other_platform_oauth_client` dizileri boş. Bu nedenle Google girişinin kod tarafında tek başına çalışır hâle getirilmesi mümkün değil; Firebase Console'da OAuth istemcilerinin üretilmesi zorunlu.

## 3. Firestore güvenlik kurallarını canlı projeye yayımlama

Güvenlik kuralları kaynak dosyası `store/firestore.rules`; `firebase.json` bu dosyayı işaret eder. GitHub'a commit etmek canlı Firebase projesini değiştirmez.

GitHub Actions üzerinden yayımlamak için Firebase projesinde **Firebase Rules Admin** yetkisine sahip bir servis hesabı oluştur. JSON anahtarını GitHub deposunun Settings → Secrets and variables → Actions bölümüne `FIREBASE_SERVICE_ACCOUNT_STRES_CARD` adıyla ekle. Ardından Actions → **Firestore Kurallarını Canlı Projeye Yayımla** iş akışını çalıştır. İş akışı yalnızca `store/firestore.rules` dosyasını yayımlar.

Alternatif olarak Firebase CLI ile yetkili oturum açıp proje kökünde şu komutu çalıştırabilirsin:

```bash
firebase deploy --only firestore:rules --project stres-card
```

Yayımlamadan önce Firebase Console'da doğru projenin **stres-card** olduğunu doğrula. Eski uygulama sürümleri cihaz kimliğiyle kanal işlemi yapıyordu; yeni kurallar kanal işlemlerinde Firebase hesabı UID'si ister. Yeni APK ve kurallar birlikte devreye alınmalıdır.

## 4. Yeni güvenlik davranışı

- Public kanallar yalnızca giriş yapmış hesaplar tarafından listelenebilir.
- Private kanal dokümanı ve üye listesi yalnızca kanal üyelerine okunabilir.
- Davet kodları `channel_invites/{CODE}` dokümanında tutulur; kod koleksiyonu listelenemez, yalnızca kodu bilen kullanıcı tek dokümanı okuyabilir.
- Private katılım aynı batch içinde davet kodu + kullanıcı UID'siyle üyelik oluşturur.
- Turnuvalar yalnızca kanal üyelerine görünür; kurucu başlatır; katılımcı yalnızca kendi UID'sini kayıt listesine ekleyebilir.
- Misafir oyun odaları ve genel oyun akışı bu kanal kimlik değişikliğinden etkilenmez.

## 5. Eski kanal kayıtları

Önceki sürümlerin `ownerDeviceId` ve üye belge kimlikleri cihaz kimliğiydi. Yeni kurallar bunları otomatik olarak güvenilir hesap UID'si kabul etmez. Eski kanalların gerekiyorsa kontrollü bir yönetici/veri migrasyonu yapılmalıdır; eski belgeleri herkese açık bırakmak güvenli bir geçiş yöntemi değildir.
