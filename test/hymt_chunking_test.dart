import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/translation/engines/hymt_chunking.dart';

void main() {
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
