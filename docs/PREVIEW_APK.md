# Preview APK oluşturma

Bu dalda önizleme APK'sı `.github/workflows/build-apk.yml` iş akışıyla üretilir.

- İş akışı önce `flutter test` ve `flutter analyze --no-fatal-infos` kontrollerini çalıştırır.
- Kontroller başarılıysa, commit mesajında `[build-preview-apk]` bulunduğunda imzalı release önizleme APK'sı oluşturur.
- APK, GitHub Actions çalıştırmasının `reflex2-preview-apk` adlı artifact'i olarak 7 gün saklanır.
- Manuel çalıştırmada GitHub Actions > Flutter Testleri > Run workflow bölümünden `build_preview_apk` seçeneği etkinleştirilebilir.

Önizleme derlemesi yalnızca `redesign/modern-competitive` geliştirme dalı içindir; `main` dalına yayın yapmaz.
