// Curated Piper voices for in-app download.
//
// PSRC-252 — danh sách này được đối chiếu với `voices.json` của
// https://huggingface.co/rhasspy/piper-voices (nhánh `main`, khảo sát
// 2026-11-19). Mọi `id` ở đây PHẢI là một key có thật trong voices.json:
//   ├── file ONNX:  <hfOnnxRel>
//   └── file config: <hfOnnxRel>.json
// Không thêm model "nghe tên giống có" — đặc biệt với my_MM/si_LK/tạ
// (xem [PiperVoiceCatalog.unavailableLanguages]): Piper hiện KHÔNG có giọng
// bản xứ cho các ngôn ngữ đó.
//
// Trình cài ưu tiên bundle k2-fsa (onnx+tokens+espeak), rồi mới tải thẳng
// HuggingFace onnx+json (xem `SherpaModelManager.downloadPiperBundle`). Vì vậy
// các bản `medium/x_low/low` của rhasspy đều dùng được ở đây.

/// Một giọng Piper có thật trên HuggingFace.
class PiperVoiceOffer {
  final String id;
  final String languageCode;
  final String languageLabelEn;
  final String quality;
  final String speaker;
  final String hfOnnxRel;

  /// Kích thước ~MB của file ONNX (làm tròn từ `size_bytes` của voices.json).
  /// Chỉ để hiển thị — KHÔNG phải mức RAM cần để chạy model.
  final int approxSizeMB;

  const PiperVoiceOffer({
    required this.id,
    required this.languageCode,
    required this.languageLabelEn,
    required this.quality,
    required this.speaker,
    required this.hfOnnxRel,
    this.approxSizeMB = 60,
  });

  /// Có nằm trong nhóm ngôn ngữ ưu tiên hay không (UI gom nhóm, không cần
  /// cờ `featured` rời rạc như bản cũ).
  bool get isPriority =>
      PiperVoiceCatalog.priorityLanguageCodes.contains(languageCode);

  String get hfOnnxUrl =>
      'https://huggingface.co/rhasspy/piper-voices/resolve/main/$hfOnnxRel';

  String get hfJsonUrl => '$hfOnnxUrl.json';

  static const hfTreeUrl =
      'https://huggingface.co/rhasspy/piper-voices/tree/main';
}

/// Ngôn ngữ người dùng thường hỏi nhưng Piper KHÔNG có giọng bản xứ.
/// [languageCode] là mã NGÔN NGỮ — không phải tên quốc gia (Sri Lanka có
/// Sinhala, Tamil và English; Myanmar có Burmese).
class PiperUnavailableLanguage {
  final String languageCode;
  final String languageLabelEn;

  const PiperUnavailableLanguage({
    required this.languageCode,
    required this.languageLabelEn,
  });
}

class PiperVoiceCatalog {
  PiperVoiceCatalog._();

  /// Ngôn ngữ hiển thị ở chế độ gọn. Có vài giọng bản xứ cho mỗi ngôn ngữ;
  /// `zh_CN` và `zh_TW` là hai mặt chữ — chỉ liệt kê `zh_CN` vì đây là mã có
  /// model thật trong piper-voices.
  static const List<String> priorityLanguageCodes = [
    'vi_VN',
    'en_US',
    'en_GB',
    'zh_CN',
    'hi_IN',
    'ja_JP',
    'th_TH',
  ];

  /// Không có giọng nào cho các mã này trong piper-voices (2026-11). UI phải
  /// nói rõ để người dùng không tải nhầm model tiếng khác rồi tưởng là lỗi.
  static const List<PiperUnavailableLanguage> unavailableLanguages = [
    PiperUnavailableLanguage(
      languageCode: 'my_MM',
      languageLabelEn: 'Burmese (Myanmar)',
    ),
    PiperUnavailableLanguage(
      languageCode: 'si_LK',
      languageLabelEn: 'Sinhala (Sri Lanka)',
    ),
    PiperUnavailableLanguage(
      languageCode: 'ta_LK',
      languageLabelEn: 'Tamil (Sri Lanka)',
    ),
  ];

