// READ-SELECT-002 — chọn nhiều từ ở chế độ ô chữ của tab Đọc.
//
// Audit 0.10.3 mục 1.e: "chọn nhiều từ thường thất bại — chạm thì phát âm, giữ
// thì ra việc khác". Ở chế độ ô chữ, mỗi từ là một GestureDetector riêng và
// KHÔNG có SelectableText ⇒ không thể bôi chọn. Cách chữa: giữ một từ = mỏ
// neo, kéo ngang hoặc chạm từ thứ hai = mở rộng vùng chọn.
//
// Test này khoá phần THUẦN LOGIC (không dựng widget tree): gộp khoảng chọn
// thành chuỗi + offset để (a) `ReadTextActionRunner` xử lý đúng đoạn đã chọn và
// (b) `TextProvider.selectTextWithOffsets` có đúng vị trí trong dòng.

import 'dart:ui' show Offset, Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/models/word_analysis.dart';
import 'package:in4up/screens/read_mode/services/word_range_selection.dart';

List<AnalyzedWord> wordsOf(List<String> values) =>
    [for (final v in values) AnalyzedWord(word: v)];

void main() {
  group('resolveWordRange — mỏ neo ↔ đầu kéo', () {
    test('chưa có mỏ neo (chưa giữ từ nào) ⇒ không có vùng chọn', () {
      expect(resolveWordRange(anchorIndex: null, focusIndex: 3, wordCount: 8),
          isNull);
      expect(resolveWordRange(anchorIndex: -1, focusIndex: 3, wordCount: 8),
          isNull);
      expect(resolveWordRange(anchorIndex: 8, focusIndex: 3, wordCount: 8),
          isNull);
      expect(resolveWordRange(anchorIndex: 0, focusIndex: 0, wordCount: 0),
          isNull);
    });

    test('giữ một từ ⇒ vùng chọn đúng một từ (anchor = focus = từ đó)', () {
      final range = resolveWordRange(anchorIndex: 2, focusIndex: null, wordCount: 5)!;
      expect(range.start, 2);
      expect(range.end, 2);
      expect(range.length, 1);
      expect(range.anchorIndex, 2);
      expect(range.contains(2), isTrue);
      expect(range.contains(1), isFalse);
    });

    test('mở rộng sang phải rồi kéo NGƯỢC qua mỏ neo vẫn ra đúng khoảng', () {
      final anchor = resolveWordRange(anchorIndex: 3, focusIndex: 3, wordCount: 9)!;
      final right = anchor.extendTo(6);
      expect([right.start, right.end], [3, 6]);
      expect(right.anchorIndex, 3, reason: 'mỏ neo không đổi khi kéo');

      final left = anchor.extendTo(1);
      expect([left.start, left.end], [1, 3]);
      expect(left.length, 3);
      expect(left.contains(0), isFalse);
      expect(left.contains(1), isTrue);
      expect(left.contains(4), isFalse);
    });

    test('đầu kéo vượt quá biên ⇒ kẹp vào từ đầu/cuối', () {
      final range = resolveWordRange(anchorIndex: 2, focusIndex: 99, wordCount: 5)!;
      expect([range.start, range.end], [2, 4]);
      // Kẹp biên là việc của resolveWordRange (widget luôn gọi qua đó);
      // extendTo chỉ là phép dời đầu kéo.
      final back =
          resolveWordRange(anchorIndex: 2, focusIndex: -5, wordCount: 5)!;
      expect([back.start, back.end], [0, 2]);
    });
  });

  group('buildWordSelectionText — chuỗi ghép + offset trong dòng', () {
    const line = 'Hôm nay trời rất đẹp, bạn nhé!';
    final words = wordsOf(['Hôm', 'nay', 'trời', 'rất', 'đẹp', 'bạn', 'nhé']);

    test('chọn 5 từ liên tiếp (mỏ neo → kéo) ⇒ đúng chuỗi + offset', () {
      final range = resolveWordRange(anchorIndex: 0, focusIndex: 4, wordCount: words.length)!;
      final selection = buildWordSelectionText(
        words: words,
        start: range.start,
        end: range.end,
        lineContent: line,
      )!;
      expect(selection.text, 'Hôm nay trời rất đẹp');
      expect(line.substring(selection.startOffset, selection.endOffset),
          'Hôm nay trời rất đẹp');
    });

    test('chọn giữa dòng ⇒ offset trỏ đúng vào cụm đó, không phải đầu dòng', () {
      final range = resolveWordRange(anchorIndex: 5, focusIndex: 6, wordCount: words.length)!;
      final selection = buildWordSelectionText(
        words: words,
        start: range.start,
        end: range.end,
        lineContent: line,
      )!;
      expect(selection.text, 'bạn nhé');
      expect(selection.startOffset, line.indexOf('bạn'));
      expect(
        selection.endOffset,
        line.indexOf('bạn') + 'bạn nhé'.length,
      );
    });

    test('các từ nối bằng ĐÚNG một dấu cách (kể cả khi dòng có dấu câu)', () {
      final selection = buildWordSelectionText(
        words: words,
        start: 2,
        end: 4,
        lineContent: line,
      )!;
      expect(selection.text, 'trời rất đẹp');
      expect(selection.text.contains('  '), isFalse);
    });

    test('khoảng chọn không hợp lệ ⇒ null (widget không ghi selection rác)', () {
      expect(
        buildWordSelectionText(words: words, start: -1, end: 2, lineContent: line),
        isNull,
      );
      expect(
        buildWordSelectionText(words: words, start: 3, end: 2, lineContent: line),
        isNull,
      );
      expect(
        buildWordSelectionText(words: words, start: 0, end: 99, lineContent: line),
        isNull,
      );
      expect(
        buildWordSelectionText(
            words: const [], start: 0, end: 0, lineContent: line),
        isNull,
      );
    });

    test('không tìm thấy từ trong dòng ⇒ vẫn có offset hợp lệ để lưu vùng chọn',
        () {
      // Dòng đã bị sửa nhưng widget còn giữ danh sách từ cũ: thà lùi về đầu
      // dòng còn hơn ghi offset âm/ngoài phạm vi.
      final selection = buildWordSelectionText(
        words: wordsOf(['Xin', 'chào']),
        start: 0,
        end: 1,
        lineContent: line,
      )!;
      expect(selection.text, 'Xin chào');
      expect(selection.startOffset, 0);
      expect(selection.endOffset, 'Xin chào'.length);
      expect(selection.endOffset, greaterThan(selection.startOffset));
    });
  });

  group('wordIndexAtPoint — kéo thì biết đang ở từ nào', () {
    final boxes = <Rect?>[
      const Rect.fromLTWH(0, 0, 40, 20),
      const Rect.fromLTWH(45, 0, 40, 20),
      const Rect.fromLTWH(90, 0, 40, 20),
    ];

    test('con trỏ nằm trong ô ⇒ đúng từ đó', () {
      expect(wordIndexAtPoint(boxes: boxes, point: const Offset(10, 10)), 0);
      expect(wordIndexAtPoint(boxes: boxes, point: const Offset(60, 10)), 1);
      expect(wordIndexAtPoint(boxes: boxes, point: const Offset(100, 5)), 2);
    });

    test('con trỏ ở giữa hai ô ⇒ lấy từ gần nhất (mở rộng liên tục)', () {
      // Khe giữa ô 0 (0..40) và ô 1 (45..85): 41 gần ô 0, 44 gần ô 1.
      expect(wordIndexAtPoint(boxes: boxes, point: const Offset(41, 10)), 0);
      expect(wordIndexAtPoint(boxes: boxes, point: const Offset(44, 10)), 1);
      // Khe giữa ô 1 (45..85) và ô 2 (90..130): 86 gần ô 1, 89 gần ô 2.
      expect(wordIndexAtPoint(boxes: boxes, point: const Offset(86, 10)), 1);
      expect(wordIndexAtPoint(boxes: boxes, point: const Offset(89, 10)), 2);
    });

    test('kéo quá mép phải/trái ⇒ vẫn bám từ ngoài cùng, không đứng im', () {
      expect(wordIndexAtPoint(boxes: boxes, point: const Offset(400, 10)), 2);
      expect(wordIndexAtPoint(boxes: boxes, point: const Offset(-50, 10)), 0);
    });

    test('ô chưa đo được (null) bị bỏ qua, không tính là ở gốc toạ độ', () {
      expect(
        wordIndexAtPoint(
          boxes: const [null, Rect.fromLTWH(200, 0, 40, 20)],
          point: const Offset(2, 2),
        ),
        1,
      );
      expect(wordIndexAtPoint(boxes: const [null], point: Offset.zero), isNull);
      expect(wordIndexAtPoint(boxes: const [], point: Offset.zero), isNull);
    });
  });

  group('WordSelectionState — chạm ra ngoài biết phải bỏ chọn', () {
    test('bật/tắt cờ dòng đang chọn', () {
      WordSelectionState.deactivate();
      expect(WordSelectionState.isActive, isFalse);
      WordSelectionState.activate(7);
      expect(WordSelectionState.isActive, isTrue);
      expect(WordSelectionState.activeLineIndex, 7);
      WordSelectionState.deactivate();
      expect(WordSelectionState.isActive, isFalse);
    });
  });
}
