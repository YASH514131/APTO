import 'package:audioplayers/audioplayers.dart';

class AptoAudioService {
  static final AudioPlayer _player = AudioPlayer()
    ..audioCache = AudioCache(prefix: 'lib/assets/audio/');

  static Future<void> playInitialize() async {
    await _play('initalize.m4a');
  }

  static Future<void> playFinalize() async {
    await _play('finalize.m4a');
  }

  static Future<void> playNotification() async {
    await _play('notification.m4a');
  }

  static Future<void> _play(String assetPath) async {
    try {
      await _player.stop();
      await _player.play(AssetSource(assetPath));
    } catch (_) {
      // Audio is supplemental and must not interrupt wallet or payment flow.
    }
  }
}
