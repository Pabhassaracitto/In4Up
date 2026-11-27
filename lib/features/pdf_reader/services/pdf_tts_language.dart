// lib/features/pdf_reader/services/pdf_tts_language.dart
//
// AUDIT v1.30.1 (mục 1) — «Tab đọc · PDF reader: phần cài đặt chỉ có giọng đọc
// English và Tiếng Việt ⇒ phải có thêm ngôn ngữ khác».
//
// Vì sao tách file: bảng chọn giọng đọc nằm trong `pdf_toolbar.dart` — file
// import plugin (`flutter/services`, TTS engine) nên KHÔNG chạy được trên host
// VM. Toàn bộ luật "mã nào hợp lệ / nhãn nào hiển thị / giọng nào thuộc ngôn
// ngữ nào" là dữ liệu thuần, tách ra đây để test bằng Dart thường (cùng lý do
// `pdf_page_translate.dart` và `pdf_tts_machine.dart` đã tách).
//
// Nguồn sự thật duy nhất là [AppLanguageCatalog] — 26 ngôn ngữ mà app đã dùng
// cho cài đặt ngôn ngữ, dịch và TTS. Trước đây bảng đọc PDF tự khai báo một
// danh sách 3 dòng ('auto', 'en-US', 'vi-VN'); nay dùng chung catalog nên
// thêm ngôn ngữ ở một nơi là mọi bề mặt có ngay.

import '../../../core/language/app_language.dart';

/// Khoá SharedPreferences lưu ngôn ngữ đọc của PDF Reader.
///
/// Giữ NGUYÊN chuỗi cũ `pdf_tts_locale` (người dùng đã cài app không mất lựa
/// chọn), chỉ đổi phạm vi giá trị được chấp nhận.
const String kPdfTtsLocalePrefKey = 'pdf_tts_locale';

/// Giá trị «để engine tự nhận diện ngôn ngữ».
const String kPdfTtsAutoCode = 'auto';

/// Chuẩn hoá một mã ngôn ngữ đọc về dạng mà [AppLanguage.ttsLocale] dùng.
///
/// Nhận: `auto`/`AUTO`/`tự động`/rỗng → [kPdfTtsAutoCode]; mã trong catalog ở
/// bất kỳ dạng nào (`vi`, `vi-VN`, `VI`, `vi_VN`, `VIE`…) → `ttsLocale` chuẩn
/// (`vi-VN`). Mã lạ → [kPdfTtsAutoCode] (an toàn hơn đoán bừa: engine tự nhận
/// diện vẫn đọc đúng, còn ghim sai ngôn ngữ thì đọc sai hẳn).
String normalizePdfTtsLanguage(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return kPdfTtsAutoCode;
  final lower = value.toLowerCase().replaceAll('_', '-');
  if (lower == kPdfTtsAutoCode || lower == 'system') return kPdfTtsAutoCode;
  final resolved = AppLanguageCatalog.maybeFromCode(value);
  return resolved?.ttsLocale ?? kPdfTtsAutoCode;
}

/// Nhãn NGẮN cho chip trên bảng cài đặt đọc: cờ + tên bản ngữ.
///
/// `auto` không có quốc gia ⇒ dùng nhãn chữ (đã qua i18n ở nơi gọi).
/// Trả `null` khi mã không nằm trong catalog để nơi gọi tự quyết định
/// (thường là rơi về nhãn «Tự động»).
AppLanguage? pdfTtsLanguageFor(String? code) {
  final normalized = normalizePdfTtsLanguage(code);
  if (normalized == kPdfTtsAutoCode) return null;
  return AppLanguageCatalog.maybeFromCode(normalized);
}

/// Nhãn chip cho một mã: `🇻🇳 Tiếng Việt`, `🇯🇵 日本語` …
///
/// Vì sao trả `null` thay vì đoán: rule #5 của repo cấm tự sinh key i18n;
/// nhãn «Tự động» do nơi gọi dịch (`context.uiText('Tự động')`), còn tên bản
/// ngữ thì KHÔNG dịch (người học cần đọc được chính tên đó).
String? pdfTtsLanguageLabel(String? code) {
  final language = pdfTtsLanguageFor(code);
  if (language == null) return null;
  return '${language.flag} ${language.nativeName}';
}

/// Danh sách ngôn ngữ ĐỌC được đề xuất, xếp theo độ liên quan cho người học.
///
/// `auto` luôn đứng đầu; tiếp theo là các ngôn ngữ người Việt học nhiều nhất
/// (Anh, Trung, Nhật, Hàn, Đài, Pháp, Đức, Tây Ban Nha, Nga, Thái, Lào,
/// Khmer, Ả Rập, Hindi…), phần còn lại theo thứ tự catalog. Sắp xếp ở đây chứ
/// không ở UI để test được và để mọi bề mặt (chip + sheet + test) cùng một thứ
/// tự.
const List<String> _kPreferredTtsLocales = <String>[
  // Thứ tự = mức độ phổ biến với người học Việt Nam, KHÔNG phải bảng chữ
  // cái: ai mở bảng này cũng đang học 1 trong ~5 ngôn ngữ đầu.
  // (Chỉ được chứa mã CÓ trong AppLanguageCatalog — mã lạ bị lọc bỏ, và test
  // `pdf_tts_language_test` kiểm tra đúng điều đó.)
  'en-US',
  'zh-CN',
  'ja-JP',
  'ko-KR',
  'vi-VN',
  'zh-TW',
  'fr-FR',
  'de-DE',
  'es-ES',
  'ru-RU',
  'th-TH',
  'lo-LA',
  'km-KH',
  'my-MM',
  'ar-SA',
  'hi-IN',
  'id-ID',
  'pt-PT',
  'it-IT',
  'bn-BD',
  'si-LK',
  'ta-IN',
  'te-IN',
  'mr-IN',
  'mn-MN',
  'bo-CN',
];

/// Ngôn ngữ đọc theo thứ tự ưu tiên ở trên; mã nào catalog không có thì bỏ.
///
/// Kết quả KHÔNG chứa «Tự động» — nơi gọi tự thêm chip đó (cần i18n).
List<AppLanguage> pdfTtsLanguageOptions() {
  final byLocale = <String, AppLanguage>{
    for (final language in AppLanguageCatalog.languages)
      language.ttsLocale: language,
  };
  final ordered = <AppLanguage>[];
  final seen = <String>{};
  for (final locale in _kPreferredTtsLocales) {
    final language = byLocale[locale];
    if (language == null) continue;
    ordered.add(language);
    seen.add(locale);
  }
  for (final language in AppLanguageCatalog.languages) {
    if (seen.contains(language.ttsLocale)) continue;
    ordered.add(language);
  }
  return List<AppLanguage>.unmodifiable(ordered);
}
