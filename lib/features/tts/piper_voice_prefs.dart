import 'package:in4up_stt/tts/sherpa_piper_tts_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferred Piper voice per language (`en-US` → `en_US-lessac-medium`).
///
/// PSRC-230 — tab Đọc phát song ngữ bằng Sherpa/Piper nhưng câu TIẾNG ANH vẫn
/// đọc bằng giọng TIẾNG VIỆT. Nguyên nhân nằm ở đây: bản cũ trả `_defaultVoice`
/// (giọng người dùng lưu lần cuối, thường là giọng Việt) cho MỌI ngôn ngữ chưa
/// có mục riêng. Nay giọng mặc định chỉ được dùng khi NGÔN NGỮ CỦA CHÍNH NÓ
/// khớp ngôn ngữ cần đọc; không khớp ⇒ `null` để `PiperTtsEngine` từ chối và
/// `TtsService` chuyển sang engine kế tiếp (thà im lặng rồi fallback còn hơn
/// đọc tiếng Anh bằng giọng Việt).
///
/// PSRC-18 (đồng bộ với `EdgeVoicePrefs`) — chuyển mượt giữa các phương ngữ
/// cùng ngôn ngữ gốc (`en-US` ↔ `en-GB`) và dọn khoá vùng cũ khi người dùng
/// đổi phương ngữ; `zh-CN` và `zh-TW` là hai MẶT CHỮ khác nhau nên giữ riêng.
class PiperVoicePrefs {
  PiperVoicePrefs._();
  static final PiperVoicePrefs instance = PiperVoicePrefs._();

  static const _prefix = 'piper_voice_for_lang_';
  static const _defaultKey = 'piper_voice_default';

  final Map<String, String> _mem = {};
  String? _defaultVoice;
  SharedPreferences? _prefs;

  Future<SharedPreferences> _ensure() async {
    final prefs = await SharedPreferences.getInstance();
    // Test/hot-restart có thể thay kho dữ liệu: nhận diện instance MỚI rồi
    // xoá cache bộ nhớ, nếu không ta đọc mãi giá trị của kho cũ.
    if (!identical(prefs, _prefs)) {
      _prefs = prefs;
      _mem.clear();
      _defaultVoice = null;
    }
    return prefs;
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

  /// Ngôn ngữ của một tên giọng Piper (`en_US-lessac-medium` → `en-US`).
  /// Dùng CHUNG parser với sherpa core để tên giọng chỉ có một cách hiểu.
  static String languageOfVoiceName(String voiceName) =>
      normalizeLang(SherpaPiperTtsCore.langFromVoiceName(voiceName));

  /// Giọng [voiceName] có đọc được [language] không.
  ///
  /// Không rõ ngôn ngữ của giọng (tên không có mã) ⇒ chấp nhận, vì không có
  /// căn cứ để phản chứng — đây vẫn là lựa chọn tốt hơn im lặng.
  static bool isVoiceCompatibleWithLanguage(
    String voiceName,
    String language, {
    String Function(String voiceName)? languageOfVoice,
  }) {
    final want = normalizeLang(language);
    if (want.isEmpty || want == 'other') return true;
    final voiceLang = (languageOfVoice ?? languageOfVoiceName)(voiceName);
    if (voiceLang.isEmpty || voiceLang == 'other') return true;
    if (voiceLang == want) return true;
    final voiceShort = voiceLang.split('-').first;
    final wantShort = want.split('-').first;
    if (voiceShort != wantShort) return false;
    // Tiếng Trung: giản thể và phồn thể là hai mặt chữ — cùng mã `zh` nhưng
    // KHÔNG dùng chéo được.
    if (wantShort == 'zh') return false;
    return true;
  }

  /// Bậc thang chọn giọng Piper cho một ngôn ngữ — THUẦN LOGIC, test được:
  ///
  ///  1. giọng RIÊNG của đúng ngôn ngữ (`en-GB`);
  ///  2. giọng của mã ngắn (`en`) hoặc phương ngữ cùng họ (`en-US`), vì
  ///     `LanguageDetector`/`PlaybackEngine` chuẩn hoá tiếng Anh về `en-US`;
  ///  3. giọng MẶC ĐỊNH — chỉ khi ngôn ngữ của chính giọng đó khớp;
  ///  4. `null` ⇒ không có giọng phù hợp (engine tự fallback).
  static String? resolveVoiceForLanguage({
    required String language,
    required Map<String, String> perLanguageVoices,
    String? defaultVoice,
    String Function(String voiceName) languageOfVoice = languageOfVoiceName,
  }) {
    final want = normalizeLang(language);
    final voices = <String, String>{};
    perLanguageVoices.forEach((key, value) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return;
      voices[normalizeLang(key)] = trimmed;
    });
    final fallback = (defaultVoice ?? '').trim();

    if (want.isEmpty || want == 'other') {
      return fallback.isEmpty ? null : fallback;
    }

    final own = voices[want];
    if (own != null) return own;

    final wantShort = want.split('-').first;
    if (wantShort != 'zh') {
      final familyKeys = voices.keys
          .where((key) => key.split('-').first == wantShort)
          .toList()
        ..sort();
      if (familyKeys.isNotEmpty) return voices[familyKeys.first];
    }

    if (fallback.isEmpty) return null;
    return isVoiceCompatibleWithLanguage(
      fallback,
      want,
      languageOfVoice: languageOfVoice,
    )
        ? fallback
        : null;
  }

