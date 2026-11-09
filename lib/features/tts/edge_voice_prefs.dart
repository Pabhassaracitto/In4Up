import 'package:shared_preferences/shared_preferences.dart';

/// Preferred Microsoft Edge (Neural) voice per language
/// (`vi-VN` → `vi-VN-NamMinhNeural`, `en-GB` → `en-GB-RyanNeural`…).
///
/// TTS-EDGE-VOICE-001 — bộ chọn giọng RIÊNG cho engine Edge.
/// TTS-EDGE-VOICE-003 — cho phép GHIM một giọng Edge dùng cho MỌI ngôn ngữ
/// chưa chọn giọng riêng; giọng riêng theo ngôn ngữ luôn thắng giọng ghim.
/// PSRC-18 — hỗ trợ chuyển đổi mượt giữa các phương ngữ cùng ngôn ngữ gốc
/// (ví dụ `en-US` ↔ `en-GB`) khi `LanguageDetector`/`PlaybackEngine` luôn
/// chuẩn hoá tiếng Anh về `en-US`, đồng thời giữ độc lập `zh-CN` và `zh-TW`.
class EdgeVoicePrefs {
  EdgeVoicePrefs._();
  static final EdgeVoicePrefs instance = EdgeVoicePrefs._();

  static const _prefix = 'edge_voice_for_lang_';

  /// Giọng GHIM (dùng cho mọi ngôn ngữ chưa chọn giọng riêng). Khoá giữ tên
  /// cũ `edge_voice_default` để bản cũ đọc được cùng một chỗ.
  static const _pinnedVoiceKey = 'edge_voice_default';

  /// Công tắc ghim — mặc định TẮT (khoá vắng mặt = tắt).
  static const _pinAllKey = 'edge_voice_pin_all';

  final Map<String, String> _mem = {};
  String? _pinnedVoice;
  bool? _pinAll;
  SharedPreferences? _prefs;

