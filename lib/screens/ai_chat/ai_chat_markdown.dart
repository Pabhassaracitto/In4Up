// lib/screens/ai_chat/ai_chat_markdown.dart
//
// PSRC-263 — render phần trả lời của trợ lý mà KHÔNG để lộ ký hiệu markdown
// thô (`**bold**`, `*italic*`, `` `code` ``, `# heading`, `- gạch đầu dòng`).
//
// Vì sao KHÔNG thêm package `flutter_markdown`:
//   * Quyết định phạm vi của phiên này: không kéo dependency mới vào pubspec.
//   * Chat chỉ cần MỘT TẬP NHỎ markdown mà model hay sinh (in đậm, in nghiêng,
//     code inline, tiêu đề, gạch đầu dòng, đánh số, code fence). Một parser
//     đúc sẵn nhẹ là đủ, dễ test, không rủi ro overflow/selection của widget
//     markdown đầy đủ.
//
// Mục tiêu là "render sạch", không phải render đúng chuẩn CommonMark:
//   * Dấu `**`/`__`/`*`/`_`/`` ` `` còn sót (chuỗi lẻ, chưa đóng) được COI LÀ
//     văn bản thường — KHÔNG được lộ thành ký tự `*` trơ trọi. Hàm bóc dấu
//     chỉ nhận cặp mở/đóng HỢP LỆ; phần còn lại giữ nguyên glyph.
//   * Mọi thứ không nhận diện được đều rơi về văn bản thường, không vỡ layout.
//
// Thuần Dart (chỉ import TextStyle) nên test được bằng `flutter_test` không
// cần build widget.

import 'package:flutter/painting.dart'
    show Color, FontStyle, FontWeight, TextStyle;

/// Tham số kiểu dáng cho phần tử markdown, suy ra từ style cơ sở của bubble.
class ChatMarkdownStyles {
  const ChatMarkdownStyles({
    required this.base,
    required this.bold,
    required this.italic,
    required this.boldItalic,
    required this.code,
    required this.heading,
  });

  factory ChatMarkdownStyles.from(TextStyle base) {
    final bold = base.copyWith(fontWeight: FontWeight.w700);
    final italic = base.copyWith(fontStyle: FontStyle.italic);
    return ChatMarkdownStyles(
      base: base,
      bold: bold,
      italic: italic,
      boldItalic: base.copyWith(
        fontWeight: FontWeight.w700,
        fontStyle: FontStyle.italic,
      ),
      // Code inline: giữ kích thước, chỉ đổi nền + font mono nhẹ để phân biệt.
      code: base.copyWith(
        fontFamily: 'monospace',
        backgroundColor: const Color(0x33000000),
        fontSize: (base.fontSize ?? 14) * 0.94,
      ),
      heading: base.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: (base.fontSize ?? 14) * 1.12,
        height: 1.35,
      ),
    );
  }

  final TextStyle base;
  final TextStyle bold;
  final TextStyle italic;
  final TextStyle boldItalic;
  final TextStyle code;
  final TextStyle heading;
}

/// Một span văn bản + style đã giải markdown.
class MdSpan {
  const MdSpan(this.text, this.style);
  final String text;
  final TextStyle style;
}

/// Renderer markdown tối thiểu → danh sách [MdSpan] (để bubble dựng TextSpan).
class ChatMarkdown {
  const ChatMarkdown._();

  /// Tách [text] thành các [MdSpan] theo kiểu trong [styles].
  ///
  /// * Chia theo DÒNG để xử lý block-level (heading `#`, gạch đầu dòng `-`/`•`,
  ///   đánh số `1.`, code fence ```), rồi bóc inline (bold/italic/code) trong
  ///   từng dòng.
  /// * Giữ `\n` giữa các dòng trong kết quả (trừ code fence bị bỏ marker).
  static List<MdSpan> parse(String text, ChatMarkdownStyles styles) {
    final spans = <MdSpan>[];
    if (text.isEmpty) return spans;

    // Code fence đa dòng: gom nguyên khối, bỏ marker ``` và ngôn ngữ.
    final lines = text.split('\n');
    final buffer = StringBuffer();
    var inFence = false;

    void flushParagraph() {
      final chunk = buffer.toString();
      buffer.clear();
      if (chunk.isEmpty) return;
      _emitLineSpans(chunk, styles, spans);
    }

    for (var i = 0; i < lines.length; i++) {
      final raw = lines[i];
      final trimmed = raw.trimRight();
      if (trimmed.trimLeft().startsWith('```')) {
        if (inFence) {
          // Đóng fence: kết thúc khối code, không xuống dòng thừa sau marker.
          inFence = false;
        } else {
          // Mở fence: xả phần văn bản trước đó rồi bắt đầu gom code.
          flushParagraph();
          inFence = true;
        }
        continue;
      }
      if (inFence) {
        buffer.write(raw);
        buffer.write('\n');
        continue;
      }
      buffer.write(raw);
      if (i < lines.length - 1) buffer.write('\n');
    }
    // Nếu còn đang trong fence chưa đóng (model cắt giữa chừng) thì phần gom
    // được vẫn là code — cứ xả như paragraph, inline parser bỏ qua ` vì chưa
    // đóng; không sao, nội dung vẫn đọc được.
    flushParagraph();
    return spans;
  }

