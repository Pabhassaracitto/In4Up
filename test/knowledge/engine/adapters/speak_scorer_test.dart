import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/knowledge/engine/adapters/speak_scorer.dart';

void main() {
  group('SpeakScorer — phát âm 1 từ', () {
    test('đúng hoàn toàn → score 1.0', () {
      final r = SpeakScorer.score(word: 'apple', recognizedText: 'apple');
      expect(r.score, closeTo(1.0, 1e-10));
      expect(r.isCorrect, isTrue);
    });

    test('sai hoàn toàn → score thấp', () {
      final r = SpeakScorer.score(word: 'apple', recognizedText: 'xyz');
      expect(r.score, lessThan(0.6));
      expect(r.isCorrect, isFalse);
    });

    test('partial: gần đúng → score trung bình', () {
      // Jaro-Winkler cho 'apple' vs 'aple' → cao
      final r = SpeakScorer.score(word: 'apple', recognizedText: 'aple');
      expect(r.score, greaterThan(0.5));
    });

    test('q mapping: score >= 0.6 → isCorrect (q >= 3)', () {
      // scoreNor = q/5, q >= 3 → scoreNor >= 0.6 → isCorrect
      final r = SpeakScorer.score(word: 'cat', recognizedText: 'cat');
      expect(r.isCorrect, isTrue, reason: 'đúng → scoreNor >= 0.6');
    });
  });
}
