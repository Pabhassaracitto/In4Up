import 'package:shared_preferences/shared_preferences.dart';

/// Preferred Piper voice per language (`en-US` → `en_US-lessac-medium`).
class PiperVoicePrefs {
  PiperVoicePrefs._();
  static final PiperVoicePrefs instance = PiperVoicePrefs._();

  static const _prefix = 'piper_voice_for_lang_';
  static const _defaultKey = 'piper_voice_default';

  final Map<String, String> _mem = {};
  String? _defaultVoice;
  SharedPreferences? _prefs;

  Future<SharedPreferences> _ensure() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  static String normalizeLang(String language) {
    final raw = language.trim().replaceAll('_', '-');
    if (raw.isEmpty || raw.toLowerCase() == 'auto') return '';
    final parts = raw.split('-');
    if (parts.length >= 2) {
      return '${parts[0].toLowerCase()}-${parts[1].toUpperCase()}';
    }
    return parts.first.toLowerCase();
  }

  Future<void> setVoiceForLang(String language, String voiceName) async {
    final lang = normalizeLang(language);
    final prefs = await _ensure();
    if (lang.isEmpty) {
      _defaultVoice = voiceName;
      await prefs.setString(_defaultKey, voiceName);
      return;
    }
    _mem[lang] = voiceName;
    await prefs.setString('$_prefix$lang', voiceName);
  }

  Future<String?> voiceForLang(String language) async {
    final lang = normalizeLang(language);
    if (lang.isNotEmpty && _mem.containsKey(lang)) return _mem[lang];
    final prefs = await _ensure();
    if (lang.isNotEmpty) {
      final stored = prefs.getString('$_prefix$lang');
      if (stored != null && stored.isNotEmpty) {
        _mem[lang] = stored;
        return stored;
      }
      final short = lang.split('-').first;
      for (final key in prefs.getKeys()) {
        if (!key.startsWith(_prefix)) continue;
        final kLang = key.substring(_prefix.length);
        if (kLang.split('-').first == short) {
          return prefs.getString(key);
        }
      }
    }
    _defaultVoice ??= prefs.getString(_defaultKey);
    return _defaultVoice;
  }

  Future<Map<String, String>> all() async {
    final prefs = await _ensure();
    final out = <String, String>{};
    for (final key in prefs.getKeys()) {
      if (key.startsWith(_prefix)) {
        final v = prefs.getString(key);
        if (v != null && v.isNotEmpty) {
          out[key.substring(_prefix.length)] = v;
        }
      }
    }
    return out;
  }
}
