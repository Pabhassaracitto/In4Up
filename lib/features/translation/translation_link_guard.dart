// lib/features/translation/translation_link_guard.dart
//
// AUDIT-1.21.0 #6 — "Bản dịch ra https://linux.do/t/topic/111737 dù có model".
//
// Triệu chứng thật (owner 06/11): chạy DeepLX trong Termux, lấy một link dán
// vào, kết quả dịch CHỈ là chính dòng link đó. Đường đi trong code:
//
//   1. Một URL thuần (không có câu chữ) đi qua `detectSourceLanguage` → thường
//      bị đoán thành đúng ngôn ngữ đích (VI) vì "topic", "do", "linux"… ⇒
//      `_translateTextInternal` nhánh `source == target` trả NGUYÊN VĂN, ghi
//      là "↔️ Cùng ngôn ngữ" ⇒ UI hiện URL như thể đó là bản dịch.
//   2. Hoặc engine online/offline trả nguyên link (link là "untranslatable"),
//      `_looksUntranslated` bỏ qua vì so sánh chuỗi normalize bằng nhau… rồi
//      bước từ điển last-resort vẫn nhả nguyên link ra.
//   3. Dịch màn hình: thanh địa chỉ / link trong bài bị OCR thành 1 khối chữ
//      ⇒ overlay vẽ đúng cái URL đó như "bản dịch".
//
// Sửa ở một chỗ, dùng chung cho cả 3 đường: nhận diện "chỉ có liên kết" bằng
// hàm THUẦN (test host VM), trả kết quả rõ ràng thay vì giả vờ dịch xong.
// Không đụng nội dung user: một câu CÓ kèm link vẫn được dịch bình thường.

/// Thông báo lỗi (English — canonical fallback của rule #5; tầng service
/// không có BuildContext để gọi `uiText`).
const String kLinkOnlyTranslationMessage =
    'Only a link was provided — there is no text to translate.';

final RegExp _schemeUrl = RegExp(
  r'^(?:https?|ftp)://[^\s<>"\']+$',
  caseSensitive: false,
);
final RegExp _wwwUrl = RegExp(
  r'^www\.[a-z0-9\-]+(?:\.[a-z0-9\-]+)+[^\s<>"\']*$',
  caseSensitive: false,
);
final RegExp _bareDomain = RegExp(
  r'^[a-z0-9\-]+(?:\.[a-z0-9\-]+){1,}(?:/[^\s<>"\']*)?$',
  caseSensitive: false,
);
final RegExp _punctuationOnly = RegExp(r'^[\p{P}\p{S}]+$', unicode: true);

String _stripWrappers(String token) {
  var value = token.trim();
  // Dấu ngoặc/vết câu hay dính quanh link khi copy từ trình duyệt hoặc OCR.
  const pairs = [
    ['(', ')'],
    ['[', ']'],
    ['{', '}'],
    ['<', '>'],
    ['"', '"'],
    ["'", "'"],
  ];
  for (final pair in pairs) {
    if (value.startsWith(pair[0]) && value.endsWith(pair[1]) &&
        value.length > 1) {
      value = value.substring(1, value.length - 1).trim();
    }
  }
  while (value.isNotEmpty &&
      (value.endsWith(',') ||
          value.endsWith('.') ||
          value.endsWith(';') ||
          value.endsWith(':') ||
          value.endsWith('!') ||
          value.endsWith('?'))) {
    value = value.substring(0, value.length - 1).trim();
  }
  return value;
}

bool isUrlToken(String raw) {
  final token = _stripWrappers(raw);
  if (token.isEmpty) return false;
  if (_schemeUrl.hasMatch(token) || _wwwUrl.hasMatch(token)) return true;
  // `linux.do/t/topic/111737` (không có scheme) vẫn là link.
  if (_bareDomain.hasMatch(token)) {
    final host = token.split('/').first.toLowerCase();
    return host.contains('.') && !host.endsWith('.');
  }
  return false;
}

/// True khi toàn bộ [text] chỉ gồm 1+ liên kết (và dấu câu / khoảng trắng).
///
///  • `'https://linux.do/t/topic/111737'` → true
///  • `'https://a.com https://b.com'` → true
///  • `'Xem thêm: https://linux.do/t/topic/111737'` → false (vẫn dịch câu)
///  • `''` / `'12:30'` → false
bool isLinkOnlyText(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return false;
  var links = 0;
  var words = 0;
  for (final raw in trimmed.split(RegExp(r'\s+'))) {
    if (raw.isEmpty) continue;
    if (isUrlToken(raw)) {
      links++;
      continue;
    }
    if (_punctuationOnly.hasMatch(raw)) continue;
    words++;
  }
  return links > 0 && words == 0;
}
