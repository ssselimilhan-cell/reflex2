import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_settings.dart';
import 'user_profile.dart';

/// Çok hafif, anonim ölçüm ve hata kaydı. Üçüncü taraf SDK kullanmaz:
/// olaylar kendi Firestore'umuza (app_events, app_errors) yazılır; kayıtları
/// yalnızca sen Firebase Console'dan görürsün. Ayarlar'dan kapatılabilir.
/// Oturum başına sınırlıdır (çok fazla yazma/maliyet olmasın diye).
class Telemetry {
  /// main.dart, Firebase başarıyla başlatılınca true yapar.
  static bool ready = false;

  static const String appVersion = '1.0.0';
  static const int _maxEvents = 25;
  static const int _maxErrors = 5;
  static int _events = 0;
  static int _errors = 0;

  static Future<void> _write(String collection, Map<String, Object?> data) async {
    try {
      await FirebaseFirestore.instance.collection(collection).add(data);
    } catch (_) {}
  }

  static bool get _on => ready && AppSettings.instance.telemetryEnabled;

  /// Örn. Telemetry.log('game_end', {'mode': 'bot', 'won': true});
  static void log(String name, [Map<String, Object?> params = const {}]) {
    if (!_on || _events >= _maxEvents) return;
    _events++;
    _write('app_events', {
      'name': name,
      'params': params,
      'deviceId': UserProfile.instance.deviceId,
      'lang': AppSettings.instance.language.name,
      'appVersion': appVersion,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static String _cut(String s, int n) => s.length > n ? s.substring(0, n) : s;

  static void error(Object error, StackTrace? stack) {
    if (!_on || _errors >= _maxErrors) return;
    _errors++;
    _write('app_errors', {
      'message': _cut('$error', 400),
      'stack': _cut('${stack ?? ''}', 1500),
      'deviceId': UserProfile.instance.deviceId,
      'appVersion': appVersion,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
