import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/services/vocab_batch/vocab_batch_models.dart';
import 'package:in4up_core/vocab_level_difficulty.dart';

WebExtractionCandidate _candidate() => WebExtractionCandidate(
      text: 'resilient',
      normalized: 'resilient',
      sampleContext: 'A resilient community can recover quickly.',
      frequency: 2,
      existed: false,
      wordCount: 1,
      appearsInTitle: false,
      isPriority: true,
      rankScore: 12,
      selected: true,
    );

void main() {
  group('WebExtractionCandidate difficulty persistence', () {
    test('round-trips the selected difficulty', () {
      final candidate = _candidate()..difficulty = DifficultyLevel.hard;

      final restored = WebExtractionCandidate.fromJson(candidate.toJson());

      expect(candidate.toJson()['difficulty'], 'hard');
      expect(restored.difficulty, DifficultyLevel.hard);
    });

    test('accepts older drafts and ignores unknown difficulty values', () {
      final oldDraft = _candidate().toJson()..remove('difficulty');
      final invalidDraft = _candidate().toJson()..['difficulty'] = 'expert';

      expect(WebExtractionCandidate.fromJson(oldDraft).difficulty, isNull);
      expect(WebExtractionCandidate.fromJson(invalidDraft).difficulty, isNull);
    });
  });
}
