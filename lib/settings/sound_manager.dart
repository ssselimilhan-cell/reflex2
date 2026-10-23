import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'app_settings.dart';

enum Sfx { play, deal, streak, win, lose, nomatch }

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

  void _haptic(Sfx sfx) {
    try {
      switch (sfx) {
        case Sfx.play:
          HapticFeedback.lightImpact();
        case Sfx.streak:
        case Sfx.win:
          HapticFeedback.heavyImpact();
        case Sfx.lose:
        case Sfx.nomatch:
          HapticFeedback.mediumImpact();
        case Sfx.deal:
          break;
      }
    } catch (_) {}
  }

  Future<void> play(Sfx sfx) async {
    if (AppSettings.instance.hapticsEnabled) _haptic(sfx);
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
