// DICT-TITLE-001 (owner 2026-10-27) — tên bộ từ điển sau khi cài hiện ra
// HTML thô và dấu `\` của định dạng MDX:
//
//   `<html><b>SImple English Dictionary(EN-EN)</b></html>`
//   `Từ\điẻn\ Anh -\ Việt\ v1.1`
//
// Cả hai chuỗi này là **trường `Title` trong header .mdx** — chúng tôi lấy
// nguyên văn rồi lưu vào manifest và in thẳng ra UI. Người dùng chỉ cần đọc
// "Simple English Dictionary (EN-EN)" và "Từ điển Anh - Việt v1.1".
//
// Vì sao phải làm sạch ở CẢ lúc đọc manifest (không chỉ lúc import): owner đã
// cài hai bộ này từ 1.17.0, tên bẩn đã nằm trong `manifest.json` trên máy —
// sửa mỗi đường import thì máy đang có vẫn hiện bẩn cho tới khi cài lại.
//
// Lớp này THUẦN Dart (không Flutter, không I/O) để test được trên CI.

/// Làm sạch tên bộ từ điển lấy từ header MDX (`Title=`) hoặc từ tên file.
class DictTitleCleaner {
  DictTitleCleaner._();

  /// Tối đa 80 ký tự — tên dài hơn là do header chứa cả đoạn mô tả.
  static const int maxLength = 80;

  /// Thẻ ngắt dòng phải thành khoảng trắng TRƯỚC khi bóc thẻ, nếu không
  /// `Anh<br>Việt` sẽ dính thành `AnhViệt`.
  static final RegExp _breakTags = RegExp(
    r'<\s*/?\s*(br|p|div|li|tr|td|th|h[1-6]|section|article)\b[^>]*>',
    caseSensitive: false,
  );

  /// Chỉ bóc thứ TRÔNG NHƯ thẻ: phải bắt đầu bằng chữ cái/`/`/`!`. Nếu bóc
  /// mọi cặp `<…>` thì một tiêu đề có `a < b > c` sẽ mất phần giữa.
  static final RegExp _tags = RegExp(r'<[a-zA-Z/!][^<>]{0,400}>');

  /// Entity dạng số: `&#39;` / `&#x27;`.
  static final RegExp _numericEntity = RegExp(r'&#(?:x([0-9a-fA-F]+)|(\d+));');

  static final RegExp _spaces = RegExp(r'\s+');

  /// Dấu phân cách mồ côi ở hai đầu, do header/bản dịch để lại.
  static final RegExp _edgeSeparators = RegExp(r'^[\s\-–—|:,;·•/\\]+');
  static final RegExp _edgeSeparatorsEnd = RegExp(r'[\s\-–—|:,;·•/\\]+$');

  static const Map<String, String> _namedEntities = <String, String>{
    'amp': '&',
    'lt': '<',
    'gt': '>',
    'quot': '"',
    'apos': "'",
    'nbsp': ' ',
    'ndash': '–',
    'mdash': '—',
    'hellip': '…',
    'laquo': '«',
    'raquo': '»',
    'ldquo': '“',
    'rdquo': '”',
    'lsquo': '‘',
    'rsquo': '’',
  };

  static final RegExp _namedEntity = RegExp(
    r'&([a-zA-Z][a-zA-Z0-9]{1,9});',
  );

  /// `true` khi [raw] KHÔNG phải dạng đã sạch ⇒ chỗ lưu (manifest) nên ghi đè.
  ///
  /// Dùng để nâng cấp dữ liệu cũ: manifest đang giữ tên bẩn của bản 1.17.0.
  static bool needsClean(String? raw) {
    if (raw == null) return false;
    final cleaned = clean(raw);
    return cleaned != null && cleaned != raw.trim();
  }

  /// Trả `null` khi không còn gì đọc được (để caller rơi về tên file).
  static String? clean(String? raw) {
    if (raw == null) return null;
    var text = raw;
    if (text.trim().isEmpty) return null;

    // 1. Ngắt dòng → khoảng trắng (trước khi bóc thẻ).
    text = text.replaceAll(_breakTags, ' ');

    // 2. Giải entity. Lặp 2 lượt: dữ liệu thật có `&amp;lt;` (escape hai lớp)
    //    và `<b>Anh &amp; Việt</b>`.
    for (var pass = 0; pass < 2; pass++) {
      text = _decodeEntities(text);
    }

    // 3. Bóc thẻ HTML còn lại (`<html>`, `<b>`, `<span style=…>`).
    text = text.replaceAll(_tags, ' ');

    // 4. Dấu `\` của định dạng MDX (escape khoảng trắng / phân cách từ).
    //    `Từ\điẻn\ Anh -\ Việt\ v1.1` → `Từ điẻn  Anh -  Việt v1.1`.
    //    Trong tên hiển thị, `\` không bao giờ có nghĩa ⇒ đổi thành khoảng
    //    trắng rồi gộp khoảng trắng là an toàn nhất.
    if (text.contains('\\')) {
      text = text.replaceAll('\\', ' ');
    }

    // 5. Gộp khoảng trắng + cắt dấu phân cách mồ côi ở hai đầu.
    text = text.replaceAll(_spaces, ' ').trim();
    text = text.replaceAll(_edgeSeparators, '');
    text = text.replaceAll(_edgeSeparatorsEnd, '').trim();

    // 6. Chuẩn hoá lại nếu bước 5 để lại khoảng trắng (vd `A -  B`).
    text = text.replaceAll(_spaces, ' ').trim();
    if (text.isEmpty) return null;
    if (text.length > maxLength) {
      text = '${text.substring(0, maxLength - 1).trimRight()}…';
    }
    return text;
  }

  /// Như [clean] nhưng cho phép fallback: trả [fallback] khi không đọc được.
  static String cleanOr(String? raw, String fallback) =>
      clean(raw) ?? clean(fallback) ?? fallback;

  static String _decodeEntities(String text) {
    if (!text.contains('&')) return text;
    var out = text.replaceAllMapped(_numericEntity, (match) {
      final hex = match.group(1);
      final dec = match.group(2);
      final code = hex != null
          ? int.tryParse(hex, radix: 16)
          : int.tryParse(dec ?? '');
      if (code == null || code <= 0 || code > 0x10FFFF) return ' ';
      return String.fromCharCode(code);
    });
    out = out.replaceAllMapped(_namedEntity, (match) {
      final value = _namedEntities[match.group(1)!.toLowerCase()];
      return value ?? match.group(0)!;
    });
    return out;
  }
}
