import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/web_reader/services/reader_cues.dart';

void main() {
  test('long article remains complete with bounded TTS requests', () {
    final text = List.generate(500, (i) => 'Sentence $i.').join(' ');
    final cues = readerCues(text);
    expect(cues.length, 500);
    expect(cues.last.text, 'Sentence 499.');
    for (final cue in cues) {
      expect(text.substring(cue.start, cue.end), cue.text);
    }
    expect(readerCueAt(cues, text.indexOf('Sentence 250')), 250);
  });
  test('unpunctuated CJK content is bounded without losing characters', () {
    final text = List.filled(5000, '文').join();
    final cues = readerCues(text);
    expect(cues.every((cue) => cue.text.length <= 400), isTrue);
    expect(cues.map((cue) => cue.text).join(), text);
  });
}
