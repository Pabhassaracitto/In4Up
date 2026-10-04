// Dựng pattern tìm kiếm trong PDF cho người dùng Việt.
//
// pdfrx tìm bằng `Pattern.allMatches` trên `PdfPageText.fullText` (một chuỗi
// ghép của cả trang) nên chỉ cần đưa đúng một RegExp là có: bỏ qua hoa/thường,
// tuỳ chọn bỏ qua thanh điệu, khớp cả trường hợp xuống dòng giữa câu. Đặt ở
// service để test được mà không cần mở file PDF.

/// Các "họ" chữ cái được coi là NHƯ NHAU khi bật *Không phân biệt dấu*: bỏ hết dấu
/// câu lẫn mũ/lưỡi (ă→a, â→a, ê→e, ô/ơ→o, ư→u, đ→d) — đúng nghĩa "gõ không dấu"
/// mà người dùng Việt nhập.
///
/// MỖI ký tự trong query vẫn chỉ khớp ĐÚNG MỘT ký tự trong trang (`1:1`), nên
/// offset `start/end` pdfrx nhận lại vẫn chính xác và highlight không lệch. Điều
/// ta KHÔNG làm là co giãn `aa`↔`â`: kiểu đó phá vỡ offset để đổi lấy vài kết quả
/// kiểu gõ Telex — không đáng.
const List<String> _foldGroups = [
  'aàáảãạăằắẳẵặâầấẩẫậ',
  'eèéẻẽẹêềếểễệ',
  'iìíỉĩị',
  'oòóỏõọôồốổỗộơờớởỡợ',
  'uùúủũụưừứửữự',
  'yỳýỷỹỵ',
  'dđ',
];

/// Tra chiều ngược lại: mọi thành viên (thường) của một họ → cả họ.
final Map<String, String> _toneFamilies = <String, String>{
  for (final group in _foldGroups)
    for (final rune in group.runes) String.fromCharCode(rune): group,
};

const Set<String> _regexSpecial = {
  r'\', '.', '*', '+', '?', '^', r'$', '(', ')', '[', ']', '{', '}', '|', '/',
  '=', '!', '<', '>', '@', '%', ':',
};

/// Chuỗi quá ngắn thì quét cả cuốn sách là lãng phí (và toàn kết quả nhiễu).
bool isPdfSearchQueryMeaningful(String raw, {int minLength = 2}) =>
    raw.trim().runes.length >= minLength;

/// RegExp đưa cho `PdfTextSearcher.startTextSearch`.
///
/// Trả về `null` khi query rỗng. `caseSensitive: false` là chưa đủ cho chữ có
/// dấu (engine Dart chỉ tự hạ hoa với ASCII) nên ta nhét cả biến thể HOA vào
/// lớp ký tự.
RegExp? buildPdfSearchPattern(String raw, {bool ignoreTones = false}) {
  final query = raw.trim();
  if (query.isEmpty) return null;

  final buffer = StringBuffer();
  var inWhitespace = false;
  for (final rune in query.runes) {
    final ch = String.fromCharCode(rune);
    if (ch.trim().isEmpty) {
      if (!inWhitespace) {
        buffer.write(r'\s+');
        inWhitespace = true;
      }
      continue;
    }
    inWhitespace = false;

    final family = ignoreTones ? _toneFamilies[ch.toLowerCase()] : null;
    final chars = <String>{};
    if (family != null) {
      for (final variant in family.split('')) {
        chars.add(variant);
        chars.add(variant.toUpperCase());
      }
    } else {
      chars.add(ch);
      chars.add(ch.toLowerCase());
      chars.add(ch.toUpperCase());
    }

    if (chars.length == 1) {
      buffer.write(_escapeLiteral(chars.first));
    } else {
      buffer.write('[${chars.map(_escapeForCharClass).join()}]');
    }
  }

  final pattern = buffer.toString();
  if (pattern.isEmpty) return null;
  return RegExp(pattern, caseSensitive: false, unicode: true);
}

String _escapeLiteral(String char) =>
    _regexSpecial.contains(char) ? '\\$char' : char;

String _escapeForCharClass(String char) {
  // Trong `[...]` chỉ bốn ký tự này có ý nghĩa đặc biệt.
  if (char == r'\' || char == ']' || char == '^' || char == '-') {
    return '\\$char';
  }
  return char;
}

/// Đoạn ngữ cảnh quanh kết quả, đã gấp khoảng trắng. Dùng cho danh sách kết quả.
String pdfSearchSnippet(
  String fullText,
  int start,
  int end, {
  int radius = 46,
}) {
  final safeStart = _clamp(start, 0, fullText.length);
  final safeEnd = _clamp(end, safeStart, fullText.length);
  final from = _clamp(safeStart - radius, 0, fullText.length);
  final to = _clamp(safeEnd + radius, 0, fullText.length);
  final slice = fullText.substring(from, to).replaceAll(RegExp(r'\s+'), ' ').trim();
  if (slice.isEmpty) return '';
  final head = from > 0 ? '…' : '';
  final tail = to < fullText.length ? '…' : '';
  return '$head$slice$tail';
}

/// Clamp tường minh thay cho `num.clamp`: an toàn tuyệt đối về kiểu tĩnh khi đưa
/// vào `String.substring(int, int)`.
int _clamp(int value, int min, int max) =>
    value < min ? min : (value > max ? max : value);
