// lib/services/sound_fx.dart
import 'package:audioplayers/audioplayers.dart';

class SoundFx {
  SoundFx._();
  static final SoundFx instance = SoundFx._();

  final AudioPlayer _player = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
  bool enabled = true;
  bool _preloaded = false;

  Future<void> preload() async {
    if (_preloaded) return;
    try {
      // Pré-carrega a fonte (ok para Web/Mobile)
      await _player.setSourceAsset('sounds/abrir_garrafa.mp3');
      _preloaded = true;
    } catch (_) {
      // silencioso — se der erro, ainda tentamos tocar depois com play()
    }
  }

  Future<void> playAddItem() async {
    if (!enabled) return;
    try {
      // Garante que toca do início mesmo em cliques rápidos
      await _player.stop();
      await _player.play(AssetSource('sounds/abrir_garrafa.mp3'));
    } catch (_) {
      // silencioso
    }
  }
}
