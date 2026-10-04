/// ═══════════════════════════════════════════════════════════════
/// SEGMENTER — tách đoạn có VỊ TRÍ, không chặt nhầm viết tắt/số
///
/// Handoff MVA v2.0 — Task 4 (DoD test: "Mr.", "U.S.", số thập phân,
/// câu tiếng Việt ghép phải tách ĐÚNG).
///
/// Quy tắc chấm-kết-thúc-câu (tại '.'):
///  * BỎ QUA nếu hai bên là chữ số (3.14 / 1.000 / 3,14-style an toàn clause)
///  * BỎ QUA nếu là viết tắt đã biết (Mr. Mrs. Ms. Dr. Prof. Jr. Sr.
///    St. vs. etc. e.g. i.e. vv. GS. TS. ThS. TP.)
///  * BỎ QỤA nếu là acronym chấm (U.S. / U.K. / a.m. — pattern (X.){2,})
///    (giới hạn v1: "cuối câu đúng lúc acronym" типа "…in the U.S. Next…"
///    sẽ không tách — chấp nhận, có doc ở SKILL/test)
///  * KẾT THÚC nếu kí tự không-khoảng-trắng kế tiếp là HOA hoặc hết chuỗi.
/// Mệnh đề (clause): tách tại , ; : — trừ giữa hai chữ số (1,000 / 3,14).
/// Thuần dart:core.
/// ═══════════════════════════════════════════════════════════════
library;

/// Một đoạn văn có vị trí trong chuỗi (đã normalize) — dùng cho
/// Evidence.locator.offset của schema mục 2.2.
class Segment {
  final String text;
  final int start;
  final int end;

  const Segment({
    required this.text,
    required this.start,
    required this.end,
  });

  Map<String, dynamic> toJson() =>
      <String, dynamic>{'text': text, 'start': start, 'end': end};

  factory Segment.fromJson(Map<String, dynamic> json) => Segment(
        text: json['text'] as String,
        start: json['start'] as int,
        end: json['end'] as int,
      );
}

class TextSegmenter {
  TextSegmenter._();

  /// Viết tắt đứng TRƯỚC dấu chấm (không phân biệt hoa thường).
  static final Set<String> _abbreviations = <String>{
    'mr', 'mrs', 'ms', 'dr', 'prof', 'sr', 'jr', 'st', 'vs', 'etc',
    'eg', 'ie', 'vv', 'gs', 'ts', 'ths', 'tp', // GS/TS/ThS/TP (Việt)
    'inc', 'ltd', 'co', 'dept', 'univ', 'approx', 'min', 'max',
  };

  /// Acronym dạng chấm: "U.S.", "U.K." — khớp phần đuôi chuỗi.
  static final RegExp _dottedAcronymTail = RegExp(r'(?:[A-Za-z]\.){2,}$');

  /// Từ liền trước (chỉ chữ) dùng để tra viết tắt.
  static final RegExp _tailWord = RegExp(r'[\p{L}]+$', unicode: true);

  static bool _isDigitAt(String s, int i) =>
      i >= 0 && i < s.length && s.codeUnitAt(i) >= 0x30 && s.codeUnitAt(i) <= 0x39;

  static final RegExp _singleLetter = RegExp(r'\p{L}', unicode: true);

  static bool _isLetterAt(String s, int i) =>
      i >= 0 && i < s.length && _singleLetter.hasMatch(s[i]);

  static bool _isUpper(String s, int i) {
    if (i < 0 || i >= s.length) return false;
    final c = s[i];
    return c != c.toLowerCase();
  }

  /// Kí tự không-trắng đầu tiên sau [from]; null nếu chỉ khoảng trắng tới cuối.
  static int? _nextNonSpace(String s, int from) {
    for (var i = from; i < s.length; i++) {
      if (!_isWhitespace(s.codeUnitAt(i))) return i;
    }
    return null;
  }

  static bool _isWhitespace(int cu) =>
      cu == 0x20 || cu == 0x09 || cu == 0x0A || cu == 0x0D;

  /// Tách đoạn văn theo dòng trống (\n\n trở lên).
  static List<Segment> paragraphs(String text) {
    final result = <Segment>[];
    var start = 0;
    for (var i = 0; i < text.length; i++) {
      if (_isNewlineAt(text, i) && _isNewlineAt(text, i + 1)) {
        _flushParagraph(text, start, i, result);
        // bỏ qua cụm \n liên tiếp
        var j = i;
        while (j < text.length && _isNewlineAt(text, j)) {
          j++;
        }
        start = j;
        i = j - 1;
      }
    }
    _flushParagraph(text, start, text.length, result);
    return result;
  }

  static bool _isNewlineAt(String s, int i) =>
      i >= 0 && i < s.length && s.codeUnitAt(i) == 0x0A;

  static void _flushParagraph(String text, int start, int end, List<Segment> out) {
    final t = text.substring(start, end).trim();
    if (t.isEmpty) return;
    final realStart = start + (text.substring(start, end).indexOf(t));
    out.add(Segment(text: t, start: realStart, end: realStart + t.length));
  }