  Future<void> setVoiceForLang(String language, String voiceName) async {
    final lang = normalizeLang(language);
    final trimmed = voiceName.trim();
    final prefs = await _ensure();
    if (lang.isEmpty || lang == 'other') {
      _defaultVoice = trimmed;
      await prefs.setString(_defaultKey, trimmed);
      return;
    }

    final short = lang.split('-').first;

    // PSRC-18/230: người dùng vừa đổi phương ngữ (`en-GB` ↔ `en-US`) ⇒ dọn
    // khoá vùng cũ cùng họ để lựa chọn mới có hiệu lực ngay. `zh` giữ riêng.
    if (short != lang && short != 'zh') {
      final stale = <String>[
        for (final key in prefs.getKeys())
          if (key.startsWith(_prefix)) key.substring(_prefix.length),
      ].where((keyLang) =>
          keyLang != lang &&
          keyLang != short &&
          keyLang.split('-').first == short);

      for (final keyLang in stale.toList()) {
        _mem.remove(keyLang);
        await prefs.remove('$_prefix$keyLang');
      }
      _mem.removeWhere(
        (keyLang, _) =>
            keyLang != lang &&
            keyLang != short &&
            keyLang.split('-').first == short,
      );
    }

    _mem[lang] = trimmed;
    await prefs.setString('$_prefix$lang', trimmed);

    // Lưu thêm short code (`vi` song song `vi-VN`). Với `zh`, chỉ ghi nếu
    // chưa có — để `zh-TW` không ghi đè fallback của `zh-CN`.
    if (short != lang) {
      if (short != 'zh' || !prefs.containsKey('$_prefix$short')) {
        _mem[short] = trimmed;
        await prefs.setString('$_prefix$short', trimmed);
      }
    }
  }

  /// Giọng Piper sẽ dùng cho [language]; `null` = KHÔNG có giọng phù hợp
  /// (trước PSRC-230 hàm này trả giọng mặc định của ngôn ngữ khác).
  Future<String?> voiceForLang(String language) async {
    final prefs = await _ensure();
    final stored = <String, String>{..._mem};
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_prefix)) continue;
      final keyLang = key.substring(_prefix.length);
      if (stored.containsKey(keyLang)) continue;
      final value = prefs.getString(key);
      if (value != null && value.isNotEmpty) stored[keyLang] = value;
    }
    _defaultVoice ??= prefs.getString(_defaultKey);
    return resolveVoiceForLanguage(
      language: language,
      perLanguageVoices: stored,
      defaultVoice: _defaultVoice,
    );
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
