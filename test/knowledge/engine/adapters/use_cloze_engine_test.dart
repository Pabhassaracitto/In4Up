import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/knowledge/engine/adapters/use_cloze_engine.dart';

void main() {
  group('UseClozeEngine — cloze điền dạng', () {
    test('đúng đáp án → isCorrect', () {
      final item = ClozeItem(
        sentence: 'I have two ___.',
        answer: 'cats',
        formType: 'plural',
      );
      final r = UseClozeEngine.check(item: item, userAnswer: 'cats');
      expect(r.isCorrect, isTrue);
    });

    test('sai đáp án → isCorrect false', () {
      final item = ClozeItem(
        sentence: 'I have two ___.',
        answer: 'cats',
        formType: 'plural',
      );
      final r = UseClozeEngine.check(item: item, userAnswer: 'dogs');
      expect(r.isCorrect, isFalse);
    });

    test('normalize: case + dấu không ảnh hưởng', () {
      final item = ClozeItem(
        sentence: 'I have two ___.',
        answer: 'cats',
        formType: 'plural',
      );
      final r = UseClozeEngine.check(item: item, userAnswer: 'Cats');
      expect(r.isCorrect, isTrue);
    });

    test('filled sentence', () {
      final item = ClozeItem(
        sentence: 'I have two ___.',
        answer: 'cats',
        formType: 'plural',
      );
      expect(item.filled, 'I have two cats.');
    });

    test('createItem', () {
      final item = UseClozeEngine.createItem(
        word: 'cats',
        template: 'I have two ___.',
        formType: 'plural',
      );
      expect(item.answer, 'cats');
      expect(item.sentence, 'I have two ___.');
    });
  });
}