  static const List<PiperVoiceOffer> all = [
    // ── Tiếng Việt ────────────────────────────────────────────────────────
    PiperVoiceOffer(
      id: 'vi_VN-vais1000-medium',
      languageCode: 'vi_VN',
      languageLabelEn: 'Vietnamese',
      quality: 'medium',
      speaker: 'vais1000',
      hfOnnxRel: 'vi/vi_VN/vais1000/medium/vi_VN-vais1000-medium.onnx',
      approxSizeMB: 60,
    ),
    PiperVoiceOffer(
      id: 'vi_VN-25hours_single-low',
      languageCode: 'vi_VN',
      languageLabelEn: 'Vietnamese',
      quality: 'low',
      speaker: '25hours_single',
      hfOnnxRel: 'vi/vi_VN/25hours_single/low/vi_VN-25hours_single-low.onnx',
      approxSizeMB: 60,
    ),
    PiperVoiceOffer(
      id: 'vi_VN-vivos-x_low',
      languageCode: 'vi_VN',
      languageLabelEn: 'Vietnamese',
      quality: 'x_low',
      speaker: 'vivos',
      hfOnnxRel: 'vi/vi_VN/vivos/x_low/vi_VN-vivos-x_low.onnx',
      approxSizeMB: 27,
    ),
    // ── Tiếng Anh ─────────────────────────────────────────────────────────
    PiperVoiceOffer(
      id: 'en_US-lessac-medium',
      languageCode: 'en_US',
      languageLabelEn: 'English (US)',
      quality: 'medium',
      speaker: 'lessac',
      hfOnnxRel: 'en/en_US/lessac/medium/en_US-lessac-medium.onnx',
      approxSizeMB: 60,
    ),
    PiperVoiceOffer(
      id: 'en_US-libritts_r-medium',
      languageCode: 'en_US',
      languageLabelEn: 'English (US)',
      quality: 'medium',
      speaker: 'libritts_r',
      hfOnnxRel: 'en/en_US/libritts_r/medium/en_US-libritts_r-medium.onnx',
      approxSizeMB: 74,
    ),
    PiperVoiceOffer(
      id: 'en_US-amy-medium',
      languageCode: 'en_US',
      languageLabelEn: 'English (US)',
      quality: 'medium',
      speaker: 'amy',
      hfOnnxRel: 'en/en_US/amy/medium/en_US-amy-medium.onnx',
      approxSizeMB: 60,
    ),
    PiperVoiceOffer(
      id: 'en_US-ryan-medium',
      languageCode: 'en_US',
      languageLabelEn: 'English (US)',
      quality: 'medium',
      speaker: 'ryan',
      hfOnnxRel: 'en/en_US/ryan/medium/en_US-ryan-medium.onnx',
      approxSizeMB: 60,
    ),
    PiperVoiceOffer(
      id: 'en_GB-alan-medium',
      languageCode: 'en_GB',
      languageLabelEn: 'English (UK)',
      quality: 'medium',
      speaker: 'alan',
      hfOnnxRel: 'en/en_GB/alan/medium/en_GB-alan-medium.onnx',
      approxSizeMB: 60,
    ),
    PiperVoiceOffer(
      id: 'en_GB-alba-medium',
      languageCode: 'en_GB',
      languageLabelEn: 'English (UK)',
      quality: 'medium',
      speaker: 'alba',
      hfOnnxRel: 'en/en_GB/alba/medium/en_GB-alba-medium.onnx',
      approxSizeMB: 60,
    ),
    PiperVoiceOffer(
      id: 'en_GB-cori-medium',
      languageCode: 'en_GB',
      languageLabelEn: 'English (UK)',
      quality: 'medium',
      speaker: 'cori',
      hfOnnxRel: 'en/en_GB/cori/medium/en_GB-cori-medium.onnx',
      approxSizeMB: 60,
    ),
    // ── Tiếng Trung (giản thể) ────────────────────────────────────────────
    PiperVoiceOffer(
      id: 'zh_CN-huayan-medium',
      languageCode: 'zh_CN',
      languageLabelEn: 'Chinese (Mandarin, simplified)',
      quality: 'medium',
      speaker: 'huayan',
      hfOnnxRel: 'zh/zh_CN/huayan/medium/zh_CN-huayan-medium.onnx',
      approxSizeMB: 60,
    ),
    PiperVoiceOffer(
      id: 'zh_CN-chaowen-medium',
      languageCode: 'zh_CN',
      languageLabelEn: 'Chinese (Mandarin, simplified)',
      quality: 'medium',
      speaker: 'chaowen',
      hfOnnxRel: 'zh/zh_CN/chaowen/medium/zh_CN-chaowen-medium.onnx',
      approxSizeMB: 60,
    ),
    PiperVoiceOffer(
      id: 'zh_CN-xiao_ya-medium',
      languageCode: 'zh_CN',
      languageLabelEn: 'Chinese (Mandarin, simplified)',
      quality: 'medium',
      speaker: 'xiao_ya',
      hfOnnxRel: 'zh/zh_CN/xiao_ya/medium/zh_CN-xiao_ya-medium.onnx',
      approxSizeMB: 60,
    ),
    PiperVoiceOffer(
      id: 'zh_CN-huayan-x_low',
      languageCode: 'zh_CN',
      languageLabelEn: 'Chinese (Mandarin, simplified)',
      quality: 'x_low',
      speaker: 'huayan',
      hfOnnxRel: 'zh/zh_CN/huayan/x_low/zh_CN-huayan-x_low.onnx',
      approxSizeMB: 20,
    ),
    // ── Tiếng Hindi ────────────────────────────────────────────────────────
    PiperVoiceOffer(
      id: 'hi_IN-pratham-medium',
      languageCode: 'hi_IN',
      languageLabelEn: 'Hindi',
      quality: 'medium',
      speaker: 'pratham',
      hfOnnxRel: 'hi/hi_IN/pratham/medium/hi_IN-pratham-medium.onnx',
      approxSizeMB: 60,
    ),
    PiperVoiceOffer(
      id: 'hi_IN-priyamvada-medium',
      languageCode: 'hi_IN',
      languageLabelEn: 'Hindi',
      quality: 'medium',
      speaker: 'priyamvada',
      hfOnnxRel: 'hi/hi_IN/priyamvada/medium/hi_IN-priyamvada-medium.onnx',
      approxSizeMB: 60,
    ),
    PiperVoiceOffer(
      id: 'hi_IN-rohan-medium',
      languageCode: 'hi_IN',
      languageLabelEn: 'Hindi',
      quality: 'medium',
      speaker: 'rohan',
      hfOnnxRel: 'hi/hi_IN/rohan/medium/hi_IN-rohan-medium.onnx',
      approxSizeMB: 60,
    ),
    // ── Tiếng Nhật / Thái ──────────────────────────────────────────────────
    PiperVoiceOffer(
      id: 'ja_JP-hi_fi_captain-medium',
      languageCode: 'ja_JP',
      languageLabelEn: 'Japanese',
      quality: 'medium',
      speaker: 'hi_fi_captain',
      hfOnnxRel: 'ja/ja_JP/hi_fi_captain/medium/ja_JP-hi_fi_captain-medium.onnx',
      approxSizeMB: 73,
    ),
    PiperVoiceOffer(
      id: 'th_TH-tsync2-medium',
      languageCode: 'th_TH',
      languageLabelEn: 'Thai',
      quality: 'medium',
      speaker: 'tsync2',
      hfOnnxRel: 'th/th_TH/tsync2/medium/th_TH-tsync2-medium.onnx',
      approxSizeMB: 60,
    ),
    // ── Các ngôn ngữ khác (mở rộng) ───────────────────────────────────────
    PiperVoiceOffer(
      id: 'fr_FR-siwis-medium',
      languageCode: 'fr_FR',
      languageLabelEn: 'French',
      quality: 'medium',
      speaker: 'siwis',
      hfOnnxRel: 'fr/fr_FR/siwis/medium/fr_FR-siwis-medium.onnx',
    ),
    PiperVoiceOffer(
      id: 'de_DE-thorsten-medium',
      languageCode: 'de_DE',
      languageLabelEn: 'German',
      quality: 'medium',
      speaker: 'thorsten',
      hfOnnxRel: 'de/de_DE/thorsten/medium/de_DE-thorsten-medium.onnx',
    ),
    PiperVoiceOffer(
      id: 'es_ES-sharvard-medium',
      languageCode: 'es_ES',
      languageLabelEn: 'Spanish',
      quality: 'medium',
      speaker: 'sharvard',
      hfOnnxRel: 'es/es_ES/sharvard/medium/es_ES-sharvard-medium.onnx',
      approxSizeMB: 73,
    ),
    PiperVoiceOffer(
      id: 'ar_JO-kareem-medium',
      languageCode: 'ar_JO',
      languageLabelEn: 'Arabic',
      quality: 'medium',
      speaker: 'kareem',
      hfOnnxRel: 'ar/ar_JO/kareem/medium/ar_JO-kareem-medium.onnx',
    ),
    PiperVoiceOffer(
      id: 'bn_BD-google-medium',
      languageCode: 'bn_BD',
      languageLabelEn: 'Bengali',
      quality: 'medium',
      speaker: 'google',
      hfOnnxRel: 'bn/bn_BD/google/medium/bn_BD-google-medium.onnx',
      approxSizeMB: 73,
    ),
    PiperVoiceOffer(
      id: 'nl_NL-mls-medium',
      languageCode: 'nl_NL',
      languageLabelEn: 'Dutch',
      quality: 'medium',
      speaker: 'mls',
      hfOnnxRel: 'nl/nl_NL/mls/medium/nl_NL-mls-medium.onnx',
      approxSizeMB: 73,
    ),
    PiperVoiceOffer(
      id: 'pl_PL-darkman-medium',
      languageCode: 'pl_PL',
      languageLabelEn: 'Polish',
      quality: 'medium',
      speaker: 'darkman',
      hfOnnxRel: 'pl/pl_PL/darkman/medium/pl_PL-darkman-medium.onnx',
    ),
    PiperVoiceOffer(
      id: 'pt_BR-faber-medium',
      languageCode: 'pt_BR',
      languageLabelEn: 'Portuguese (BR)',
      quality: 'medium',
      speaker: 'faber',
      hfOnnxRel: 'pt/pt_BR/faber/medium/pt_BR-faber-medium.onnx',
    ),
    PiperVoiceOffer(
      id: 'ru_RU-irina-medium',
      languageCode: 'ru_RU',
      languageLabelEn: 'Russian',
      quality: 'medium',
      speaker: 'irina',
      hfOnnxRel: 'ru/ru_RU/irina/medium/ru_RU-irina-medium.onnx',
    ),
    PiperVoiceOffer(
      id: 'uk_UA-ukrainian_tts-medium',
      languageCode: 'uk_UA',
      languageLabelEn: 'Ukrainian',
      quality: 'medium',
      speaker: 'ukrainian_tts',
      hfOnnxRel:
          'uk/uk_UA/ukrainian_tts/medium/uk_UA-ukrainian_tts-medium.onnx',
      approxSizeMB: 73,
    ),
    PiperVoiceOffer(
      id: 'it_IT-paola-medium',
      languageCode: 'it_IT',
      languageLabelEn: 'Italian',
      quality: 'medium',
      speaker: 'paola',
      hfOnnxRel: 'it/it_IT/paola/medium/it_IT-paola-medium.onnx',
    ),
    PiperVoiceOffer(
      id: 'ko_KR-kss-medium',
      languageCode: 'ko_KR',
      languageLabelEn: 'Korean',
      quality: 'medium',
      speaker: 'kss',
      hfOnnxRel: 'ko/ko_KR/kss/medium/ko_KR-kss-medium.onnx',
    ),
    PiperVoiceOffer(
      id: 'tr_TR-dfki-medium',
      languageCode: 'tr_TR',
      languageLabelEn: 'Turkish',
      quality: 'medium',
      speaker: 'dfki',
      hfOnnxRel: 'tr/tr_TR/dfki/medium/tr_TR-dfki-medium.onnx',
    ),
    PiperVoiceOffer(
      id: 'sv_SE-nst-medium',
      languageCode: 'sv_SE',
      languageLabelEn: 'Swedish',
      quality: 'medium',
      speaker: 'nst',
      hfOnnxRel: 'sv/sv_SE/nst/medium/sv_SE-nst-medium.onnx',
    ),
    PiperVoiceOffer(
      id: 'fa_IR-gyro-medium',
      languageCode: 'fa_IR',
      languageLabelEn: 'Persian',
      quality: 'medium',
      speaker: 'gyro',
      hfOnnxRel: 'fa/fa_IR/gyro/medium/fa_IR-gyro-medium.onnx',
    ),
  ];

