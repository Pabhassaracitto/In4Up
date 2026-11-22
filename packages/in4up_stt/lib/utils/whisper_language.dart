// packages/in4up_stt/lib/utils/whisper_language.dart
//
// whisper.cpp (và plugin whisper_flutter_new phía sau nó) CHỈ hiểu
//  * danh sách mã của chính nó — `g_lang`, 100 mục cho 99 ngôn ngữ
//    (2 ký tự, cộng 'haw'/'yue' 3 ký tự), hoặc
//  * chuỗi "auto" (tự nhận diện).
// Mọi thứ khác đều fail:
//   - 'en-US' / 'hi-IN'  → whisper_lang_id() trả -1 → plugin báo
//                          "error: unknown language = en-US" (cả job hỏng);
//   - 'pi' (Pali), 'zh_TW', 'fil'… → cùng lỗi trên;
//   - '' / null           → mặc định trong whisper_full_default_params là
//                          "en" → mọi audio KHÔNG tiếng Anh bị ép ra
//                          chữ LATIN (Hindi ra "main bahut…" thay vì
//                          "मैं बहुत…").
//
// Vì vậy MỌI đường gọi Whisper phải đi qua [WhisperLanguage.code] trước.
//
// Đồng thời: script của đầu ra phải khớp ngôn ngữ đã chọn. Model tiny/base
// với âm thanh Hindi (nhất là bài hát) thường trả về chữ Latin dù đã
// truyền đúng 'hi' — đó là giới hạn model, không phải lỗi ngôn ngữ.
// [WhisperLanguage.latinizedFor] phát hiện đúng tình huống đó để UI báo
// người dùng "chọn model lớn hơn rồi tạo lại" thay vì im lặng nhận sai.

/// Result of normalizing a user/app language into a Whisper language code.
class WhisperLanguageResolution {
  /// Mã an toàn để đưa vào whisper.cpp — luôn là 1 trong 99 mã Whisper
  /// hoặc [WhisperLanguage.auto].
  final String code;

  /// Chuỗi gốc được truyền vào (đã trim) — để hiển thị/log.
  final String requested;

  /// Ngôn ngữ được yêu cầu nhưng Whisper không hỗ trợ (vd Pali 'pi',
  /// Tạng 'bo' bản cũ, 'zh_TW' gộp về 'zh'…) → đã rơi về 'auto'.
  final bool unsupported;

  /// [code] khác [requested] sau chuẩn hóa (bỏ vùng, alias, fallback).
  final bool changed;

  const WhisperLanguageResolution({
    required this.code,
    required this.requested,
    this.unsupported = false,
    this.changed = false,
  });

  bool get isAuto => code == WhisperLanguage.auto;

  @override
  String toString() =>
      'WhisperLanguageResolution(code=$code, requested=$requested'
      '${unsupported ? ', unsupported' : ''})';
}

/// Chuẩn hóa mã ngôn ngữ + kiểm tra script đầu ra cho Whisper.
class WhisperLanguage {
  WhisperLanguage._();

  /// Chuỗi Whisper dùng để tự nhận diện ngôn ngữ (auto-detect).
  static const String auto = 'auto';

  /// 99 mã Whisper hỗ trợ (khớp `g_lang` trong whisper.cpp / token ngôn ngữ
  /// của OpenAI Whisper). 'auto' được xử lý riêng, KHÔNG nằm ở đây.
  static const Set<String> supported = <String>{
    'af', 'am', 'ar', 'as', 'az', 'ba', 'be', 'bg', 'bn', 'bo',
    'br', 'bs', 'ca', 'cs', 'cy', 'da', 'de', 'el', 'en', 'es',
    'et', 'eu', 'fa', 'fi', 'fo', 'fr', 'gl', 'gu', 'ha', 'haw',
    'he', 'hi', 'hr', 'ht', 'hu', 'hy', 'id', 'is', 'it', 'ja',
    'jw', 'ka', 'kk', 'km', 'kn', 'ko', 'la', 'lb', 'ln', 'lo',
    'lt', 'lv', 'mg', 'mi', 'mk', 'ml', 'mn', 'mr', 'ms', 'mt',
    'my', 'ne', 'nl', 'nn', 'no', 'oc', 'pa', 'pl', 'ps', 'pt',
    'ro', 'ru', 'sa', 'sd', 'si', 'sk', 'sl', 'sn', 'so', 'sq',
    'sr', 'su', 'sv', 'sw', 'ta', 'te', 'tg', 'th', 'tk', 'tl',
    'tr', 'tt', 'uk', 'ur', 'uz', 'vi', 'yi', 'yo', 'zh', 'yue',
  };

