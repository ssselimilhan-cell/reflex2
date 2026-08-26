import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// Önceki 'device_id.dart' oturum bazlıydı (her açılışta değişiyordu).
/// Profil ve online istatistikler için CİHAZDA KALICI bir kimlik gerekiyor
/// — bu yüzden bir kere üretilip SharedPreferences'a kaydediliyor, sonraki
/// açılışlarda aynısı okunuyor.
Future<String> getPersistentDeviceId() async {
  final prefs = await SharedPreferences.getInstance();
  var id = prefs.getString('persistentDeviceId');
  if (id == null) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rnd = Random();
    id = List.generate(20, (_) => chars[rnd.nextInt(chars.length)]).join();
    await prefs.setString('persistentDeviceId', id);
  }
  return id;
}
