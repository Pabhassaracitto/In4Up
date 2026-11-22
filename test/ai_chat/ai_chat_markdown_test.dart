// PSRC-263 — bubble trợ lý không được lộ ký hiệu markdown thô (`**`, `*`,
// backtick, `#`, `-`). Parser THUẦN DART (không build widget) nên chạy được
// trên CI không cần thiết bị.
//
// Ngưỡng chấp nhận là "render sạch, không vỡ layout" — KHÔNG phải render
// đúng chuẩn CommonMark. Dấu lẻ/chưa đóng phải giữ nguyên glyph, không được
// biến mất mà cũng không được lộ thành `*` trơ trọi.

import 'package:flutter/painting.dart'
    show Color, FontStyle, FontWeight, TextStyle;
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/screens/ai_chat/ai_chat_markdown.dart';

void main() {
  const base = TextStyle(fontSize: 14, color: Color(0xFFFFFFFF));
  final styles = ChatMarkdownStyles.from(base);

  /// Ghép toàn bộ text của các span lại (để soi nội dung đã bóc dấu).
  String joined(List<MdSpan> spans) => spans.map((s) => s.text).join();

  /// Text của các span có style đậm.
  String boldText(List<MdSpan> spans) => spans
      .where((s) => s.style.fontWeight == FontWeight.w700)
      .map((s) => s.text)
      .join();

  group('ChatMarkdown — inline', () {
    test('in đậm **…** được bóc dấu và đánh style bold', () {
      final spans = ChatMarkdown.parse('Đây là **quan trọng** nhé.', styles);
      expect(joined(spans), 'Đây là quan trọng nhé.',
          reason: 'dấu ** phải bị bóc khỏi văn bản hiển thị');
      expect(joined(spans), isNot(contains('**')));
      expect(boldText(spans), 'quan trọng');
    });

    test('in nghiêng *…* được bóc dấu và đánh style italic', () {
      final spans = ChatMarkdown.parse('từ *này* nhấn mạnh', styles);
      expect(joined(spans), 'từ này nhấn mạnh');
      final italic = spans
          .where((s) => s.style.fontStyle == FontStyle.italic)
          .map((s) => s.text)
          .join();
      expect(italic, 'này');
    });

    test('bold-italic ***…*** được bóc sạch cả 3 dấu', () {
      final spans = ChatMarkdown.parse('x ***rất*** y', styles);
      expect(joined(spans), 'x rất y');
      expect(joined(spans), isNot(contains('*')));
    });

    test('code inline `…` giữ nguyên nội dung, không bóc markdown bên trong',
        () {
      final spans = ChatMarkdown.parse('gõ `**len**(x)` để đếm', styles);
      expect(joined(spans), 'gõ **len**(x) để đếm',
          reason: 'dấu ** nằm TRONG code phải giữ nguyên, không bị bóc');
      final code = spans
          .where((s) => s.style.fontFamily == 'monospace')
          .map((s) => s.text)
          .join();
      expect(code, '**len**(x)');
    });

    test('dấu lẻ (chưa đóng) được giữ nguyên glyph, không lộ trơ trọi', () {
      // "** không đóng" — giữ nguyên vì không có cặp đóng hợp lệ.
      final spans = ChatMarkdown.parse('tính 2 ** 3 và 5 * 4', styles);
      expect(joined(spans), 'tính 2 ** 3 và 5 * 4');
    });
  });

  group('ChatMarkdown — block-level', () {
    test('heading `# ` bị bóc dấu # và tăng kiểu', () {
      final spans = ChatMarkdown.parse('# Tiêu đề\nNội dung', styles);
      expect(joined(spans), 'Tiêu đề\nNội dung');
      expect(joined(spans), isNot(contains('#')));
      final heading = spans.firstWhere((s) => s.text == 'Tiêu đề');
      expect(heading.style.fontWeight, FontWeight.w700);
      expect(heading.style.fontSize, greaterThan(base.fontSize!));
    });

    test('gạch đầu dòng `- ` đổi thành bullet •', () {
      final spans = ChatMarkdown.parse('- mục một\n- mục hai', styles);
      expect(joined(spans), '• mục một\n• mục hai');
      expect(joined(spans), isNot(startsWith('-')));
    });

    test('đánh số `1. ` giữ nguyên số, không bị bóc nhầm', () {
      final spans = ChatMarkdown.parse('1. bước một\n2. bước hai', styles);
      expect(joined(spans), '1. bước một\n2. bước hai');
    });

    test('code fence ``` bị bỏ marker, giữ nội dung code', () {
      final spans = ChatMarkdown.parse('trước\n```\nint x = 1;\n```\nsau', styles);
      final text = joined(spans);
      expect(text, contains('int x = 1;'));
      expect(text, isNot(contains('```')));
      expect(text, contains('trước'));
      expect(text, contains('sau'));
    });
  });

  group('ChatMarkdown — câu trả lời thực tế của model', () {
    test('ví dụ markdown hỗn hợp render sạch, không còn ** trơ trọi', () {
      const reply = '**Ý chính:**\n'
          '- Từ `abandon` nghĩa là *bỏ rơi*.\n'
          '- Cấu trúc **S + V + O**.\n\n'
          'Bạn có muốn ví dụ thêm không?';
      final text = joined(ChatMarkdown.parse(reply, styles));
      expect(text, isNot(contains('**')));
      expect(text, contains('Ý chính:'));
      expect(text, contains('abandon'));
      expect(text, contains('• '));
    });
  });
}
