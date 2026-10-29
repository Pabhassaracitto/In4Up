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
///
/// TTS-EDGE-VOICE-003 (nghiệm thu máy thật, audit 1.g — tài liệu LẪN Việt–Anh):
/// câu tiếng Anh trong tài liệu tiếng Việt được nhận diện là `en-US`, mà
/// người dùng mới chỉ cấu hình giọng **tiếng Việt** ⇒ rơi về giọng mặc định
/// của en-US (Aria, nữ) ⇒ lại đúng triệu chứng "chọn giọng nam mà giọng nữ
/// đọc", lần này ở dòng ngoại ngữ. Hướng đã chọn (thay vì thêm bộ chọn giọng
/// ngay trong luồng đọc): cho phép **GHIM** một giọng Edge dùng cho MỌI ngôn
/// ngữ chưa chọn giọng riêng. Mặc định TẮT ⇒ không đổi hành vi người dùng cũ;
/// giọng riêng theo ngôn ngữ luôn thắng giọng ghim.
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

  /// Bậc thang chọn giọng Edge cho một ngôn ngữ — THUẦN LOGIC, test được:
  ///
  ///  1. giọng RIÊNG của ngôn ngữ đó (người dùng đã chọn) — luôn thắng;
  ///  2. giọng GHIM, nhưng chỉ khi công tắc ghim đang bật;
  ///  3. `null` → engine tự dùng giọng mặc định của ngôn ngữ.
  ///
  /// Vì sao giọng riêng thắng giọng ghim: ghim là để lấp chỗ TRỐNG (dòng
  /// ngoại ngữ trong tài liệu lẫn Việt–Anh), không phải để nuốt lựa chọn
  /// tường minh của người dùng.
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
    final prefs = await _ensure();
    if (lang.isEmpty || lang == 'other') {
      // Nhóm "ngôn ngữ khác" = chọn giọng cho những ngôn ngữ chưa cấu hình
      // ⇒ ghi vào ô GHIM và bật công tắc ghim luôn (lựa chọn tường minh).
      await setPinnedVoice(voiceId);
      await setPinAllLanguages(true);
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

  /// Giọng đã lưu cho đúng [lang] (không tính giọng ghim): `vi-VN` → `vi`.
  String? _storedVoiceForLang(SharedPreferences prefs, String lang) {
    final cached = _mem[lang];
    if (cached != null && cached.isNotEmpty) return cached;

    final direct = prefs.getString('$_prefix$lang');
    if (direct != null && direct.isNotEmpty) {
      _mem[lang] = direct;
      return direct;
    }

    final short = lang.split('-').first;
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_prefix)) continue;
      final kLang = key.substring(_prefix.length);
      if (kLang.split('-').first != short) continue;
      final value = prefs.getString(key);
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  /// Giọng GHIM cho mọi ngôn ngữ chưa chọn giọng riêng (null = chưa ghim).
  Future<String?> get pinnedVoice async {
    final cached = _pinnedVoice;
    if (cached != null) return cached.isEmpty ? null : cached;
    final stored = (await _ensure()).getString(_pinnedVoiceKey);
    _pinnedVoice = stored ?? '';
    return stored == null || stored.isEmpty ? null : stored;
  }

  Future<void> setPinnedVoice(String voiceId) async {
    _pinnedVoice = voiceId.trim();
    await (await _ensure()).setString(_pinnedVoiceKey, _pinnedVoice!);
  }

  /// Công tắc "dùng giọng ghim cho mọi ngôn ngữ" — mặc định TẮT.
  Future<bool> get pinAllLanguages async {
    _pinAll ??= (await _ensure()).getBool(_pinAllKey) ?? false;
    return _pinAll!;
  }

  Future<void> setPinAllLanguages(bool value, {String? voiceId}) async {
    if (voiceId != null && voiceId.trim().isNotEmpty) {
      await setPinnedVoice(voiceId);
    }
    _pinAll = value;
    await (await _ensure()).setBool(_pinAllKey, value);
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