  /// Alias hay gặp → mã Whisper. Gồm cả mã 3 ký tự lỗi thời + biến thể
  /// BCP-47 mà app và hệ điều hành thường trả về.
  static const Map<String, String> aliases = <String, String>{
    'iw': 'he', // Hebrew (mã cũ Java/Android)
    'ji': 'yi', // Yiddish (mã cũ)
    'in': 'id', // Indonesian (mã cũ Android)
    'mo': 'ro', // Moldovan → Romanian
    'fil': 'tl', // Filipino → Tagalog
    'zh-hant': 'zh',
    'zh-hans': 'zh',
    'zh-tw': 'zh',
    'zh-hk': 'zh',
    'zh-cn': 'zh',
    'zh-sg': 'zh',
    'yue-hant': 'yue',
    'pt-br': 'pt',
    'es-419': 'es',
    'en-gb': 'en',
    'en-us': 'en',
    'fr-ca': 'fr',
    'hi-in': 'hi',
    'vi-vn': 'vi',
    'pali': 'pi', // Whisper không có Pali → resolve() rơi về 'auto'
    'pli': 'pi',
    'pi-latn': 'pi',
    'sanskrit': 'sa',
    'san': 'sa',
    'thai': 'th',
    'hindi': 'hi',
    'vietnamese': 'vi',
    'english': 'en',
    'chinese': 'zh',
    // ISO 639-2/T — một số hệ điều hành/library trả mã 3 ký tự.
    'vie': 'vi', 'eng': 'en', 'hin': 'hi', 'ben': 'bn', 'tam': 'ta',
    'tel': 'te', 'mar': 'mr', 'guj': 'gu', 'kan': 'kn', 'mal': 'ml',
    'pan': 'pa', 'sin': 'si', 'nep': 'ne', 'urd': 'ur', 'per': 'fa',
    'fas': 'fa', 'arb': 'ar', 'ara': 'ar', 'tha': 'th', 'lao': 'lo',
    'khm': 'km', 'mya': 'my', 'bod': 'bo', 'rus': 'ru',
    'jpn': 'ja', 'kor': 'ko', 'zho': 'zh', 'cmn': 'zh',
  };

  /// Scripts that Whisper's *small* models render unreliably — a bigger
  /// model is worth the RAM for these.
  static const Set<String> _weakOnTiny = <String>{
    'devanagari', 'bengali', 'gurmukhi', 'gujarati', 'tamil', 'telugu',
    'kannada', 'malayalam', 'sinhala', 'thai', 'lao', 'khmer', 'myanmar',
    'tibetan', 'han', 'kana', 'hangul', 'arabic', 'hebrew', 'georgian',
    'armenian',
  };