  /// Giọng ưu tiên — TẤT CẢ model của các ngôn ngữ ưu tiên, nhiều lựa chọn
  /// bản xứ cho mỗi ngôn ngữ. UI gom theo [languageCode] và mặc định GỘP.
  static List<PiperVoiceOffer> featured() => all.where((v) => v.isPriority).toList(growable: false);

  static List<PiperVoiceOffer> more() =>
      all.where((v) => !v.isPriority).toList(growable: false);

  /// Gom giọng theo mã ngôn ngữ, giữ thứ tự [languageCodes] nếu đưa vào
  /// (dùng để hiển thị ưu tiên trước, các ngôn ngữ còn lại theo thứ tự catalog).
  static Map<String, List<PiperVoiceOffer>> groupByLanguage(
    List<PiperVoiceOffer> offers, {
    List<String>? languageCodes,
  }) {
    final byLang = <String, List<PiperVoiceOffer>>{};
    for (final v in offers) {
      byLang.putIfAbsent(v.languageCode, () => []).add(v);
    }
    if (languageCodes == null) return byLang;
    final ordered = <String, List<PiperVoiceOffer>>{};
    for (final code in languageCodes) {
      final group = byLang.remove(code);
      if (group != null) ordered[code] = group;
    }
    ordered.addAll(byLang);
    return ordered;
  }