  Future<SharedPreferences> _ensure() async {
    final prefs = await SharedPreferences.getInstance();
    if (!identical(prefs, _prefs)) {
      _prefs = prefs;
      _mem.clear();
      _pinnedVoice = null;
      _pinAll = null;
    }
    return prefs;
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

  /// Bậc thang chọn giọng Edge cho một ngôn ngữ — THUẦN LOGIC, test được:
  ///
  ///  1. giọng RIÊNG của ngôn ngữ đó (người dùng đã chọn) — luôn thắng;
  ///  2. giọng GHIM, nhưng chỉ khi công tắc ghim đang bật;
  ///  3. `null` → engine tự dùng giọng mặc định của ngôn ngữ.
  static String? resolveVoiceForLanguage({
    required String? perLanguageVoice,
    required String? pinnedVoice,
    required bool pinAll,
  }) {
    final own = perLanguageVoice?.trim() ?? '';
    if (own.isNotEmpty) return own;
    if (!pinAll) return null;
    final pinned = pinnedVoice?.trim() ?? '';
    return pinned.isEmpty ? null : pinned;
  }

  Future<void> setVoiceForLang(String language, String voiceId) async {
    final lang = normalizeLang(language);
    final trimmed = voiceId.trim();
    final prefs = await _ensure();
    if (lang.isEmpty || lang == 'other') {
      await setPinnedVoice(trimmed);
      await setPinAllLanguages(true);
      return;
    }

    final short = lang.split('-').first;

    // Với các ngôn ngữ cùng chữ viết mà bộ nhận diện luôn trả về 1 mã chuẩn
    // duy nhất (vd tiếng Anh luôn ra `en-US`, không phân biệt Mỹ/Anh), khi
    // người dùng chủ động đổi sang phương ngữ khác (`en-GB` ↔ `en-US`), dọn
    // khoá vùng cũ cùng họ để lựa chọn mới có hiệu lực ngay lập tức.
    // Ngoại lệ: `zh` có `zh-CN` (giản thể) và `zh-TW` (phồn thể) được nhận
    // diện độc lập theo mặt chữ Hán nên giữ riêng cả hai.
    if (short != lang && short != 'zh') {
      final staleRegionalKeys = <String>[
        for (final key in prefs.getKeys())
          if (key.startsWith(_prefix)) key.substring(_prefix.length),
      ].where((kLang) =>
          kLang != lang && kLang != short && kLang.split('-').first == short);

      for (final stale in staleRegionalKeys) {
        _mem.remove(stale);
        await prefs.remove('$_prefix$stale');
      }
      _mem.removeWhere(
        (kLang, _) =>
            kLang != lang && kLang != short && kLang.split('-').first == short,
      );
    }

    _mem[lang] = trimmed;
    await prefs.setString('$_prefix$lang', trimmed);

    // Lưu thêm short code (`vi` song song `vi-VN`, `en` trỏ tới phương ngữ
    // tiếng Anh vừa chọn). Với `zh`, chỉ ghi short code nếu chưa có để không
    // làm `zh-TW` ghi đè fallback của `zh-CN` khi cả hai cùng được cấu hình.
    if (short != lang) {
      if (short != 'zh' || !prefs.containsKey('$_prefix$short')) {
        _mem[short] = trimmed;
        await prefs.setString('$_prefix$short', trimmed);
      }
    }
  }

  /// Giọng Edge sẽ dùng cho [language]; `null` = chưa chọn (engine dùng giọng
  /// mặc định theo ngôn ngữ).
  Future<String?> voiceForLang(String language) async {
    final lang = normalizeLang(language);
    final prefs = await _ensure();
    final own = lang.isEmpty || lang == 'other'
        ? null
        : _storedVoiceForLang(prefs, lang);
    return resolveVoiceForLanguage(
      perLanguageVoice: own,
      pinnedVoice: await pinnedVoice,
      pinAll: await pinAllLanguages,
    );
  }

  /// Giọng đã lưu cho đúng [lang] (không tính giọng ghim):
  /// khớp chính xác (`vi-VN` / `zh-TW`) → mã ngắn (`en`) → phương ngữ cùng họ.
  String? _storedVoiceForLang(SharedPreferences prefs, String lang) {
    final cached = _mem[lang];
    if (cached != null && cached.isNotEmpty) return cached;

    final direct = prefs.getString('$_prefix$lang');
    if (direct != null && direct.isNotEmpty) {
      _mem[lang] = direct;
      return direct;
    }

    final short = lang.split('-').first;
    final cachedShort = _mem[short];
    if (cachedShort != null && cachedShort.isNotEmpty) return cachedShort;

    final directShort = prefs.getString('$_prefix$short');
    if (directShort != null && directShort.isNotEmpty) {
      _mem[short] = directShort;
      return directShort;
    }

    final siblingKeys = prefs
        .getKeys()
        .where((key) => key.startsWith(_prefix))
        .toList()
      ..sort();
    for (final key in siblingKeys) {
      final kLang = key.substring(_prefix.length);
      if (kLang.split('-').first != short) continue;
      final value = prefs.getString(key);
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  /// Giọng GHIM cho mọi ngôn ngữ chưa chọn giọng riêng (null = chưa ghim).
  Future<String?> get pinnedVoice async {
    final prefs = await _ensure();
    final cached = _pinnedVoice;
    if (cached != null) return cached.isEmpty ? null : cached;
    final stored = prefs.getString(_pinnedVoiceKey);
    _pinnedVoice = stored ?? '';
    return stored == null || stored.isEmpty ? null : stored;
  }

  Future<void> setPinnedVoice(String voiceId) async {
    final prefs = await _ensure();
    _pinnedVoice = voiceId.trim();
    await prefs.setString(_pinnedVoiceKey, _pinnedVoice!);
  }

  /// Công tắc "dùng giọng ghim cho mọi ngôn ngữ" — mặc định TẮT.
  Future<bool> get pinAllLanguages async {
    final prefs = await _ensure();
    _pinAll ??= prefs.getBool(_pinAllKey) ?? false;
    return _pinAll!;
  }

  Future<void> setPinAllLanguages(bool value, {String? voiceId}) async {
    final prefs = await _ensure();
    if (voiceId != null && voiceId.trim().isNotEmpty) {
      await setPinnedVoice(voiceId);
    }
    _pinAll = value;
    await prefs.setBool(_pinAllKey, value);
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