  static final Map<String, RegExp> _scriptPatterns = <String, RegExp>{
    'latin': RegExp('[A-Za-z\\u00C0-\\u024F\\u1E00-\\u1EFF]'),
    'devanagari': RegExp('[\\u0900-\\u097F]'),
    'bengali': RegExp('[\\u0980-\\u09FF]'),
    'gurmukhi': RegExp('[\\u0A00-\\u0A7F]'),
    'gujarati': RegExp('[\\u0A80-\\u0AFF]'),
    'oriya': RegExp('[\\u0B00-\\u0B7F]'),
    'tamil': RegExp('[\\u0B80-\\u0BFF]'),
    'telugu': RegExp('[\\u0C00-\\u0C7F]'),
    'kannada': RegExp('[\\u0C80-\\u0CFF]'),
    'malayalam': RegExp('[\\u0D00-\\u0D7F]'),
    'sinhala': RegExp('[\\u0D80-\\u0DFF]'),
    'thai': RegExp('[\\u0E00-\\u0E7F]'),
    'lao': RegExp('[\\u0E80-\\u0EFF]'),
    'tibetan': RegExp('[\\u0F00-\\u0FFF]'),
    'myanmar': RegExp('[\\u1000-\\u109F]'),
    'georgian': RegExp('[\\u10A0-\\u10FF]'),
    'khmer': RegExp('[\\u1780-\\u17FF]'),
    'hebrew': RegExp('[\\u0590-\\u05FF]'),
    'arabic': RegExp('[\\u0600-\\u06FF\\u0750-\\u077F\\uFB50-\\uFDFF]'),
    'armenian': RegExp('[\\u0530-\\u058F]'),
    'greek': RegExp('[\\u0370-\\u03FF]'),
    'cyrillic': RegExp('[\\u0400-\\u04FF]'),
    'hangul': RegExp('[\\u1100-\\u11FF\\uAC00-\\uD7AF]'),
    'kana': RegExp('[\\u3040-\\u30FF]'),
    'han': RegExp('[\\u3400-\\u4DBF\\u4E00-\\u9FFF\\uF900-\\uFAFF]'),
  };

  /// Script mong đợi của một mã ngôn ngữ Whisper.
  ///
  /// Trả về null khi không chắc chắn ('auto', ngôn ngữ ít dùng) — khi đó
  /// KHÔNG được coi là lỗi script.
  static String? scriptFor(String? code) {
    final c = code == null ? '' : code.toLowerCase();
    if (c.isEmpty || c == auto) return null;
    switch (c) {
      case 'hi':
      case 'mr':
      case 'ne':
      case 'sa':
        return 'devanagari';
      case 'bn':
        return 'bengali';
      case 'pa':
        return 'gurmukhi';
      case 'gu':
        return 'gujarati';
      case 'or':
        return 'oriya';
      case 'ta':
        return 'tamil';
      case 'te':
        return 'telugu';
      case 'kn':
        return 'kannada';
      case 'ml':
        return 'malayalam';
      case 'si':
        return 'sinhala';
      case 'th':
        return 'thai';
      case 'lo':
        return 'lao';
      case 'bo':
        return 'tibetan';
      case 'my':
        return 'myanmar';
      case 'km':
        return 'khmer';
      case 'ka':
        return 'georgian';
      case 'hy':
        return 'armenian';
      case 'el':
        return 'greek';
      case 'he':
      case 'yi':
        return 'hebrew';
      case 'ar':
      case 'fa':
      case 'ur':
      case 'ps':
      case 'sd':
        return 'arabic';
      case 'ru':
      case 'uk':
      case 'be':
      case 'bg':
      case 'sr':
      case 'mk':
      case 'kk':
      case 'mn':
      case 'tg':
      case 'ba':
        return 'cyrillic';
      case 'ko':
        return 'hangul';
      case 'ja':
        return 'kana';
      case 'zh':
      case 'yue':
        return 'han';
      default:
        // Phần còn lại của danh sách Whisper đều dùng bảng chữ Latin
        // (vi, id, ms, jw, su, sw, ha, yo, ...). 'auto' và mã lạ → null.
        return supported.contains(c) ? 'latin' : null;
    }
  }

