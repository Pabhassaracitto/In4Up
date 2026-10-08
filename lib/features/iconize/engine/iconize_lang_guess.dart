// lib/features/iconize/engine/iconize_lang_guess.dart
//
// ICONIZE-001d — đoán mã ngôn ngữ cho câu TRƯỚC khi đưa vào IconizeEngine.
//
// Vì sao cần: panel dịch PDF chạy với sourceLang = 'AUTO' là chủ yếu —
// engine lại cần langCode tường minh (en* đường chính, vi* qua Bridge,
// khác → giữ chữ toàn bộ). Heuristic ở đây CỐ Ý bảo thủ theo nguyên tắc
// safety-first của blueprint (mục 3.5): đoán sai về phía 'other' chỉ làm
// MẤT icon (giữ chữ — vô hại); đoán bừa 'en' cho tiếng Pháp/Đức có thể
// icon hóa sai nghĩa ("chat" tiếng Pháp = mèo ≠ chat EN). Vì vậy:
//
//  - Có khai báo tường minh (≠ AUTO) → tin khai báo, không đoán.
//  - Có dấu tiếng Việt → 'vi' (đặc trưng đủ mạnh).
//  - Chỉ chữ ASCII + có ít nhất một stopword tiếng Anh phổ biến → 'en'.
//    (câu Latin không stopword EN — pháp/đức/indonesia... → 'other').
//  - Còn lại → 'other' (engine trả rỗng — giữ chữ).
//
// Thuần Dart — test không cần Flutter.

final RegExp _viDiacriticsRe = RegExp(
  r'[àảãáạăằắẳẵặâầấẩẫậèẻẽéẹêềếểễệìỉĩíịòỏõóọôồốổỗộơờớởỡợùủũúụưừứửữựỳỷỹýỵđ]',
  caseSensitive: false,
);

final RegExp _nonAsciiLetterRe = RegExp(r'[^\x00-\x7F]');

// Stopword EN tần suất cao, ít trùng với các tiếng Latin khác ở dạng
// nguyên văn (bỏ "a"/"in" vì quá phổ quát).
const Set<String> _enStopwords = {
  'the', 'and', 'is', 'are', 'was', 'were', 'of', 'to', 'with',
  'this', 'that', 'it', 'on', 'for', 'at', 'he', 'she', 'they',
  'you', 'we', 'my', 'his', 'her', 'from', 'by', 'not', 'but',
  'have', 'will', 'there', 'their', 'what', 'your', 'its',
  'into', 'through',
};

final RegExp _asciiWordRe = RegExp(r"[A-Za-z][A-Za-z'\-]*");

/// Mã ngôn ngữ đưa vào IconizeEngine cho [text].
///
/// [declared] là mã nguồn do user/cài đặt khai báo ('AUTO' hoặc rỗng =
/// không khai báo). Trả 'en' / 'vi' / 'other' (hoặc nguyên văn mã khai báo
/// đã lowercase khi có).
String guessIconizeLang(String text, {String? declared}) {
  final d = declared?.trim().toLowerCase();
  if (d != null && d.isNotEmpty && d != 'auto') return d;

  if (_viDiacriticsRe.hasMatch(text)) return 'vi';
  if (_nonAsciiLetterRe.hasMatch(text)) return 'other';

  for (final m in _asciiWordRe.allMatches(text)) {
    if (_enStopwords.contains(m.group(0)!.toLowerCase())) return 'en';
  }
  return 'other';
}
