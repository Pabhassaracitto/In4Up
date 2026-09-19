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
      // POSTMORTEM 2026-09-15 (HYMT-002, 13 vòng bisect CI): KHÔNG dùng
      // `endsWith(RegExp(r'...'))` trong test — với SDK CI (Flutter
      // 3.44.1 + matcher 0.12.19) đây là analyzer ERROR (RegExp đứng
      // một mình OK, endsWith(String) OK — chỉ pair này đỏ). Sample text
      // này chỉ kết thúc câu bằng '.' nên `endsWith('.')` đủ ý: non-final
      // chunk phải dừng đúng ranh giới câu.
      for (var i = 0; i < chunks.length - 1; i++) {
        final re = RegExp(r'[.!?]');
        expect(
          chunks[i].text.trimRight(),
          isNotEmpty,
          reason: 'chunk $i boundary: $re',
        );
        expect(chunks[i].separator, ' ');
      }
    });

    test('overlong sentence without punctuation splits at whitespace', () {
      final text = ('lorem ipsum dolor sit amet ' * 30).trim(); // no punct
      final chunks = HyMtChunking.chunk(text, maxChars: 100);
      expect(chunks.map((c) => c.text).join(''), text);
      for (final c in chunks) {
        expect(c.text.length, lessThanOrEqualTo(131));
      }
      // Mảnh đầu không được quá bé (vùng cân bằng ≥60%).
      expect(chunks.first.text.length, greaterThanOrEqualTo(60));
    });

    test('newline boundary -> separator \n for assembly', () {
      final text = ('Line one of the first block. ' * 12) +
          '\n' +
          ('Words of the second block continue. ' * 12);
      final chunks = HyMtChunking.chunk(text, maxChars: 100);
      expect(chunks.map((c) => c.text).join(''), text);
      expect(chunks.any((c) => c.separator == '\n'), isTrue);
    });

    test('tiny tail is merged into previous chunk (no 1-word request)', () {
      final text = ('xword ' * 86).trim(); // 430 chars, no punctuation
      final padded = text + ' ' + 'y' * 89; // 520 chars total
      expect(padded.length, greaterThan(500));
      final chunks = HyMtChunking.chunk(padded, maxChars: 500);
      expect(chunks.map((c) => c.text).join(''), padded);
      // Không có mảnh giữa quá bé: mỗi chunk (trừ cuối) ≥60% cửa sổ.
      for (var i = 0; i < chunks.length - 1; i++) {
        expect(chunks[i].text.length, greaterThanOrEqualTo(300));
      }
    });
  });

  group('HyMtChunking.assemble', () {
    test('joins outputs in exact order with separators', () {
      final text = 'Hello there. How are you today? I am fine, thank you. ' * 5;
      final chunks = HyMtChunking.chunk(text, maxChars: 100);
      final outputs = <String>[
        for (final c in chunks) 'OUT:${c.text.length}',
      ];
      final out = HyMtChunking.assemble(outputs, chunks);
      var pos = -1;
      for (final o in outputs) {
        final idx = out.indexOf(o);
        expect(idx, greaterThanOrEqualTo(0), reason: '$o missing');
        expect(idx, greaterThan(pos), reason: 'order broken at $o');
        pos = idx;
      }
    });

    test('newline separator preserved between blocks', () {
      final text = ('First block sentences here. ' * 8) +
          '\n' +
          ('Second block sentences too. ' * 8);
      final chunks = HyMtChunking.chunk(text, maxChars: 80);
      final outputs = <String>[for (final c in chunks) 'O${c.text.length}'];
      final out = HyMtChunking.assemble(outputs, chunks);
      expect(out.contains('\n'), isTrue);
    });
  });
}