  /// Chuẩn hóa [language] (BCP-47 tùy ý: 'hi', 'hi-IN', 'zh_TW', 'Pali',
  /// '') thành mã an toàn cho whisper.cpp.
  ///
  /// Không bao giờ ném exception: mã lạ → 'auto' (tự nhận diện) +
  /// [WhisperLanguageResolution.unsupported] = true.
  static WhisperLanguageResolution resolve(String? language) {
    final raw = (language ?? '').trim();
    if (raw.isEmpty) {
      return const WhisperLanguageResolution(
        code: auto,
        requested: '',
        changed: true,
      );
    }
    final lower = raw.toLowerCase().replaceAll('_', '-');
    if (lower == auto || lower == 'system' || lower == 'detect') {
      return WhisperLanguageResolution(code: auto, requested: raw);
    }

    // 'en-US', 'zh-Hant-TW', 'pa_Guru…' → lấy phần ngôn ngữ + alias đầy đủ.
    final full = lower.split(RegExp(r'[-_]')).take(3).join('-');
    final base = lower.split(RegExp(r'[-_]')).first;

    String? hit;
    if (aliases.containsKey(full)) {
      hit = aliases[full];
    } else if (aliases.containsKey(base)) {
      hit = aliases[base];
    } else if (supported.contains(base)) {
      hit = base;
    } else if (supported.contains(full)) {
      hit = full;
    }

    if (hit == null) {
      return WhisperLanguageResolution(
        code: auto,
        requested: raw,
        unsupported: true,
        changed: true,
      );
    }
    if (!supported.contains(hit)) {
      // Alias trỏ tới ngôn ngữ Whisper không có (Pali 'pi', …) → auto.
      return WhisperLanguageResolution(
        code: auto,
        requested: raw,
        unsupported: true,
        changed: true,
      );
    }
    return WhisperLanguageResolution(
      code: hit,
      requested: raw,
      changed: hit != raw.toLowerCase(),
    );
  }

  /// Chỉ cần mã — dùng tại mọi biên gọi Whisper.
  static String code(String? language) => resolve(language).code;

  /// Có nên ưu tiên model ≥ base cho ngôn ngữ này không (script ngoài Latin
  /// mà tiny/base hay "Latin-hóa").
  static bool prefersStrongModel(String? language) {
    final script = scriptFor(code(language));
    return script != null && _weakOnTiny.contains(script);
  }

  /// Đầu ra có vẻ bị Latin-hóa so với ngôn ngữ đã chọn?
  ///
  /// Chỉ trả về true khi ngôn ngữ yêu cầu một script ngoài Latin và văn bản
  /// hầu như chỉ chứa chữ Latin. 'auto' / ngôn ngữ không rõ script → false
  /// (không đoán, theo đúng tinh thần Rule #5).
  static bool latinizedFor({String? language, required String text}) {
    final script = scriptFor(code(language));
    return script != null && script != 'latin' && _isScriptMissing(script, text);
  }

  static bool _isScriptMissing(String script, String text) {
    if (text.trim().isEmpty) return false;
    final expected = _scriptPatterns[script];
    final latin = _scriptPatterns['latin'];
    if (expected == null || latin == null) return false;

    final expectedCount = expected.allMatches(text).length;
    if (expectedCount > 0) return false;

    final latinCount = latin.allMatches(text).length;
    if (latinCount < 8) return false; // quá ngắn → chưa đủ bằng chứng

    // Không có ANY ký tự script nào khác ngoài Latin → 100% Latin.
    final otherScripts = <String>[
      'devanagari', 'bengali', 'gurmukhi', 'gujarati', 'tamil', 'telugu',
      'kannada', 'malayalam', 'sinhala', 'thai', 'lao', 'tibetan', 'myanmar',
      'khmer', 'hebrew', 'arabic', 'armenian', 'greek', 'cyrillic', 'hangul',
      'kana', 'han', 'georgian',
    ];
    for (final other in otherScripts) {
      if (other == script) continue;
      final pattern = _scriptPatterns[other];
      if (pattern != null && pattern.hasMatch(text)) return false;
    }
    return true;
  }

