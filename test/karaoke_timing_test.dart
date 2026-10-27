import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/providers/player_provider.dart';
import 'package:in4up/screens/understand_mode/understand_provider.dart';
import 'package:in4up_stt/models/stt_result.dart';
import 'package:in4up_stt/stt_lrc_converter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_queue_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('inline word timestamps belong to the text after each tag', () {
    final lines = SttLrcConverter().parseLrcContent(
      '[00:01.00]one <00:02.00>two <00:04.50>three\n',
    );
    expect(lines.single.text, 'one two three');
    expect(lines.single.words.map((word) => word.word), ['one', 'two', 'three']);
    expect(lines.single.words.map((word) => word.start), [
      const Duration(seconds: 1),
      const Duration(seconds: 2),
      const Duration(milliseconds: 4500),
    ]);
  });

  test('first word timestamp and long recording minutes survive a round trip', () {
    final result = SttResult(
      fullText: 'one two',
      segments: [
        SttSegment(
          id: 0,
          uid: 'long',
          startSeconds: 6000,
          endSeconds: 6004,
          text: 'one two',
          words: const [
            SttWord(word: 'one', startSeconds: 6000.5, endSeconds: 6001),
            SttWord(word: 'two', startSeconds: 6002, endSeconds: 6003),
          ],
          avgConfidence: 1,
        ),
      ],
      engineUsed: SttEngineType.whisper,
      language: 'en',
      processingTime: Duration.zero,
      audioFingerprint: 'source',
      hasWordTimestamps: true,
    );
    final converter = SttLrcConverter();
    final line = converter.parseLrcContent(converter.generateLrcContent(result)).single;
    expect(line.timestamp, const Duration(minutes: 100));
    expect(line.words.map((word) => word.start), [
      const Duration(minutes: 100, milliseconds: 500),
      const Duration(minutes: 100, seconds: 2),
    ]);
    final edited = converter.parseLrcContent(SttLrcConverter.serializeLine(line)).single;
    expect(edited.words.map((word) => word.start), line.words.map((word) => word.start));
    expect(converter.parseLrcContent('[1:02.00]short minute').single.timestamp,
        const Duration(minutes: 1, seconds: 2));
  });

  test('word markers preserve source punctuation, spacing and edited text', () {
    final original = LrcLine(
      timestamp: const Duration(seconds: 2),
      text: '你好，世界  foo!',
      words: const [
        LrcWord(word: '你好', start: Duration(seconds: 2)),
        LrcWord(word: '世界', start: Duration(milliseconds: 3007)),
        LrcWord(word: 'foo', start: Duration(milliseconds: 4003)),
      ],
    );
    expect(SttLrcConverter.wordTimingsMatchText(original), isTrue);
    final saved = SttLrcConverter().parseLrcContent(
      SttLrcConverter.serializeLine(original),
    ).single;
    expect(saved.text, original.text);
    expect(saved.words.map((word) => word.start), original.words.map((word) => word.start));

    final edited = LrcLine(
      timestamp: original.timestamp,
      text: '再见，世界  foo!',
      words: original.words,
    );
    expect(SttLrcConverter.wordTimingsMatchText(edited), isFalse);
    final safeText = SttLrcConverter().parseLrcContent(
      SttLrcConverter.serializeLine(edited),
    ).single;
    expect(safeText.text, edited.text);
    expect(safeText.words, isEmpty);

    final result = SttResult(
      fullText: original.text,
      segments: [SttSegment(
        id: 0, uid: 'cjk', startSeconds: 2, endSeconds: 5,
        text: original.text, avgConfidence: 1,
        words: const [
          SttWord(word: '你好', startSeconds: 2, endSeconds: 3),
          SttWord(word: '世界', startSeconds: 3.007, endSeconds: 4),
          SttWord(word: 'foo', startSeconds: 4.003, endSeconds: 5),
        ],
      )],
      engineUsed: SttEngineType.whisper, language: 'zh',
      processingTime: Duration.zero, audioFingerprint: 'source', hasWordTimestamps: true,
    );
    final generated = SttLrcConverter().parseLrcContent(
      SttLrcConverter().generateLrcContent(result),
    ).single;
    expect(generated.text, original.text);
    expect(generated.words.map((word) => word.start), original.words.map((word) => word.start));
  });

  test('loading or replacing lyrics uses the last clock even while paused', () {
    final understand = UnderstandProvider();
    understand.updatePosition(const Duration(seconds: 5));
    understand.loadLrcLines([
      LrcLine(timestamp: const Duration(seconds: 10), text: 'later'),
      LrcLine(timestamp: const Duration(seconds: 2), text: 'now'),
      LrcLine(timestamp: const Duration(seconds: 2), text: 'same time'),
      LrcLine(timestamp: Duration.zero, text: 'first'),
    ]);
    expect(understand.lrcLines.map((line) => line.text),
        ['first', 'now', 'same time', 'later']);
    expect(understand.currentLineIndex, 2);
    expect(understand.currentWordIndex, greaterThanOrEqualTo(0));
    understand.updatePosition(const Duration(milliseconds: 500));
    expect(understand.currentLineIndex, 0);
    understand.loadLrcLines([
      LrcLine(timestamp: const Duration(seconds: 1), text: 'new'),
    ]);
    expect(understand.currentLineIndex, -1);
    expect(understand.currentWordIndex, -1);
    understand.clear();
    expect(understand.currentWordIndex, -1);
    understand.dispose();
  });

  test('estimated words do not cross the next line start', () {
    final understand = UnderstandProvider();
    understand.loadLrcLines([
      LrcLine(timestamp: Duration.zero, text: 'a b c d'),
      LrcLine(timestamp: const Duration(milliseconds: 150), text: 'next'),
    ]);
    expect(understand.wordsForLine(0).last.start,
        lessThan(const Duration(milliseconds: 150)));
    understand.dispose();
  });

  test('player drives lyrics without mounting either screen', () async {
    SharedPreferences.setMockInitialValues({});
    final audio = FakeQueueAudio();
    final understand = UnderstandProvider();
    final player = PlayerProvider(
      audioService: audio,
      storage: FakeQueueStorage(),
      understandProvider: understand,
      initializeSttService: false,
      loadCachedLrc: false,
      recordRecentAudio: (_) async {},
    );
    audio.position(const Duration(seconds: 7));
    await Future<void>.delayed(Duration.zero);
    understand.loadLrcLines([
      LrcLine(timestamp: const Duration(seconds: 2), text: 'first'),
      LrcLine(timestamp: const Duration(seconds: 6), text: 'second'),
    ]);
    expect(understand.currentLineIndex, 1);
    audio.position(const Duration(seconds: 3));
    await Future<void>.delayed(Duration.zero);
    expect(understand.currentLineIndex, 0);
    player.dispose();
    await Future<void>.delayed(Duration.zero);
    understand.dispose();
  });
}
