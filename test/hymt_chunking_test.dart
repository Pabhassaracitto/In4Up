import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/translation/engines/hymt_chunking.dart';

void main() {
  group('HyMtChunking.chunk', () {
    test('empty text -> no chunks', () {
      expect(HyMtChunking.chunk('', maxChars: 500), isEmpty);
    });

    test('short text is ONE chunk, untouched (no fake splitting)', () {
      const text = 'Xin chào thế giới. This is a short sentence.';
      final chunks = HyMtChunking.chunk(text, maxChars: 500);
      expect(chunks, hasLength(1));
      expect(chunks.single.text, text);
    });

    test(
      'chunks partition the original text exactly (no loss, no duplication)',
      () {
        final samples = <String>[
          'Hello world. ' * 300, // 2400 chars
          'a' * 1234, // no punctuation, no space
          'Câu một. Câu hai! Câu ba? Câu bốn…' * 20,
          ('para one line here. ' * 8) +
              '\n' +
              ('second paragraph words. ' * 8),
          'word ' * 700,
          'no spaces at all in this string' * 50,
          'Mixed. Text! Với tiếng Việt? Dấu… câu. ' * 30,
        ];
        for (final text in samples) {
          final chunks = HyMtChunking.chunk(text, maxChars: 500);
          expect(
            chunks.map((c) => c.text).join(''),
            text,
            reason: 'partition property on ${text.length} chars',
          );
          for (final c in chunks) {
            expect(c.text, isNotEmpty);
            // ≤ maxChars, ngoại lệ mảnh cuối vượt nhẹ <32 (kỹ thuật)
            expect(c.text.length, lessThanOrEqualTo(531));
          }
        }
      },
    );

    test('2000+ chars -> multiple chunks, order preserved', () {
      final text = 'The quick brown fox jumps over the lazy dog. ' * 45;
      expect(text.length, greaterThanOrEqualTo(2000));
      final chunks = HyMtChunking.chunk(text, maxChars: 500);
      expect(chunks.length, greaterThan(1));
      // Thứ tự: mỗi chunk nằm đúng vị trí trong text gốc, không trùng.
      var pos = 0;
      for (final c in chunks) {
        expect(text.indexOf(c.text, pos), pos);
        pos += c.text.length;
      }
      expect(pos, text.length);
    });

    test('sentence boundaries: non-final chunks end at sentence end', () {
      final text =
          List.generate(60, (i) => 'Sentence number $i is here.').join(' ');
      final chunks = HyMtChunking.chunk(text, maxChars: 200);
      expect(chunks.length, greaterThan(1));
      for (var i = 0; i < chunks.length - 1; i++) {
        expect(
          chunks[i].text.trimRight(),
          endsWith(RegExp(r'[.!?…:;]')),
          reason: 'chunk $i should end at a sentence boundary',
        );
      }
    });
  });
}