  /// PSRC-266 — mã Whisper của các ngôn ngữ được CHÀO SẴN ở đầu bộ chọn
  /// (phần còn lại nằm trong nhóm "Xem thêm" cuộn được). Đặt 'auto' đầu
  /// tiên; các ngôn ngữ phổ biến của app theo sau.
  static const List<String> featuredOptionCodes = <String>[
    auto, 'vi', 'en', 'zh', 'ja', 'ko', 'th', 'hi', 'pi',
  ];

  /// Một entry "Tự động (Whisper tự nhận diện)" luôn nằm đầu danh sách.
  static const WhisperLanguageOption autoOption = WhisperLanguageOption(
    code: auto,
    labelEn: 'Auto (detect)',
    labelVi: 'Tự động (tự nhận diện)',
  );

  /// PSRC-266 — DANH SÁCH ĐẦY ĐỦ các ngôn ngữ Whisper transcribe được,
  /// được phát sinh TỪ CHÍNH [supported] (khớp `g_lang` của whisper.cpp),
  /// KHÔNG phải một danh sách cứng chung chung. 'auto' không nằm ở đây —
  /// thêm bằng [allOptions].
  ///
  /// Nhãn bằng TÊN TỰ GỌI (endonym) để người dùng đọc ngôn ngữ đó nhận ra
  /// ngay; đó là lựa chọn trung lập, không phụ thuộc ngôn ngữ UI của app.
  static List<WhisperLanguageOption> languageOptions() {
    final codes = supported.toList()..sort();
    return [for (final c in codes) WhisperLanguageOption.forCode(c)];
  }

  /// [autoOption] + toàn bộ [languageOptions] — một danh sách duy nhất cho
  /// bộ chọn ngôn ngữ của "Tạo lời".
  static List<WhisperLanguageOption> allOptions() =>
      <WhisperLanguageOption>[autoOption, ...languageOptions()];

  /// Danh sách ngắn hiển thị ban đầu: [featuredOptionCodes] có mặt trong
  /// [supported] (hoặc 'auto'), theo đúng thứ tự ưu tiên. Pali ('pi') KHÔNG
  /// nằm trong [supported] nhưng được đưa vào có nhãn rõ "không có model
  /// riêng" để không còn trông như một lựa chọn transcribe trực tiếp.
  static List<WhisperLanguageOption> featuredOptions() {
    final out = <WhisperLanguageOption>[];
    for (final code in featuredOptionCodes) {
      if (code == auto) {
        out.add(autoOption);
      } else if (code == 'pi') {
        out.add(WhisperLanguageOption.pali);
      } else if (supported.contains(code)) {
        out.add(WhisperLanguageOption.forCode(code));
      }
    }
    return out;
  }

  /// Nhóm "Xem thêm ngôn ngữ" = toàn bộ ngôn ngữ hỗ trợ TRỪ các mã đã nằm
  /// trong [featuredOptions] (không trùng, không sót). 'auto' không lặp lại.
  static List<WhisperLanguageOption> moreOptions() {
    final featuredCodes = <String>{for (final o in featuredOptions()) o.code};
    return [for (final o in languageOptions()) if (!featuredCodes.contains(o.code)) o];
  }
}

/// Một lựa chọn ngôn ngữ trong bộ chọn "Tạo lời" (PSRC-266).
///
/// Gắn CHẶT nhãn hiển thị với mã whisper.cpp, để nhãn nào hiện ra thì đúng
/// mã đó được đưa vào engine — không còn tình trạng chip "Pali" nhưng lại
/// lén gửi mã khác, hay một mã không tồn tại làm hỏng cả job.
class WhisperLanguageOption {
  /// Mã đưa thẳng vào whisper.cpp — luôn là một trong [WhisperLanguage.supported]
  /// hoặc [WhisperLanguage.auto], hoặc một mã "ngoài model" có [resolvesToAuto]
  /// (chỉ dùng để hiển thị thành thật, ví dụ Pali).
  final String code;

