// PLAN-043 mục 2 — test LOGIC THUẦN của "Worklist đọc từ + nghĩa".
// `WordlistPlaybackService` chỉ phát theo chuỗi bước hàm thuần dựng, nên
// test ở đây pin hành vi nghe được: thứ tự, số lần lặp từng phía, khoảng
// lặng gợi nhớ, mục thiếu nghĩa, và persist cài đặt.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/screens/tools/word_list/wordlist_read_sequence.dart';

const _lines = [
  WordlistReadLine(word: 'dog', meaning: 'con chó'),
  WordlistReadLine(word: 'cat', meaning: 'con mèo'),
  WordlistReadLine(word: 'orphan', meaning: ''),
];

List<WordlistReadStep> _seq(WordlistReadSettings s) =>
    buildWordlistReadSequence(lines: _lines, settings: s);

void main() {
  group('mặc định owner chốt: Từ ×2 → Nghĩa ×1', () {
    final steps = _seq(const WordlistReadSettings());

    test('thứ tự + phía đúng; mục thiếu nghĩa chỉ đọc từ', () {
      expect(steps.map((s) => s.text).toList(), [
        'dog', 'dog', 'con chó',
        'cat', 'cat', 'con mèo',
        'orphan', 'orphan',
      ]);
      expect(steps.map((s) => s.isMeaning).toList(), [
        false, false, true,
        false, false, true,
        false, false,
      ]);
      expect(steps.map((s) => s.line).toList(), [0, 0, 0, 1, 1, 1, 2, 2]);
    });

    test('repeatNumber đếm trong từng phía (1-based, đặt lại mỗi phía)', () {
      expect(steps.map((s) => s.repeatNumber).toList(),
          [1, 2, 1, 1, 2, 1, 1, 2]);
    });

    test('khoảng nghỉ: đầu mục = 0, giữa 2 lần cùng phía = gapRepeats, đổi phía = gapSides', () {
      expect(steps.map((s) => s.pauseBeforeMs).toList(),
          [0, 350, 700, 0, 350, 700, 0, 350]);
    });
  });

  test('wordOnly: bỏ hẳn phía nghĩa dù meaningRepeats > 0', () {
    final steps = _seq(const WordlistReadSettings(
        mode: WordlistReadMode.wordOnly, wordRepeats: 1, meaningRepeats: 3));
    expect(steps.map((s) => s.text).toList(), ['dog', 'cat', 'orphan']);
    expect(steps.every((s) => !s.isMeaning), isTrue);
  });

  test('meaningOnly: chỉ nghĩa; mục thiếu nghĩa đọc TỪ thay (không im lặng)', () {
    final steps = _seq(const WordlistReadSettings(
        mode: WordlistReadMode.meaningOnly, meaningRepeats: 2));
    expect(steps.map((s) => s.text).toList(),
        ['con chó', 'con chó', 'con mèo', 'con mèo', 'orphan']);
    expect(steps.last.isMeaning, isFalse);
  });

  test('meaningThenWord: đảo thứ tự hai phía', () {
    final steps = _seq(const WordlistReadSettings(
        mode: WordlistReadMode.meaningThenWord,
        wordRepeats: 1,
        meaningRepeats: 1));
    expect(steps.map((s) => s.text).toList(),
        ['con chó', 'dog', 'con mèo', 'cat', 'orphan']);
  });

  test('recall: nghĩa trước, bước TỪ đầu tiên mang khoảng lặng gợi nhớ đầy đủ', () {
    final steps = _seq(const WordlistReadSettings(
      mode: WordlistReadMode.recall,
      wordRepeats: 1,
      meaningRepeats: 1,
      gapBetweenSidesMs: 3000,
    ));
    expect(steps.map((s) => s.text).toList(),
        ['con chó', 'dog', 'con mèo', 'cat', 'orphan']);
    // Bước 'dog'/'cat' phải chờ 3000ms (tự nhớ), không phải nghỉ thường.
    expect(steps[1].pauseBeforeMs, 3000);
    expect(steps[3].pauseBeforeMs, 3000);
    expect(steps[0].pauseBeforeMs, 0);
  });

  test('cài đặt cực đoan: cả hai phía 0 lần ⇒ vẫn đọc từ 1 lần', () {
    final steps = _seq(const WordlistReadSettings(
        wordRepeats: 0, meaningRepeats: 0));
    expect(steps.map((s) => s.text).toList(), ['dog', 'cat', 'orphan']);
  });

  test('số lần lặp bị kẹp 0–5', () {
    final steps = _seq(const WordlistReadSettings(
        mode: WordlistReadMode.wordOnly, wordRepeats: 99));
    expect(steps.where((s) => s.line == 0).length, 5);
  });

  test('mục word rỗng bị bỏ hoàn toàn', () {
    final steps = buildWordlistReadSequence(
      lines: const [
        WordlistReadLine(word: '  ', meaning: 'nghĩa mồ côi'),
        WordlistReadLine(word: 'bird', meaning: 'chim'),
      ],
      settings: const WordlistReadSettings(),
    );
    expect(steps.every((s) => s.line == 1), isTrue);
    expect(steps, isNotEmpty);
  });

  group('persist cài đặt (toJson/fromJson)', () {
    test('round-trip giữ nguyên giá trị', () {
      const s = WordlistReadSettings(
        mode: WordlistReadMode.recall,
        wordRepeats: 3,
        meaningRepeats: 2,
        gapBetweenSidesMs: 2500,
        gapBetweenRepeatsMs: 400,
        gapBetweenWordsMs: 900,
        meaningLanguage: 'vi',
      );
      final back = WordlistReadSettings.fromJson(s.toJson());
      expect(back.mode, s.mode);
      expect(back.wordRepeats, 3);
      expect(back.meaningRepeats, 2);
      expect(back.gapBetweenSidesMs, 2500);
      expect(back.gapBetweenWordsMs, 900);
      expect(back.meaningLanguage, 'vi');
    });

    test('JSON rỗng/lạ rơi về mặc định từng trường, không ném', () {
      final back = WordlistReadSettings.fromJson(
          {'mode': 'không-có-mode-này', 'wordRepeats': 'hai'});
      expect(back.mode, WordlistReadMode.wordThenMeaning);
      expect(back.wordRepeats, 2);
      expect(back.meaningLanguage, 'auto');
    });
  });
}
