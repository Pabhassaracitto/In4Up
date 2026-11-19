import 'package:shared_preferences/shared_preferences.dart';

/// Stable storage names. A missing reader key means live inheritance, not a
/// snapshot of the common settings when the screen was first opened.
enum TtsReader { read, tipitaka, web, pdf }

class ReaderVoicePreference {
  const ReaderVoicePreference(this.engine, {this.voice, this.locale});
  final String engine;
  final String? voice;
  final String? locale;

  String? voiceFor(String engineId, String language) {
    if (engine != engineId || locale == null) return null;
    String norm(String s) => s.replaceAll('_', '-').toLowerCase();
    final own = norm(locale!);
    final want = norm(language);
    if (own == want) return voice;
    final family = own.split('-').first;
    return family != 'zh' && family == want.split('-').first ? voice : null;
  }

  static String _key(TtsReader reader) => 'tts_reader_voice_v1_${reader.name}';

  static ReaderVoicePreference? load(
      SharedPreferences prefs, TtsReader reader) {
    final data = prefs.get(_key(reader));
    if (data is! List || data.isEmpty || data.first is! String) return null;
    if (data.length == 1) return ReaderVoicePreference(data.first as String);
    if (data.length != 3 || data[1] is! String || data[2] is! String)
      return null;
    return ReaderVoicePreference(data.first as String,
        voice: data[1] as String, locale: data[2] as String);
  }

  static Future<bool> save(
      SharedPreferences prefs, TtsReader reader, ReaderVoicePreference? value) {
    if (value == null) return prefs.remove(_key(reader));
    return prefs.setStringList(_key(reader), [
      value.engine,
      if (value.voice != null && value.locale != null) ...[
        value.voice!,
        value.locale!
      ],
    ]);
  }
}