  /// Nhãn tiếng Anh (dùng khi UI không phải tiếng Việt).
  final String labelEn;

  /// Nhãn tiếng Việt (mặc định hiển thị).
  final String labelVi;

  /// Tên tự gọi (endonym) — giúp người đọc ngôn ngữ đó nhận ra ngay.
  final String endonym;

  /// Ngôn ngữ này KHÔNG có model whisper.cpp riêng → engine sẽ rơi về 'auto'.
  /// UI phải ghi rõ để người dùng không tưởng có model chuyên biệt.
  final bool resolvesToAuto;

  const WhisperLanguageOption({
    required this.code,
    required this.labelEn,
    required this.labelVi,
    this.endonym = '',
    this.resolvesToAuto = false,
  });

  /// Pali — Tipiṭaka. whisper.cpp KHÔNG có mã 'pi'; chọn mục này sẽ chạy
  /// chế độ tự nhận diện ('auto') thay vì lỗi "unknown language = pi".
  static const WhisperLanguageOption pali = WhisperLanguageOption(
    code: 'pi',
    labelEn: 'Pali',
    labelVi: 'Pali',
    endonym: 'Pāḷi',
    resolvesToAuto: true,
  );

  /// Nhãn chính theo locale UI: tiếng Việt ưu tiên [labelVi], ngôn ngữ khác
  /// dùng [labelEn]; kèm endonym khi khác nhãn chính để dễ nhận diện.
  String displayLabel({required bool vietnamese}) {
    final base = vietnamese ? labelVi : labelEn;
    if (endonym.isEmpty || endonym == labelEn) return base;
    return '$base · $endonym';
  }

  /// Mã THẬT sẽ gửi xuống engine. Với [resolvesToAuto] đây là 'auto'
  /// (an toàn), KHÔNG phải [code] gốc — nhờ đó "Pali" không còn ném lỗi.
  String get engineCode =>
      resolvesToAuto ? WhisperLanguage.auto : WhisperLanguage.code(code);

  /// Một [WhisperLanguageOption] cho [code] — phải nằm trong
  /// [WhisperLanguage.supported]. Nhãn lấy từ bảng bên dưới; mã không có
  /// trong bảng rơi về dạng `code (code)`.
  factory WhisperLanguageOption.forCode(String code) {
    final meta = _labels[code];
    if (meta == null) {
      return WhisperLanguageOption(
        code: code,
        labelEn: code,
        labelVi: code,
      );
    }
    return WhisperLanguageOption(
      code: code,
      labelEn: meta.$1,
      labelVi: meta.$2,
      endonym: meta.$3,
    );
  }

