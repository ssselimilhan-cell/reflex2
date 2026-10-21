import 'package:audioplayers/audioplayers.dart';
import 'app_settings.dart';

enum Sfx { play, deal, streak, win, lose, nomatch }

/// Kısa ses efektlerini çalar. Ayarlardan (ya da oyun içi hoparlör
/// ikonundan) kapatılabilir. Herhangi bir ses hatası oyunu ASLA
/// bozmaz — hepsi sessizce yutulur.
///
/// Her ses için 3 oynatıcı SIRAYLA kullanılır: art arda hızlı hamlelerde
/// bir önceki ses bitmeden yenisi başka oynatıcıda çalar. (Önceki sürümde
/// "düşük gecikme" modunda tek oynatıcı kullanılıyordu; ilk sesten sonra
/// takılıyordu.)
class SoundManager {
  SoundManager._();
  static final SoundManager instance = SoundManager._();

  static const int _poolSize = 3;
  final Map<Sfx, List<AudioPlayer>> _pools = {};
  final Map<Sfx, int> _next = {};

  Future<void> play(Sfx sfx) async {
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