  static PiperVoiceOffer? byId(String id) {
    for (final v in all) {
      if (v.id == id) return v;
    }
    return null;
  }

  static String _norm(String code) =>
      code.trim().toLowerCase().replaceAll('-', '_');

  /// Khớp linh hoạt: `si_LK` == `si_LK`, và mã ngắn `si` khớp `si_LK`.
  static bool _codeMatches(String catalogCode, String query) {
    final o = _norm(catalogCode);
    final w = _norm(query);
    if (w.isEmpty) return false;
    if (o == w) return true;
    return o.split('_').first == w.split('_').first;
  }

  /// [languageCode] có giọng bản xứ TẢI ĐƯỢC trong catalog không.
  ///
  /// PSRC-260 — một cửa kiểm tra duy nhất để UI KHÔNG dựng một "lựa chọn"
  /// cho ngôn ngữ không có model tải thật. Chấp nhận cả `si_LK`, `si-LK`
  /// lẫn mã ngắn `si`.
  static bool hasNativeVoice(String languageCode) {
    if (languageCode.trim().isEmpty) return false;
    return all.any((v) => _codeMatches(v.languageCode, languageCode));
  }

  /// [languageCode] đã được xác nhận là Piper CHƯA có giọng bản xứ (khảo sát
  /// voices.json 2026-11). Đây là sự kiện TĨNH của catalog — KHÁC với "một
  /// giọng hợp lệ tải lỗi tạm thời do mạng": một giọng có thật trong [all]
  /// không bao giờ bị coi là unavailable chỉ vì một lần tải lỗi.
  static bool isUnavailable(String languageCode) {
    if (languageCode.trim().isEmpty) return false;
    return unavailableLanguages
        .any((u) => _codeMatches(u.languageCode, languageCode));
  }
}