  /// Tách câu — bộ máy chính của DoD Task 4.
  static List<Segment> sentences(String text) {
    final result = <Segment>[];
    var start = 0;
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (ch != '.' && ch != '!' && ch != '?' && ch != '\n') continue;

      if (ch == '\n') {
        // Xuống dòng đơn cũng kết thúc câu (kinh nghiệm sub/audio).
        final seg = text.substring(start, i).trim();
        if (seg.isNotEmpty) {
          result.add(Segment(
              text: seg,
              start: start + text.substring(start, i).indexOf(seg),
              end: start + text.substring(start, i).indexOf(seg) + seg.length));
        }
        start = i + 1;
        continue;
      }

      // Số thập phân / hàng nghìn: bỏ qua chấm/phẩy giữa hai chữ số.
      if (ch == '.' && _isDigitAt(text, i - 1) && _isDigitAt(text, i + 1)) {
        continue;
      }

      if (ch == '.') {
        // Acronym chấm ĐANG Ở GIỮA: "U." trong "U.S." — kí tự hai bên là
        // chữ và kí tự kế tiếp nữa lại là chấm ⇒ không kết thúc câu.
        if (_isLetterAt(text, i - 1) &&
            _isLetterAt(text, i + 1) &&
            i + 2 < text.length &&
            text[i + 2] == '.') {
          continue;
        }
        final head = text.substring(0, i + 1);
        // Acronym chấm CUỐI: "U.S." — không kết thúc câu.
        if (_dottedAcronymTail.hasMatch(head)) continue;
        // Viết tắt đã biết: "Mr." — không kết thúc câu.
        final word = _tailWord.firstMatch(text.substring(0, i));
        if (word != null && _abbreviations.contains(word.group(0)!.toLowerCase())) {
          continue;
        }
      }

      // Kết thúc nếu hết chuỗi hoặc kí tự kế tiếp (không trắng) là HOA.
      final next = _nextNonSpace(text, i + 1);
      if (next == null || _isUpper(text, next)) {
        final seg = text.substring(start, i + 1).trim();
        if (seg.isNotEmpty) {
          final offsetInSlice = text.substring(start, i + 1).indexOf(seg);
          final segStart = start + offsetInSlice;
          result.add(
              Segment(text: seg, start: segStart, end: segStart + seg.length));
        }
        start = i + 1;
      }
      // Kí tự kế tiếp là chữ thường → dấu chấm này không kết thúc câu.
    }
    final tail = text.substring(start).trim();
    if (tail.isNotEmpty) {
      final offsetInSlice = text.substring(start).indexOf(tail);
      final segStart = start + offsetInSlice;
      result.add(Segment(text: tail, start: segStart, end: segStart + tail.length));
    }
    return result;
  }

  /// Tách mệnh đề từ danh sách câu: tại , ; : — trừ giữa hai chữ số.
  static List<Segment> clauses(String text) {
    final result = <Segment>[];
    for (final sentence in sentences(text)) {
      var start = sentence.start;
      for (var i = sentence.start; i < sentence.end; i++) {
        final ch = text[i];
        if (ch != ',' && ch != ';' && ch != ':') continue;
        if (_isDigitAt(text, i - 1) && _isDigitAt(text, i + 1)) continue;
        final seg = text.substring(start, i + 1).trim();
        if (seg.isNotEmpty) {
          final slice = text.substring(start, i + 1);
          final off = slice.indexOf(seg);
          result.add(Segment(
              text: seg, start: start + off, end: start + off + seg.length));
        }
        start = i + 1;
      }
      final seg = text.substring(start, sentence.end).trim();
      if (seg.isNotEmpty) {
        final slice = text.substring(start, sentence.end);
        final off = slice.indexOf(seg);
        result.add(Segment(
            text: seg, start: start + off, end: start + off + seg.length));
      }
    }
    return result;
  }

  /// Tách cụm từ: mệnh đề + cắt tại từ nối (và/hoặc/nhưng/mà/nên/vì/tuy,
  /// and/or/but/so) — từ nối thuộc cụm SAU.
  static final RegExp _conjunction = RegExp(
    r"\s(?:và|hoặc|nhưng|mà|nên|vì|tuy|and|or|but|so)\s",
    caseSensitive: false,
  );

  static List<Segment> phrases(String text) {
    final result = <Segment>[];
    for (final clause in clauses(text)) {
      var start = clause.start;
      for (final m in _conjunction.allMatches(text, clause.start)) {
        if (m.end > clause.end) break;
        final seg = text.substring(start, m.start + 1).trim();
        if (seg.isNotEmpty) {
          final slice = text.substring(start, m.start + 1);
          final off = slice.indexOf(seg);
          result.add(Segment(
              text: seg, start: start + off, end: start + off + seg.length));
        }
        start = m.start + 1;
      }
      final seg = text.substring(start, clause.end).trim();
      if (seg.isNotEmpty) {
        final slice = text.substring(start, clause.end);
        final off = slice.indexOf(seg);
        result.add(Segment(
            text: seg, start: start + off, end: start + off + seg.length));
      }
    }
    return result;
  }
}