  /// Xử lý block-level của MỘT dòng (đã chứa `\n` nội bộ từ split giữ lại),
  /// rồi bóc inline. [chunk] có thể chứa nhiều dòng (giữ `\n`).
  static void _emitLineSpans(
    String chunk,
    ChatMarkdownStyles styles,
    List<MdSpan> out,
  ) {
    final lines = chunk.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final isLast = i == lines.length - 1;
      _emitSingleLine(line, styles, out);
      if (!isLast) out.add(MdSpan('\n', styles.base));
    }
  }

  static final RegExp _headingRe = RegExp(r'^(#{1,6})\s+(.*)$');
  static final RegExp _bulletRe = RegExp(r'^\s*([-*•·+])\s+(.*)$');
  static final RegExp _numberedRe = RegExp(r'^\s*(\d+)[.)]\s+(.*)$');

  /// Một dòng vật lý: heading / bullet / đánh số / văn bản thường.
  static void _emitSingleLine(
    String line,
    ChatMarkdownStyles styles,
    List<MdSpan> out,
  ) {
    if (line.isEmpty) return;

    final heading = _headingRe.firstMatch(line);
    if (heading != null) {
      _emitInline(heading.group(2) ?? '', styles, out,
          override: styles.heading);
      return;
    }

    final bullet = _bulletRe.firstMatch(line);
    if (bullet != null) {
      out.add(MdSpan('• ', styles.base));
      _emitInline(bullet.group(2) ?? '', styles, out);
      return;
    }

    final numbered = _numberedRe.firstMatch(line);
    if (numbered != null) {
      out.add(MdSpan('${numbered.group(1)}. ', styles.base));
      _emitInline(numbered.group(2) ?? '', styles, out);
      return;
    }

    _emitInline(line, styles, out);
  }

  /// Bóc inline bold/italic/code trong [text].
  ///
  /// Chiến lược quét TRÁI→PHẢI, ưu tiên khớp DÀI NHẤT trước (***…*** rồi
  /// **…** rồi *…*; tương tự __…__ rồi _…_). Chỉ nhận cặp mở/đóng HỢP LỆ —
  /// dấu lẻ (không đóng) được giữ NGUYÊN glyph thay vì bị xoá, nên không lộ
  /// `*` trơ trọi mà cũng không nuốt chữ.
  static void _emitInline(
    String text,
    ChatMarkdownStyles styles,
    List<MdSpan> out, {
    TextStyle? override,
  }) {
    final baseStyle = override ?? styles.base;
    var i = 0;
    final buf = StringBuffer();

    void flush() {
      if (buf.isEmpty) return;
      out.add(MdSpan(buf.toString(), baseStyle));
      buf.clear();
    }

    while (i < text.length) {
      // Inline code trước — nội dung trong `…` giữ nguyên, không bóc tiếp.
      if (text[i] == '`') {
        final end = text.indexOf('`', i + 1);
        if (end > i) {
          flush();
          out.add(MdSpan(
              text.substring(i + 1, end), _merge(baseStyle, styles.code)));
          i = end + 1;
          continue;
        }
      }
      // Bold-italic ***…*** (hoặc ___…___).
      final tri = _matchDelim(text, i, 3);
      if (tri != null) {
        flush();
        _emitInline(tri.$2, styles, out,
            override: _merge(baseStyle, styles.boldItalic));
        i = tri.$3;
        continue;
      }
      // Bold **…** / __…__.
      final dbl = _matchDelim(text, i, 2);
      if (dbl != null) {
        flush();
        _emitInline(dbl.$2, styles, out,
            override: _merge(baseStyle, styles.bold));
        i = dbl.$3;
        continue;
      }
      // Italic *…* / _…_.
      final sgl = _matchDelim(text, i, 1);
      if (sgl != null) {
        flush();
        _emitInline(sgl.$2, styles, out,
            override: _merge(baseStyle, styles.italic));
        i = sgl.$3;
        continue;
      }
      buf.write(text[i]);
      i++;
    }
    flush();
  }

  /// Thử khớp cụm dấu `*`/`_` dài [count] mở tại [i] và cụm đóng tương ứng.
  ///
  /// Trả về record `(marker, inner, nextIndex)` nếu có cặp hợp lệ và phần
  /// trong không rỗng; ngược lại null (dấu lẻ — caller giữ glyph nguyên).
  static (String, String, int)? _matchDelim(String text, int i, int count) {
    final marker = _delimAt(text, i, count);
    if (marker == null) return null;
    final start = i + count;
    final close = text.indexOf(marker, start);
    if (close < 0 || close == start) return null;
    final inner = text.substring(start, close);
    if (inner.trim().isEmpty) return null;
    return (marker, inner, close + count);
  }

  /// Chuỗi dấu (`*` hoặc `_`) độ dài [count] bắt đầu ở [i], hoặc null.
  static String? _delimAt(String text, int i, int count) {
    if (i + count > text.length) return null;
    final c = text[i];
    if (c != '*' && c != '_') return null;
    for (var k = 1; k < count; k++) {
      if (text[i + k] != c) return null;
    }
    return c * count;
  }

  /// Gộp style: giữ các thuộc tính của [overlay] (fontWeight/fontStyle/font
  /// mono) đặt chồng lên [under] (kích thước heading, màu, …).
  static TextStyle _merge(TextStyle under, TextStyle overlay) {
    return under.copyWith(
      fontWeight: overlay.fontWeight,
      fontStyle: overlay.fontStyle,
      fontFamily: overlay.fontFamily,
      backgroundColor: overlay.backgroundColor,
      fontSize: overlay.fontSize,
      height: overlay.height ?? under.height,
    );
  }
}
