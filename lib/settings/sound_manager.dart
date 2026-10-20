import 'package:audioplayers/audioplayers.dart';
import 'app_settings.dart';

enum Sfx { play, deal, streak, win, lose, nomatch }

/// Kısa ses efektlerini çalar. Ayarlardan (ya da oyun içi hoparlör
/// ikonundan) kapatılabilir. Herhangi bir ses hatası oyunu ASLA
/// bozmaz — hepsi sessizce yutulur.
class SoundManager {
  SoundManager._();
  static final SoundManager instance = SoundManager._();

  final Map<Sfx, AudioPlayer> _players = {};

  Future<void> play(Sfx sfx) async {
    if (!AppSettings.instance.soundEnabled) return;
    try {
      var p = _players[sfx];
      if (p == null) {
        p = AudioPlayer();
        await p.setPlayerMode(PlayerMode.lowLatency);
        _players[sfx] = p;
      }
      await p.play(AssetSource('sounds/${sfx.name}.wav'));
    } catch (_) {}
  }
}
