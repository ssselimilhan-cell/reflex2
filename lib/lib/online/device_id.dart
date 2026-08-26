import 'dart:math';

/// Bu oturuma özel basit bir kimlik üretir (kalıcı değil).
/// İleride shared_preferences ile cihaza kalıcı kaydetmek daha sağlam olur.
String generateSessionDeviceId() {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final rnd = Random();
  return List.generate(16, (_) => chars[rnd.nextInt(chars.length)]).join();
}
