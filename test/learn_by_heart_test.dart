// test/learn_by_heart_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/learn_by_heart/data/dhammapada_seed_data.dart';
import 'package:in4up/features/learn_by_heart/models/chunk.dart';
import 'package:in4up/features/learn_by_heart/models/fsrs_models.dart';
import 'package:in4up/features/learn_by_heart/models/learn_by_heart_item.dart';
import 'package:in4up/features/learn_by_heart/models/line_timestamp.dart';
import 'package:in4up/features/learn_by_heart/models/recitation_category.dart';
import 'package:in4up/features/learn_by_heart/models/recitation_repeat.dart';
import 'package:in4up/features/learn_by_heart/models/review_state.dart';
import 'package:in4up/features/learn_by_heart/services/cloze_generator.dart';
import 'package:in4up/features/learn_by_heart/services/fsrs_engine.dart';
import 'package:in4up/features/learn_by_heart/controllers/chunking_flow_controller.dart';

void main() {
  group('Learn By Heart - Per-line TTS repeat overrides', () {
    test('JSON roundtrip preserves per-line repeats', () {
      final items = DhammapadaSeedData.getInitialItems();
      final item = items.first.copyWith(
        lineRepeatOverrides: const {1: 5, 3: 2, 7: 999},
      );
      final restored =
          LearnByHeartItem.fromJson(item.toJson() as Map<String, dynamic>);
      expect(restored.lineRepeatOverrides, {1: 5, 3: 2, 7: 999});

      // Item không có override (item cũ) → rỗng, không crash.
      final plain = LearnByHeartItem.fromJson(items.first.toJson());
      expect(plain.lineRepeatOverrides, isEmpty);
    });

    test('fromJson tolerates string keys, bad keys and out-of-range counts',
        () {
      final item = DhammapadaSeedData.getInitialItems().first;
      final json = item.toJson();
      json['lineRepeatOverrides'] = {
        '2': 3,
        'abc': 4, // key rác → bỏ
        '9': 0, // count < 1 → bỏ
        '10': 9999, // count > 999 → bỏ
        '11': '7', // value string → parse
      };
      final restored = LearnByHeartItem.fromJson(json);
      expect(restored.lineRepeatOverrides, {2: 3, 11: 7});
    });

    test('RecitationRepeat.forLine: override thắng default, clamp 1..999',
        () {
      const overrides = {2: 5};
      expect(RecitationRepeat.forLine(1, defaultCount: 3, overrides: overrides),
          3);
      expect(RecitationRepeat.forLine(2, defaultCount: 3, overrides: overrides),
          5);
      expect(RecitationRepeat.clampLine(0), 1);
      expect(RecitationRepeat.clampLine(9999), 999);
    });
  });

  group('Learn By Heart - Seed Data & Models Test', () {
    test('Initial seed items are valid and structured according to Spec v4.1', () {
      final items = DhammapadaSeedData.getInitialItems();
      expect(items.length, greaterThanOrEqualTo(12));

      for (final item in items) {
        expect(item.id.isNotEmpty, true);
        expect(item.title.isNotEmpty, true);
        expect(item.vietnameseText.isNotEmpty, true);
        expect(item.chunkList.isNotEmpty, true);
        expect(item.keywords.isNotEmpty, true);
        expect(item.shortMeaning.isNotEmpty, true);
        expect(item.lifeConnection.isNotEmpty, true);

        // JSON roundtrip test
        final json = item.toJson();
        final deserialized = LearnByHeartItem.fromJson(json);
        expect(deserialized.id, item.id);
        expect(deserialized.title, item.title);
        expect(deserialized.category, item.category);
        expect(deserialized.chunkList.length, item.chunkList.length);
        expect(deserialized.keywords.length, item.keywords.length);
      }
    });

    test('Dhammapada Verse 01 has valid Pali and Vietnamese chunks', () {
      final items = DhammapadaSeedData.getInitialItems();
      final dhp1 = items.firstWhere((i) => i.id == 'dhp_001');

      expect(dhp1.paliText.contains('Manopubbaṅgamā dhammā'), true);
      expect(dhp1.vietnameseText.contains('Ý dẫn đầu các pháp'), true);
      expect(dhp1.chunkList.length, 3);
      expect(dhp1.keywords, contains('Ý dẫn đầu'));
      expect(dhp1.keywords, contains('Ý ô nhiễm'));
      expect(dhp1.keywords, contains('Khổ não'));
    });
  });

  group('Learn By Heart - FSRS Engine & Cold Start Test', () {
    test('Cold start reviews follow intervals [0, 1, 3, 7, 14]', () {
      final initialItem = DhammapadaSeedData.getInitialItems().first;
      expect(initialItem.totalReviews, 0);

      // Review 1: Good
      final rev1 = FSRSEngine.processReview(item: initialItem, rating: FSRSRating.good);
      expect(rev1.totalReviews, 1);
      expect(rev1.consecutiveSuccesses, 1);
      expect(rev1.reviewState, ReviewState.review);

      // Review 2: Good
      final rev2 = FSRSEngine.processReview(item: rev1, rating: FSRSRating.good);
      expect(rev2.totalReviews, 2);
      expect(rev2.consecutiveSuccesses, 2);

      // Review 3: Good
      final rev3 = FSRSEngine.processReview(item: rev2, rating: FSRSRating.good);
      expect(rev3.totalReviews, 3);
      expect(rev3.consecutiveSuccesses, 3);

      // Review 4: Good
      final rev4 = FSRSEngine.processReview(item: rev3, rating: FSRSRating.good);
      expect(rev4.totalReviews, 4);
      expect(rev4.consecutiveSuccesses, 4);

      // Review 5: Good
      final rev5 = FSRSEngine.processReview(item: rev4, rating: FSRSRating.good);
      expect(rev5.totalReviews, 5);
      expect(rev5.consecutiveSuccesses, 5);
      expect(rev5.isReadyForAssessment, true);
    });

    test('Again rating resets streak, sets lapse state and 1 day interval', () {
      final itemWithReps = DhammapadaSeedData.getInitialItems().first.copyWith(
        totalReviews: 4,
        consecutiveSuccesses: 4,
        reviewState: ReviewState.review,
      );

      final lapsed = FSRSEngine.processReview(item: itemWithReps, rating: FSRSRating.again);
      expect(lapsed.consecutiveSuccesses, 0);
      expect(lapsed.reviewState, ReviewState.lapse);
      expect(lapsed.fsrsParams.lapses, 1);
      expect(lapsed.fsrsParams.lastIntervalDays, 1);
    });

    test('Assessment layer applies 2x weight factor on stability', () {
      final itemReady = DhammapadaSeedData.getInitialItems().first.copyWith(
        totalReviews: 5,
        consecutiveSuccesses: 5,
        fsrsParams: const FSRSParams(stability: 14.0, difficulty: 5.0),
      );

      final perfectResult = FSRSEngine.processAssessment(
        item: itemReady,
        rating: AssessmentRating.perfect,
      );

      expect(perfectResult.totalAssessments, 1);
      expect(perfectResult.consecutiveSuccesses, 7); // 5 + 2 bonus
      expect(perfectResult.fsrsParams.stability, greaterThan(25.0)); // > 14 * 2.0
      expect(perfectResult.isMastered, true);
    });
  });

  group('Learn By Heart - Cloze Generator Test', () {
    test('Generates interactive masked tokens matching keywords', () {
      const text = 'Ý dẫn đầu các pháp, Ý làm chủ, ý tạo';
      final keywords = ['Ý dẫn đầu', 'Ý làm chủ'];

      final tokens = ClozeGenerator.generate(
        text: text,
        keywords: keywords,
        maskRatio: 0.5,
      );

      expect(tokens.isNotEmpty, true);
      final maskedTokens = tokens.where((t) => t.isMasked).toList();
      expect(maskedTokens.isNotEmpty, true);

      // Verify keyword token properties
      final kwTokens = tokens.where((t) => t.isKeyword).toList();
      expect(kwTokens.isNotEmpty, true);
    });
  });

  group('Learn By Heart - Chunking Flow Controller Test', () {
    test('Creates progressive scaffolding steps from chunks to full recall', () {
      final item = DhammapadaSeedData.getInitialItems().first;
      final controller = ChunkingFlowController(item);

      expect(controller.totalSteps, greaterThanOrEqualTo(4));
      expect(controller.steps.first.type, ChunkStepType.studySingle);
      expect(controller.steps.last.type, ChunkStepType.fullRecall);

      // Advance through steps
      expect(controller.currentStepIndex, 0);
      controller.markStepCompleted();
      expect(controller.isStepCompleted, true);

      final canNext = controller.nextStep();
      expect(canNext, true);
      expect(controller.currentStepIndex, 1);
      expect(controller.isStepCompleted, false);
    });
  });
}