  /// Bảng nhãn cho từng mã Whisper: (English, tiếng Việt, endonym).
  /// Nguồn: tên ngôn ngữ ISO 639 + tên tự gọi phổ biến. Chỉ cần phủ các mã
  /// trong [WhisperLanguage.supported]; mã nào thiếu sẽ tự rơi về `code`.
  static const Map<String, (String, String, String)> _labels = {
    'af': ('Afrikaans', 'Tiếng Afrikaans', 'Afrikaans'),
    'am': ('Amharic', 'Tiếng Amharic', 'አማርኛ'),
    'ar': ('Arabic', 'Tiếng Ả Rập', 'العربية'),
    'as': ('Assamese', 'Tiếng Assam', 'অসমীয়া'),
    'az': ('Azerbaijani', 'Tiếng Azerbaijan', 'Azərbaycanca'),
    'ba': ('Bashkir', 'Tiếng Bashkir', 'Башҡорт'),
    'be': ('Belarusian', 'Tiếng Belarus', 'Беларуская'),
    'bg': ('Bulgarian', 'Tiếng Bulgaria', 'Български'),
    'bn': ('Bengali', 'Tiếng Bengal', 'বাংলা'),
    'bo': ('Tibetan', 'Tiếng Tây Tạng', 'བོད་ཡིག'),
    'br': ('Breton', 'Tiếng Breton', 'Brezhoneg'),
    'bs': ('Bosnian', 'Tiếng Bosnia', 'Bosanski'),
    'ca': ('Catalan', 'Tiếng Catalan', 'Català'),
    'cs': ('Czech', 'Tiếng Séc', 'Čeština'),
    'cy': ('Welsh', 'Tiếng Wales', 'Cymraeg'),
    'da': ('Danish', 'Tiếng Đan Mạch', 'Dansk'),
    'de': ('German', 'Tiếng Đức', 'Deutsch'),
    'el': ('Greek', 'Tiếng Hy Lạp', 'Ελληνικά'),
    'en': ('English', 'Tiếng Anh', 'English'),
    'es': ('Spanish', 'Tiếng Tây Ban Nha', 'Español'),
    'et': ('Estonian', 'Tiếng Estonia', 'Eesti'),
    'eu': ('Basque', 'Tiếng Basque', 'Euskara'),
    'fa': ('Persian', 'Tiếng Ba Tư', 'فارسی'),
    'fi': ('Finnish', 'Tiếng Phần Lan', 'Suomi'),
    'fo': ('Faroese', 'Tiếng Faroe', 'Føroyskt'),
    'fr': ('French', 'Tiếng Pháp', 'Français'),
    'gl': ('Galician', 'Tiếng Galicia', 'Galego'),
    'gu': ('Gujarati', 'Tiếng Gujarat', 'ગુજરાતી'),
    'ha': ('Hausa', 'Tiếng Hausa', 'Hausa'),
    'haw': ('Hawaiian', 'Tiếng Hawaii', 'ʻŌlelo Hawaiʻi'),
    'he': ('Hebrew', 'Tiếng Do Thái', 'עברית'),
    'hi': ('Hindi', 'Tiếng Hindi', 'हिन्दी'),
    'hr': ('Croatian', 'Tiếng Croatia', 'Hrvatski'),
    'ht': ('Haitian Creole', 'Tiếng Haiti (Creole)', 'Kreyòl ayisyen'),
    'hu': ('Hungarian', 'Tiếng Hungary', 'Magyar'),
    'hy': ('Armenian', 'Tiếng Armenia', 'Հայերեն'),
    'id': ('Indonesian', 'Tiếng Indonesia', 'Bahasa Indonesia'),
    'is': ('Icelandic', 'Tiếng Iceland', 'Íslenska'),
    'it': ('Italian', 'Tiếng Ý', 'Italiano'),
    'ja': ('Japanese', 'Tiếng Nhật', '日本語'),
    'jw': ('Javanese', 'Tiếng Java', 'Basa Jawa'),
    'ka': ('Georgian', 'Tiếng Gruzia', 'ქართული'),
    'kk': ('Kazakh', 'Tiếng Kazakh', 'Қазақша'),
    'km': ('Khmer', 'Tiếng Khmer', 'ខ្មែរ'),
    'kn': ('Kannada', 'Tiếng Kannada', 'ಕನ್ನಡ'),
    'ko': ('Korean', 'Tiếng Hàn', '한국어'),
    'la': ('Latin', 'Tiếng Latin', 'Latina'),
    'lb': ('Luxembourgish', 'Tiếng Luxembourg', 'Lëtzebuergesch'),
    'ln': ('Lingala', 'Tiếng Lingala', 'Lingála'),
    'lo': ('Lao', 'Tiếng Lào', 'ລາວ'),
    'lt': ('Lithuanian', 'Tiếng Litva', 'Lietuvių'),
    'lv': ('Latvian', 'Tiếng Latvia', 'Latviešu'),
    'mg': ('Malagasy', 'Tiếng Malagasy', 'Malagasy'),
    'mi': ('Maori', 'Tiếng Maori', 'Māori'),
    'mk': ('Macedonian', 'Tiếng Macedonia', 'Македонски'),
    'ml': ('Malayalam', 'Tiếng Malayalam', 'മലയാളം'),
    'mn': ('Mongolian', 'Tiếng Mông Cổ', 'Монгол'),
    'mr': ('Marathi', 'Tiếng Marathi', 'मराठी'),
    'ms': ('Malay', 'Tiếng Mã Lai', 'Bahasa Melayu'),
    'mt': ('Maltese', 'Tiếng Malta', 'Malti'),
    'my': ('Burmese', 'Tiếng Miến Điện', 'မြန်မာ'),
    'ne': ('Nepali', 'Tiếng Nepal', 'नेपाली'),
    'nl': ('Dutch', 'Tiếng Hà Lan', 'Nederlands'),
    'nn': ('Norwegian Nynorsk', 'Tiếng Na Uy (Nynorsk)', 'Nynorsk'),
    'no': ('Norwegian', 'Tiếng Na Uy', 'Norsk'),
    'oc': ('Occitan', 'Tiếng Occitan', 'Occitan'),
    'pa': ('Punjabi', 'Tiếng Punjab', 'ਪੰਜਾਬੀ'),
    'pl': ('Polish', 'Tiếng Ba Lan', 'Polski'),
    'ps': ('Pashto', 'Tiếng Pashto', 'پښتو'),
    'pt': ('Portuguese', 'Tiếng Bồ Đào Nha', 'Português'),
    'ro': ('Romanian', 'Tiếng Romania', 'Română'),
    'ru': ('Russian', 'Tiếng Nga', 'Русский'),
    'sa': ('Sanskrit', 'Tiếng Phạn', 'संस्कृतम्'),
    'sd': ('Sindhi', 'Tiếng Sindhi', 'سنڌي'),
    'si': ('Sinhala', 'Tiếng Sinhala', 'සිංහල'),
    'sk': ('Slovak', 'Tiếng Slovakia', 'Slovenčina'),
    'sl': ('Slovenian', 'Tiếng Slovenia', 'Slovenščina'),
    'sn': ('Shona', 'Tiếng Shona', 'ChiShona'),
    'so': ('Somali', 'Tiếng Somali', 'Soomaali'),
    'sq': ('Albanian', 'Tiếng Albania', 'Shqip'),
    'sr': ('Serbian', 'Tiếng Serbia', 'Српски'),
    'su': ('Sundanese', 'Tiếng Sunda', 'Basa Sunda'),
    'sv': ('Swedish', 'Tiếng Thụy Điển', 'Svenska'),
    'sw': ('Swahili', 'Tiếng Swahili', 'Kiswahili'),
    'ta': ('Tamil', 'Tiếng Tamil', 'தமிழ்'),
    'te': ('Telugu', 'Tiếng Telugu', 'తెలుగు'),
    'tg': ('Tajik', 'Tiếng Tajik', 'Тоҷикӣ'),
    'th': ('Thai', 'Tiếng Thái', 'ไทย'),
    'tk': ('Turkmen', 'Tiếng Turkmen', 'Türkmen'),
    'tl': ('Tagalog', 'Tiếng Tagalog', 'Tagalog'),
    'tr': ('Turkish', 'Tiếng Thổ Nhĩ Kỳ', 'Türkçe'),
    'tt': ('Tatar', 'Tiếng Tatar', 'Татар'),
    'uk': ('Ukrainian', 'Tiếng Ukraina', 'Українська'),
    'ur': ('Urdu', 'Tiếng Urdu', 'اردو'),
    'uz': ('Uzbek', 'Tiếng Uzbek', 'Oʻzbek'),
    'vi': ('Vietnamese', 'Tiếng Việt', 'Tiếng Việt'),
    'yi': ('Yiddish', 'Tiếng Yiddish', 'ייִדיש'),
    'yo': ('Yoruba', 'Tiếng Yoruba', 'Yorùbá'),
    'zh': ('Chinese', 'Tiếng Trung', '中文'),
    'yue': ('Cantonese', 'Tiếng Quảng Đông', '粵語'),
  };
}
