// PSRC-234 — tab Đọc, dòng KHÔNG bật "box từng từ".
//
// Triệu chứng (owner): chạm một từ không đọc từ, không mở từ điển; chạm đúp
// không đọc nguyên dòng. Nguyên nhân: dòng không box được vẽ bằng
// `SelectableText` / `SelectableText.rich` ⇒ cử chỉ chỉ có "khoảng đã chọn",
// chạm một lần chỉ đặt con trỏ nên không có phản ứng nào, và không có chỗ nào
// bắt chạm đúp.
//
// Test này giữ hai thứ khỏi bị lùi:
//   1. PHẦN THUẦN LOGIC — đổi "chỉ số ký tự" thành "từ" (kể cả từ lặp lại) và
//      phân biệt chạm một lần / chạm đúp. Không cần dựng widget tree nên chạy
//      được ở sandbox không có Flutter SDK; máy bắt thật là CI (`flutter test`).
//   2. SOURCE-SCAN — dòng không box phải đi qua `WordTapPlainText` và giữ đủ
//      ba thao tác (chạm từ / chạm đúp / giữ-kéo chọn nhiều từ).
import 'dart:io';
import 'dart:ui' show Offset;

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/screens/read_mode/services/line_word_hit.dart';

void main() {
  group('buildLineWordSpans — ghép từ vào chỉ số ký tự của dòng', () {
    test('ba từ liền nhau', () {
      final spans = buildLineWordSpans(
        content: 'The cat sat',
        words: const ['The', 'cat', 'sat'],
      );
      expect(spans.length, 3);
      expect(spans[0].wordIndex, 0);
      expect([spans[0].start, spans[0].end], [0, 3]);
      expect([spans[1].start, spans[1].end], [4, 7]);
      expect([spans[2].start, spans[2].end], [8, 11]);
    });

    test('từ LẶP LẠI trong dòng lấy đúng vị trí xuất hiện của nó', () {
      final spans = buildLineWordSpans(
        content: 'the cat the dog',
        words: const ['the', 'cat', 'the', 'dog'],
      );
      expect(spans.length, 4);
      expect([spans[0].start, spans[0].end], [0, 3]);
      expect([spans[2].start, spans[2].end], [8, 11],
          reason: 'từ "the" thứ hai phải chỉ vào chỗ thứ hai, không quay về 0');
    });

    test('từ không có trong dòng bị bỏ qua (không tạo span rỗng ở gốc)', () {
      final spans = buildLineWordSpans(
        content: 'the cat',
        words: const ['the', 'xyz', 'cat'],
      );
      expect(spans.map((s) => s.wordIndex).toList(), <int>[0, 2]);
      expect(spans.every((s) => s.length > 0), isTrue);
    });

    test('dòng rỗng / chưa phân tích từ ⇒ không có span', () {
      expect(buildLineWordSpans(content: '', words: const ['a']), isEmpty);
      expect(buildLineWordSpans(content: 'abc', words: const []), isEmpty);
    });
  });

  group('wordIndexAtCharOffset — chạm vào đâu thì ra từ đó', () {
    final spans = buildLineWordSpans(
      content: 'The cat sat',
      words: const ['The', 'cat', 'sat'],
    );

    test('giữa từ ⇒ đúng từ ấy', () {
      expect(wordIndexAtCharOffset(spans: spans, charOffset: 1), 0);
      expect(wordIndexAtCharOffset(spans: spans, charOffset: 5), 1);
      expect(wordIndexAtCharOffset(spans: spans, charOffset: 9), 2);
    });

    test('RenderParagraph trả vị trí CHÈN ⇒ chạm nửa phải ký tự cuối vẫn ăn',
        () {
      expect(wordIndexAtCharOffset(spans: spans, charOffset: 3), 0,
          reason: 'offset == end của "The" phải là từ "The"');
      expect(wordIndexAtCharOffset(spans: spans, charOffset: 7), 1);
    });

    test('rơi vào khoảng trắng giữa hai từ ⇒ lấy từ gần nhất (không "câm")',
        () {
      // "The   cat": ký tự 3..5 là khoảng trắng; 4 và 5 gần "cat" hơn "The".
      final wide = buildLineWordSpans(
        content: 'The   cat',
        words: const ['The', 'cat'],
      );
      expect(wordIndexAtCharOffset(spans: wide, charOffset: 4), 0,
          reason: 'gần "The" hơn (1 ký tự so với 2 của "cat")');
      expect(wordIndexAtCharOffset(spans: wide, charOffset: 5), 1,
          reason: 'gần "cat" hơn (1 ký tự so với 2 của "The")');
      expect(wordIndexAtCharOffset(spans: wide, charOffset: 3), 0,
          reason: 'đầu mút của "The" vẫn là "The"');
    });

    test('ngoài hai đầu dòng ⇒ vẫn trả từ gần nhất', () {
      expect(wordIndexAtCharOffset(spans: spans, charOffset: -5), 0);
      expect(wordIndexAtCharOffset(spans: spans, charOffset: 999), 2);
    });

    test('dòng chưa ghép được từ ⇒ null', () {
      expect(wordIndexAtCharOffset(spans: const [], charOffset: 4), isNull);
    });
  });

  group('lineWordSpanFor', () {
    test('lấy đúng span theo chỉ số từ trong analyzedWords', () {
      final spans = buildLineWordSpans(
        content: 'the cat',
        words: const ['the', 'xyz', 'cat'],
      );
      expect(lineWordSpanFor(spans: spans, wordIndex: 2)?.start, 4);
      expect(lineWordSpanFor(spans: spans, wordIndex: 1), isNull,
          reason: 'từ không ghép được vào dòng thì không có hình chữ nhật');
    });
  });

  group('LineTapClassifier — chạm một lần vs chạm đúp', () {
    final t0 = DateTime(2026, 11, 15, 9, 0, 0);

    test('hai cú chạm nhanh cùng chỗ ⇒ cú thứ hai là chạm đúp', () {
      final classifier = LineTapClassifier();
      expect(
        classifier.registerTap(
            position: const Offset(10, 10), at: t0),
        isFalse,
      );
      expect(
        classifier.registerTap(
          position: const Offset(12, 11),
          at: t0.add(const Duration(milliseconds: 120)),
        ),
        isTrue,
      );
    });

    test('quá thời gian ⇒ hai lần chạm rời', () {
      final classifier = LineTapClassifier();
      classifier.registerTap(position: const Offset(10, 10), at: t0);
      expect(
        classifier.registerTap(
          position: const Offset(10, 10),
          at: t0.add(const Duration(milliseconds: 400)),
        ),
        isFalse,
      );
    });

    test('cùng lúc nhưng chạm HAI TỪ KHÁC NHAU ⇒ không phải chạm đúp', () {
      final classifier = LineTapClassifier();
      classifier.registerTap(position: const Offset(10, 10), at: t0);
      expect(
        classifier.registerTap(
          position: const Offset(90, 10),
          at: t0.add(const Duration(milliseconds: 100)),
        ),
        isFalse,
      );
    });

    test('chạm đúp xong thì cú thứ ba lại là chạm một lần', () {
      final classifier = LineTapClassifier();
      classifier.registerTap(position: const Offset(10, 10), at: t0);
      classifier.registerTap(
        position: const Offset(10, 10),
        at: t0.add(const Duration(milliseconds: 100)),
      );
      expect(
        classifier.registerTap(
          position: const Offset(10, 10),
          at: t0.add(const Duration(milliseconds: 150)),
        ),
        isFalse,
      );
    });

    test('reset() quên cú chạm trước (dòng đổi nội dung)', () {
      final classifier = LineTapClassifier();
      classifier.registerTap(position: const Offset(10, 10), at: t0);
      classifier.reset();
      expect(
        classifier.registerTap(
          position: const Offset(10, 10),
          at: t0.add(const Duration(milliseconds: 100)),
        ),
        isFalse,
      );
    });
  });

  group('PSRC-234 — source-scan: dòng không box phải chạm được từng từ', () {
    final lineWidget =
        File('lib/screens/read_mode/widgets/text_line_widget.dart')
            .readAsStringSync();
    final widget = File(
            'lib/screens/read_mode/widgets/word_tap_plain_text.dart')
        .readAsStringSync();
    final hit = File('lib/screens/read_mode/services/line_word_hit.dart')
        .readAsStringSync();

    test('dòng đã phân tích từ ⇒ vẽ bằng WordTapPlainText (không SelectableText.rich)',
        () {
      expect(lineWidget.contains('WordTapPlainText('), isTrue);
      expect(lineWidget.contains('_usesWordTapPlainText'), isTrue);
      expect(
        lineWidget.contains('SelectableText.rich('),
        isFalse,
        reason: 'đường "chỉ đặt con trỏ" chính là nguyên nhân PSRC-234',
      );
    });

    test('chế độ ô từng từ vẫn do ColoredTextWidget lo (không đổi)', () {
      expect(lineWidget.contains('ColoredTextWidget('), isTrue);
      expect(lineWidget.contains('usesWordBoxes'), isTrue);
      expect(lineWidget.contains('data.wordTapBoxes'), isTrue);
    });

    test('chạm một từ ⇒ đọc từ + mở pop tra nhanh (giống khi có box)', () {
      expect(widget.contains('getPositionForOffset'), isTrue,
          reason: 'phải đổi toạ độ chạm sang chỉ số ký tự của RichText');
      expect(widget.contains('wordIndexAtCharOffset('), isTrue);
      expect(widget.contains('tp.speak(widget.words[wordIndex].word)'), isTrue);
      expect(widget.contains('WordMiniPop.show('), isTrue);
      expect(widget.contains('anchorRect: _wordRect(wordIndex)'), isTrue,
          reason: 'pop phải trồi lên cạnh đúng từ vừa chạm');
    });

    test('chạm đúp ⇒ đọc nguyên dòng + dịch nguyên câu + popup dịch', () {
      expect(widget.contains('_handleLineDoubleTap'), isTrue);
      expect(widget.contains('LineTapClassifier'), isTrue);
      expect(widget.contains('tp.speak(widget.content'), isTrue,
          reason: 'chạm đúp phải đọc cả dòng, không chỉ một từ');
      expect(widget.contains('ReadTextActionRunner.run('), isTrue);
      expect(widget.contains('ReadTextAction.translate'), isTrue);
      expect(widget.contains('selectedText: widget.content'), isTrue);
      expect(
        widget.contains('onDoubleTap:'),
        isFalse,
        reason: 'onDoubleTap của GestureDetector giữ arena ~300 ms ⇒ chạm một '
            'từ bị trễ; dùng LineTapClassifier để chạm một lần chạy ngay',
      );
    });

    test('giữ rồi kéo ⇒ chọn nhiều từ như cũ (READ-SELECT-002)', () {
      expect(widget.contains('resolveWordRange('), isTrue);
      expect(widget.contains('onLongPressStart'), isTrue);
      expect(widget.contains('onLongPressMoveUpdate'), isTrue);
      expect(widget.contains('FloatingTextActions.show('), isTrue,
          reason: 'thanh hành động phải là thanh sẵn có của việc bôi chọn');
      expect(widget.contains('selectTextWithOffsets('), isTrue,
          reason: 'vùng chọn phải vào TextProvider như một selection thật');
      expect(widget.contains('WordSelectionState.activate('), isTrue);
    });

    test('luật ghép từ nằm ở service thuần (test được, không cần widget tree)',
        () {
      expect(hit.contains('List<LineWordSpan> buildLineWordSpans('), isTrue);
      expect(hit.contains('int? wordIndexAtCharOffset('), isTrue);
      expect(hit.contains('class LineTapClassifier'), isTrue);
    });

    test('bảo toàn cỡ chữ hệ thống (RichText không tự nhân như SelectableText)',
        () {
      expect(widget.contains('MediaQuery.textScalerOf(context)'), isTrue);
    });
  });
}
