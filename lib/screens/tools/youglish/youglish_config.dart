// lib/screens/tools/youglish/youglish_config.dart
//
// PRON-001 (ADR-0015) — MỘT nguồn sự thật cho cấu trúc URL YouGlish.
// Trước PRON-001 có HAI bản `_buildUrl()` trùng nhau (youglish_widget.dart và
// youglish_mini_sheet.dart, PRON-002 dọn về cùng thư mục) — xem
// test/youglish/youglish_url_test.dart
// để biết vì sao URL phải giữ nguyên từng byte.
//
// File này THUẦN DART (không import flutter/dart:io/plugin) để golden test chạy
// được trong CI `app_analyze` mà không cần plugin WebView.

/// Ngôn ngữ YouGlish. `code` là segment đường dẫn của
/// `youglish.com/pronounce/<word>/<code>`.
///
/// Danh sách lấy từ dropdown ngôn ngữ của chính youglish.com (đối chiếu
/// 2026-10-24). Đã kiểm tra trực tiếp: `english`, `vietnamese`.
/// `code` ở giữa `.` của các mục còn lại nên được verify lại trên máy khi dùng
/// (PRON-002/003) — nếu sai, YouGlish trả trang không có video, không crash.
enum YouGlishLanguage {
  english('English', 'english'),
  vietnamese('Vietnamese', 'vietnamese'),
  hindi('Hindi', 'hindi'),
  chinese('Chinese', 'chinese'),
  japanese('Japanese', 'japanese'),
  korean('Korean', 'korean'),
  arabic('Arabic', 'arabic'),
  french('French', 'french'),
  spanish('Spanish', 'spanish'),
  portuguese('Portuguese', 'portuguese'),
  german('German', 'german'),
  italian('Italian', 'italian'),
  russian('Russian', 'russian'),
  greek('Greek', 'greek'),
  hebrew('Hebrew', 'hebrew'),
  indonesian('Indonesian', 'indonesian'),
  dutch('Dutch', 'dutch'),
  thai('Thai', 'thai'),
  turkish('Turkish', 'turkish'),
  persian('Persian', 'persian'),
  polish('Polish', 'polish'),
  romanian('Romanian', 'romanian'),
  swedish('Swedish', 'swedish'),
  ukrainian('Ukrainian', 'ukrainian');

  final String displayName;
  final String code;

  const YouGlishLanguage(this.displayName, this.code);

  /// Ngược của [code]; `null` nếu không khớp (dữ liệu cũ/lưu lỗi).
  static YouGlishLanguage? fromCode(String? code) {
    if (code == null) return null;
    for (final l in values) {
      if (l.code == code) return l;
    }
    return null;
  }
}

/// Giọng (accent) tiếng Anh — hàng accent của YouGlish:
/// US · UK · AUS · CAN · IE · SCO · NZ (đối chiếu 2026-10-24; đã kiểm tra
/// trực tiếp `english/can`).
enum YouGlishAccent {
  us('American (US)', 'us'),
  uk('British (UK)', 'uk'),
  aus('Australian', 'aus'),
  can('Canadian', 'can'),
  ie('Irish', 'ie'),
  sco('Scottish', 'sco'),
  nz('New Zealand', 'nz');

  final String displayName;
  final String code;

  const YouGlishAccent(this.displayName, this.code);

  static YouGlishAccent? fromCode(String? code) {
    if (code == null) return null;
    for (final a in values) {
      if (a.code == code) return a;
    }
    return null;
  }
}

/// Máy dựng URL YouGlish duy nhất của toàn app.
///
/// Hành vi PHẢI GIỮ NGUYÊN với hai điểm vào cũ:
///  * `YouGlishScreen` → accent chỉ được nối khi ngôn ngữ là English
///    (screen truyền `null` cho ngôn ngữ khác) và `autoPlay` bật.
///  * `YouGlishMiniSheet` → English luôn có accent (mặc định `us`), luôn
///    `autoplay=1`.
/// Mọi thay đổi ở đây đều là **đổi hành vi** ⇒ theo plan, việc đó thuộc
/// PRON-003 (tắt autoplay mặc định) / PRON-004 (widget chính thức).
class YouGlishUrl {
  YouGlishUrl._();

  static const String host = 'https://youglish.com/pronounce/';

  static String build({
    required String word,
    required YouGlishLanguage language,
    YouGlishAccent? accent,
    bool autoplay = true,
  }) {
    var url = '$host${Uri.encodeComponent(word)}';
    if (language == YouGlishLanguage.english && accent != null) {
      url += '/${language.code}/${accent.code}';
    } else {
      url += '/${language.code}';
    }
    // `embed` + `autoplay` KHÔNG có trong tài liệu YouGlish (widget chính thức
    // dùng <a class="youglish-widget"> + public/emb/widget.js). Giữ nguyên vì
    // PRON-001 cấm đổi hành vi; xem ADR-0015 D2 + card PRON-004.
    url += '?embed=1';
    if (autoplay) url += '&autoplay=1';
    return url;
  }
}
