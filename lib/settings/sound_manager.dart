import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'app_settings.dart';

enum Sfx { play, deal, streak, win, lose, nomatch, message }

/// Kısa ses efektlerini ve hafif titreşimleri tetikler. Ses ve titreşim
/// ayrı ayrı kapatılabilir. Herhangi bir hata oyunu ASLA bozmaz.
///
/// Her ses için 3 oynatıcı SIRAYLA kullanılır: art arda hızlı hamlelerde
/// bir önceki ses bitmeden yenisi başka oynatıcıda çalar.
class SoundManager {
  SoundManager._();
  static final SoundManager instance = SoundManager._();

  static const int _poolSize = 3;
  final Map<Sfx, List<AudioPlayer>> _pools = {};
  final Map<Sfx, int> _next = {};

  Future<void> _haptic(Sfx sfx) async {
    try {
      switch (sfx) {
        case Sfx.play:
          await HapticFeedback.lightImpact();
          break;
        case Sfx.streak:
        case Sfx.win:
          await HapticFeedback.heavyImpact();
          break;
        case Sfx.lose:
        case Sfx.nomatch:
          await HapticFeedback.mediumImpact();
          break;
        case Sfx.deal:
          break;
        case Sfx.message:
          await HapticFeedback.selectionClick();
          break;
      }
    } catch (_) {
      // Desteklenmeyen cihaz/kanal hatası oyunu etkilemesin.
    }
  }

  /// Ayarlar ekranındaki "Dene" düğmesi için doğrudan cihaz titreşimi.
  Future<void> testHaptics() async {
    if (!AppSettings.instance.hapticsEnabled) return;
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {
      // Bazı cihazlar sistem titreşim geri bildirimini devre dışı bırakabilir.
    }
  }

  Future<void> play(Sfx sfx) async {
    if (AppSettings.instance.hapticsEnabled) await _haptic(sfx);
    if (!AppSettings.instance.soundEnabled) return;
    try {
      final pool = _pools.putIfAbsent(
          sfx, () => List.generate(_poolSize, (_) => AudioPlayer()));
      final i = _next[sfx] ?? 0;
      _next[sfx] = (i + 1) % _poolSize;
      await pool[i].play(AssetSource('sounds/${sfx.name}.wav'));
    } catch (_) {}
  }
}
