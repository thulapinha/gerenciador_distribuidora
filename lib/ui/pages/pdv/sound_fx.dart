// lib/ui/pages/pdv/sound_fx.dart
import 'package:audioplayers/audioplayers.dart';

/// Singleton simples para tocar efeitos sonoros do PDV.
/// Usa um arquivo de asset: assets/sounds/abrir_garrafa.mp3
class SoundFx {
  SoundFx._internal();
  static final SoundFx instance = SoundFx._internal();

  final AudioPlayer _player = AudioPlayer();

  /// Pré-carrega (silencioso se falhar)
  Future<void> preload() async {
    try {
      // Não precisa manter a fonte fixada; apenas garante cache inicial.
      await _player.setSource(AssetSource('sounds/abrir_garrafa.mp3'));
    } catch (_) {
      // ignora
    }
  }

  /// Toca o som de "item adicionado".
  Future<void> playAddItem() async {
    try {
      // Reinicia o som rapidamente mesmo se estiver tocando
      await _player.stop();
      await _player.play(AssetSource('sounds/abrir_garrafa.mp3'));
    } catch (_) {
      // ignora
    }
  }
}
