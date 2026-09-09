import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/learn_by_heart/services/anki_cloze_parser.dart';
import 'package:in4up/features/learn_by_heart/services/cloze_generator.dart';

void main() {
  group('ClozeGenerator.suggestKeywords', () {
    test('skips stopwords and prefers longer words', () {
      const text = 'Ý dẫn đầu các pháp, ý làm chủ, ý tạo nên khổ đau.';
      final keys = ClozeGenerator.suggestKeywords(text, max: 5);
      expect(keys, isNot(contains('các')));
      expect(keys.any((k) => k.toLowerCase() == 'pháp' || k.contains('pháp')),
          isTrue);
      expect(keys.length, lessThanOrEqualTo(5));
    });

    test('wordsIn keeps unicode letters', () {
      expect(
        ClozeGenerator.wordsIn('Manopubbaṅgamā dhammā'),
        ['Manopubbaṅgamā', 'dhammā'],
      );
    });
  });

  group('ClozeToken.toggleKeyword', () {
    test('marks and unmarks a word without Anki syntax', () {
      final tokens = ClozeGenerator.generate(
        text: 'Ý dẫn đầu các pháp',
        keywords: const [],
        maskRatio: 0,
      );
      final phap = tokens.firstWhere((t) => t.cleanWord.contains('pháp'));
      expect(phap.isKeyword, isFalse);
      phap.toggleKeyword();
      expect(phap.isKeyword, isTrue);
      expect(phap.isMasked, isTrue);
      expect(phap.isMaskedAtLevel(ClozeLevel.keywords), isTrue);
      phap.toggleKeyword();
      expect(phap.isKeyword, isFalse);
    });
  });

  group('AnkiClozeParser still accepts pasted cards', () {
    test('strips {{c1::}} if the user pastes Anki', () {
      const raw = 'Ý dẫn đầu các {{c1::pháp}}';
      expect(AnkiClozeParser.hasAnkiCloze(raw), isTrue);
      expect(AnkiClozeParser.stripAnkiSyntax(raw), 'Ý dẫn đầu các pháp');
    });
  });
}
