import 'dart:math';

/// Bot Yolu'ndaki bir seviyenin bot ayarları (1-100).
///
/// Seviye 1-10: eski "zorluk çubuğu" (%0-%100) ile birebir aynı davranış
/// (yavaş, hata yapan, rastgele oynayan bot). Seviye 10, eski en zor bot.
/// Seviye 11-100: bu eşiğin ÜSTÜ — daha hızlı tepki, hata yok ve giderek
/// akıllanan seçim:
///  - smartness: kartını rakibin kolonuna atma eğilimi. El yenilenince
///    her oyuncu KENDİ 4 kolonundaki kartları toplar; yani kartı rakibin
///    kolonuna atan, kartından kalıcı olarak kurtulur.
///  - chainSkill: oynadığı kartın yeni bir eşleşme doğuracağı kolonu
///    seçme eğilimi (art arda hamle bonusunu besler).
///  - ownSidePlay: rakip tarafında aktif kolon yokken kendi tarafındaki
///    kolona oynama olasılığı. Simülasyonda beklemenin botu zayıflattığı
///    görüldü (tempo kaybı, art arda hamle bonusu kaçıyor), bu yüzden 1.
class BotProfile {
  static const int maxLevel = 100;

  final int level;
  final int baseMs;
  final int jitterMs;
  final double missChance;
  final double smartness;
  final double chainSkill;
  final double ownSidePlay;

  const BotProfile._({
    required this.level,
    required this.baseMs,
    required this.jitterMs,
    required this.missChance,
    required this.smartness,
    required this.chainSkill,
    required this.ownSidePlay,
  });

  /// Ortalama tepki süresi (ms) — ekranda gösterilir.
  int get meanReactionMs => baseMs + jitterMs ~/ 2;

  factory BotProfile.forLevel(int level) {
    final int l = level.clamp(1, maxLevel).toInt();
    if (l <= 10) {
      final d = (l - 1) / 9.0;
      return BotProfile._(
        level: l,
        baseMs: (900 - 700 * d).round(),
        jitterMs: 300,
        missChance: (1 - d) * 0.4,
        smartness: 0,
        chainSkill: 0,
        ownSidePlay: 1,
      );
    }
    final p = (l - 10) / 90.0;
    final smart = ((l - 10) / 30.0).clamp(0.0, 1.0).toDouble();
    final chain = ((l - 20) / 60.0).clamp(0.0, 1.0).toDouble();
    return BotProfile._(
      level: l,
      baseMs: (200 - 120 * pow(p, 0.8)).round(),
      jitterMs: (300 - 250 * pow(p, 0.6)).round(),
      missChance: 0,
      smartness: smart,
      chainSkill: chain,
      ownSidePlay: 1,
    );
  }
}
