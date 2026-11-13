import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/shadowing/models/phoneme_models.dart';
import 'package:in4up/features/shadowing/services/pronunciation_service.dart';
import 'package:in4up/features/shadowing/services/shadowing_text_scorer.dart';

void main() {
  group('PSRC-227 pure coverage table', () {
    const cases = <({String name, String original, String recognized, double expected})>[
      (name: 'exact', original: 'Hello, WORLD!', recognized: 'hello world', expected: 1),
      (name: 'half missing', original: 'one two three four', recognized: 'one two', expected: 0.5),
      (name: 'wrong completely', original: 'alpha beta gamma delta', recognized: 'red blue green black', expected: 0),
      (name: 'extra words', original: 'one two', recognized: 'one two three four', expected: 0.5),
      (name: 'empty transcript', original: 'one two three', recognized: '', expected: 0),
      (name: 'repeated words need coverage', original: 'ha ha ha', recognized: 'ha', expected: 1 / 3),
      (name: 'English digits to words', original: 'I have 2 apples', recognized: 'I have two apples', expected: 1),
      (name: 'Vietnamese digits to words', original: 'Tôi có 2 con mèo', recognized: 'Tôi có hai con mèo', expected: 1),
      (name: 'NFC composed vs decomposed', original: 'Tiếng Việt', recognized: 'Tiếng Việt', expected: 1),
    ];
    for (final c in cases) {
      test(c.name, () {
        final score = ShadowingTextScorer.score(c.original, c.recognized);
        expect(score.score, closeTo(c.expected, 1e-9));
      });
    }

    test('accented Vietnamese is better than unaccented, but tones still matter', () {
      const original = 'Tôi là học sinh.';
      final exact = ShadowingTextScorer.score(original, 'Tôi là học sinh.');
      final unaccented = ShadowingTextScorer.score(original, 'Toi la hoc sinh');
      final wrong = ShadowingTextScorer.score(original, 'xyz abc def ghi');
      expect(exact.score, 1);
      expect(unaccented.score, lessThan(exact.score));
      expect(unaccented.score, greaterThan(0.5));
      expect(wrong.score, 0);
      expect(exact.score, greaterThan(unaccented.score));
      expect(unaccented.score, greaterThan(wrong.score));
    });

    test('word order is not treated as a bag of words', () {
      final ordered = ShadowingTextScorer.score('one two three', 'one two three');
      final reversed = ShadowingTextScorer.score('one two three', 'three two one');
      expect(ordered.score, 1);
      expect(reversed.score, lessThan(ordered.score));
    });

    test('NFC composition handles uppercase Latin decomposed input', () {
      expect(ShadowingTextScorer.composeNfc('A\u0300'), 'À');
      expect(ShadowingTextScorer.composeNfc('e\u0302\u0301'), 'ế');
    });
  });

  group('PSRC-227 result wiring', () {
    test('missing words lower both tab results and never say nearly perfect', () {
      final result = PronunciationService.analyze(
        originalText: 'one two three four',
        recognizedText: 'one two',
        originalWaveform: const [0.2, 0.4, 0.6],
        userWaveform: const [0.2, 0.4, 0.6],
      );
      expect(result.overallScore, closeTo(0.5, 1e-9));
      expect(result.correctWordCount, 2);
      expect(result.totalWordCount, 4);
      expect(result.wordResults.where((w) => w.status == WordStatus.missed), hasLength(2));
      expect(result.feedbackMessage, isNot(contains('perfect')));
      expect(result.feedbackMessage, 'Một số từ bị thiếu hoặc đọc sai. Hãy luyện tiếp!');
    });

    test('extra words are penalized even when every reference word is present', () {
      final result = PronunciationService.analyze(
        originalText: 'one two',
        recognizedText: 'one two three four',
      );
      expect(result.extraWordCount, 2);
      expect(result.correctWordCount, 2);
      expect(result.overallScore, closeTo(0.5, 1e-9));
      expect(result.feedbackMessage, 'Bạn đọc thừa từ so với câu mẫu. Hãy luyện tiếp!');
    });

    test('acoustic similarity cannot inflate a low-coverage transcript', () {
      final result = PronunciationService.analyze(
        originalText: 'one two three four',
        recognizedText: 'one two',
        originalWaveform: const [1, 1, 1],
        userWaveform: const [1, 1, 1],
      );
      expect(result.acousticAnalysis, isNotNull);
      expect(result.overallScore, lessThanOrEqualTo(0.5));
    });

    test('scoring is deterministic (no random phoneme scores)', () {
      final a = PronunciationService.analyze(originalText: 'hello world', recognizedText: 'hello world');
      final b = PronunciationService.analyze(originalText: 'hello world', recognizedText: 'hello world');
      expect(a.overallScore, b.overallScore);
      expect(a.toJson()['wordBreakdown'], b.toJson()['wordBreakdown']);
    });

    test('failed STT is not replaced by the reference sentence', () {
      final stt = File('lib/features/shadowing/services/offline_stt_service.dart').readAsStringSync();
      final provider = File('lib/features/shadowing/providers/shadowing_provider.dart').readAsStringSync();
      expect(stt, isNot(contains('return originalText')));
      expect(stt, contains('Future<String?> transcribe'));
      expect(provider, isNot(contains('hello world')));
      expect(provider, contains("recognizedText == null || recognizedText.trim().isEmpty"));
      expect(provider, contains("_analysisError = 'no_speech'"));
    });
  });
}
