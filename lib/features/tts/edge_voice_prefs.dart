import 'package:shared_preferences/shared_preferences.dart';

/// Preferred Microsoft Edge (Neural) voice per language
/// (`vi-VN` → `vi-VN-NamMinhNeural`).
///
/// TTS-EDGE-VOICE-001 — bộ chọn giọng RIÊNG cho engine Edge. Trước đây app
/// chỉ có picker cho Piper, còn Edge luôn dùng giọng mặc định theo ngôn ngữ
/// (vi-VN → HoaiMy, nữ) vì không có chỗ chọn. File này theo đúng mẫu
/// [PiperVoicePrefs]: singleton + SharedPreferences, khoá theo ngôn ngữ, KHÔNG
/// đụng `_selectedVoiceId` chung của TtsService (tránh nuốt nhầm id Piper/
/// Zalo/FPT — EdgeTtsEngine.resolveVoice vẫn là chốt an toàn cuối).
class EdgeVoicePrefs {
  EdgeVoicePrefs._();
  static final EdgeVoicePrefs instance = EdgeVoicePrefs._();

  static const _prefix = 'edge_voice_for_lang_';
  static const _defaultKey = 'edge_voice_default';

  final Map<String, String> _mem = {};
  String? _defaultVoice;
  SharedPreferences? _prefs;

  Future<SharedPreferences> _ensure() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  /// Chuẩn hoá ngôn ngữ thành khoá nhất quán (`vi-VN` / `en-US` / `vi`).
  /// Giữ y hệt [PiperVoicePrefs.normalizeLang] để 2 picker đồng bộ.
  static String normalizeLang(String language) {
    final raw = language.trim().replaceAll('_', '-');
    if (raw.isEmpty || raw.toLowerCase() == 'auto') return '';
    final parts = raw.split('-');
    if (parts.length >= 2) {
      return '${parts[0].toLowerCase()}-${parts[1].toUpperCase()}';
    }
    return parts.first.toLowerCase();
  }

  Future<void> setVoiceForLang(String language, String voiceId) async {
    final lang = normalizeLang(language);
    final prefs = await _ensure();
    if (lang.isEmpty || lang == 'other') {
      _defaultVoice = voiceId;
      await prefs.setString(_defaultKey, voiceId);
      return;
    }
    _mem[lang] = voiceId;
    await prefs.setString('$_prefix$lang', voiceId);

    // Lưu thêm short code (ví dụ `vi` song song với `vi-VN`).
    final short = lang.split('-').first;
    if (short != lang) {
      _mem[short] = voiceId;
      await prefs.setString('$_prefix$short', voiceId);
    }
  }

  /// Giọng Edge đã chọn cho [language]; null = chưa chọn (engine dùng giọng
  /// mặc định theo ngôn ngữ).
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
