// lib/features/dharma/services/dharma_text.dart
//
// Tiện ích chuỗi thuần cho pháp thoại (0 I/O, 0 plugin) — test được trên CI
// không cần Flutter engine: bỏ dấu tiếng Việt/Pāḷi, so sánh "natural".

/// Bỏ dấu (diacritics) và hạ chữ thường.
///
/// Không dùng `dart:convert`/ICU: bảng thay thế tường minh để kết quả ỔN ĐỊNH
/// giữa các nền tảng (cùng chuỗi ⇒ cùng khoá, nếu không bộ lọc "theo Thầy" sẽ
/// tách một vị Thầy thành nhiều mục).
String foldDiacritics(String input) {
  var s = input.toLowerCase();
  // Chữ có dấu đặc thù tiếng Việt (không phân rã được bằng bảng Latin).
  const vietnamese = {
    'đ': 'd',
    'ơ': 'o',
    'ư': 'u',
  };
  vietnamese.forEach((k, v) => s = s.replaceAll(k, v));

  // Latin-1 Supplement + Latin Extended-A/B (Pāḷi: ā ī ū ṅ ñ ṭ ḍ ṇ ḷ ṃ).
  const latin = {
    'à': 'a', 'á': 'a', 'ả': 'a', 'ã': 'a', 'ạ': 'a',
    'ă': 'a', 'ằ': 'a', 'ắ': 'a', 'ẳ': 'a', 'ẵ': 'a', 'ặ': 'a',
    'â': 'a', 'ầ': 'a', 'ấ': 'a', 'ẩ': 'a', 'ẫ': 'a', 'ậ': 'a',
    'ā': 'a',
    'è': 'e', 'é': 'e', 'ẻ': 'e', 'ẽ': 'e', 'ẹ': 'e',
    'ē': 'e',
    'ì': 'i', 'í': 'i', 'ỉ': 'i', 'ĩ': 'i', 'ị': 'i', 'ī': 'i',
    'ò': 'o', 'ó': 'o', 'ỏ': 'o', 'õ': 'o', 'ọ': 'o',
    'ồ': 'o', 'ố': 'o', 'ổ': 'o', 'ỗ': 'o', 'ộ': 'o',
    'ờ': 'o', 'ớ': 'o', 'ở': 'o', 'ỡ': 'o', 'ợ': 'o',
    'ō': 'o',
    'ù': 'u', 'ú': 'u', 'ủ': 'u', 'ũ': 'u', 'ụ': 'u',
    'ừ': 'u', 'ứ': 'u', 'ử': 'u', 'ữ': 'u', 'ự': 'u',
    'ū': 'u',
    'ỳ': 'y', 'ý': 'y', 'ỷ': 'y', 'ỹ': 'y', 'ỵ': 'y',
    'ñ': 'n', 'ṇ': 'n', 'ṅ': 'n', 'ń': 'n',
    'ṭ': 't', 'ḍ': 'd',
    'ḷ': 'l', 'ļ': 'l', 'ĺ': 'l',
    'ṃ': 'm', 'ṁ': 'm',
    'ś': 's', 'ṣ': 's', 'š': 's',
    'ç': 'c', 'č': 'c',
    'ğ': 'g', 'ġ': 'g',
    'ṛ': 'r', 'ř': 'r',
    'ß': 'ss', 'æ': 'ae', 'œ': 'oe',
  };
  final buffer = StringBuffer();
  for (final rune in s.runes) {
    final ch = String.fromCharCode(rune);
    buffer.write(latin[ch] ?? ch);
  }
  return buffer.toString();
}

/// Khoá tìm kiếm: bỏ dấu + chỉ giữ chữ/số + gạch dưới, gộp mọi dấu cách.
String searchKey(String input) {
  final folded = foldDiacritics(input);
  final cleaned = folded.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  return cleaned.replaceAll(RegExp(r'\s+'), '_');
}

/// So sánh "natural": `B2 < B10`, `2. … < 10. …`.
///
/// Drive trả danh sách theo lexicographic ⇒ `B10, B11, B2…`; nếu hiển thị
/// nguyên thứ tự API thì người nghe mở sai bài (PLAN-042 F1).
int naturalCompare(String a, String b) {
  final ta = _tokenize(a);
  final tb = _tokenize(b);
  final n = ta.length < tb.length ? ta.length : tb.length;
  for (var i = 0; i < n; i++) {
    final x = ta[i];
    final y = tb[i];
    final xNum = x.number;
    final yNum = y.number;
    int cmp;
    if (xNum != null && yNum != null) {
      cmp = xNum.compareTo(yNum);
    } else if (xNum != null) {
      // Số đứng trước chữ: "01." trước "A-01".
      cmp = -1;
    } else if (yNum != null) {
      cmp = 1;
    } else {
      cmp = x.text.compareTo(y.text);
    }
    if (cmp != 0) return cmp;
  }
  return ta.length.compareTo(tb.length);
}

class _NatToken {
  final String text;
  final int? number;
  const _NatToken(this.text, this.number);
}

List<_NatToken> _tokenize(String input) {
  final tokens = <_NatToken>[];
  final lower = foldDiacritics(input);
  var i = 0;
  while (i < lower.length) {
    final code = lower.codeUnitAt(i);
    final isDigit = code >= 0x30 && code <= 0x39;
    var j = i;
    if (isDigit) {
      while (j < lower.length) {
        final c = lower.codeUnitAt(j);
        if (c < 0x30 || c > 0x39) break;
        j++;
      }
      final chunk = lower.substring(i, j);
      tokens.add(_NatToken(chunk, int.tryParse(chunk)));
    } else {
      while (j < lower.length) {
        final c = lower.codeUnitAt(j);
        if (c >= 0x30 && c <= 0x39) break;
        j++;
      }
      final chunk = lower.substring(i, j).trim();
      if (chunk.isNotEmpty) tokens.add(_NatToken(chunk, null));
    }
    i = j;
  }
  return tokens;
}
