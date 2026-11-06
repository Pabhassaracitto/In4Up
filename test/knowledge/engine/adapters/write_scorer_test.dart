import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/knowledge/engine/adapters/write_scorer.dart';

void main() {
  group('WriteScorer — chính tả 1 từ', () {
    test('đúng hoàn toàn → score 1.0', () {
      final r = WriteScorer.score(expected: 'apple', actual: 'apple');
      expect(r.score, closeTo(1.0, 1e-10));
      expect(r.isCorrect, isTrue);
    });

    test('sai hoàn toàn → score gần 0', () {
      final r = WriteScorer.score(expected: 'apple', actual: 'xyz');
      expect(r.score, lessThan(0.3));
      expect(r.isCorrect, isFalse);
    });

    test('sai 1 ký tự → score cao', () {
      final r = WriteScorer.score(expected: 'apple', actual: 'aple');
      expect(r.score, greaterThan(0.7), reason: 'sai 1 ký tự → vẫn cao');
      expect(r.isCorrect, isTrue);
    });

    test('normalize: case + dấu', () {
      expect(WriteScorer.normalizeWord('Apple'), 'apple');
      expect(WriteScorer.normalizeWord('Áp-ple'), 'apple');
    });

    test('missingWords + extraWords', () {
      final r = WriteScorer.score(expected: 'the cat sat', actual: 'cat sat');
      expect(r.missingWords, contains('the'));
      expect(r.extraWords, isEmpty);
    });

    test('Levenshtein distance', () {
      expect(WriteScorer.levenshteinDistance('kitten', 'sitting'), 3);
      expect(WriteScorer.levenshteinDistance('apple', 'apple'), 0);
      expect(WriteScorer.levenshteinDistance('', 'abc'), 3);
    });

    test('LCS', () {
      expect(WriteScorer.longestCommonSubsequence(
        ['the', 'cat', 'sat'], ['cat', 'sat'],
      ), 2);
    });
  });
}
