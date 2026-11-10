import 'package:just_audio/just_audio.dart';

/// Browser-safe wrapper for ordinary URL audio playback.
///
/// This intentionally does not promise background playback or native audio
/// processing. Those remain platform-specific features of the full app.
class WebAudioPlaybackController {
  final AudioPlayer player = AudioPlayer();

  Future<void> loadUrl(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const FormatException('Audio URL phải là http hoặc https.');
    }
    await player.setUrl(uri.toString());
  }

  Future<void> dispose() => player.dispose();
}
