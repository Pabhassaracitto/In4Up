// test/learn_by_heart_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/learn_by_heart/controllers/chain_recitation_controller.dart';
import 'package:in4up/features/learn_by_heart/controllers/chunking_flow_controller.dart';
import 'package:in4up/features/learn_by_heart/data/dhammapada_seed_data.dart';
import 'package:in4up/features/learn_by_heart/i18n/learn_by_heart_l10n.dart';
import 'package:in4up/features/learn_by_heart/models/chunk.dart';
import 'package:in4up/features/learn_by_heart/models/fsrs_models.dart';
import 'package:in4up/features/learn_by_heart/models/learn_by_heart_item.dart';
import 'package:in4up/features/learn_by_heart/models/line_timestamp.dart';
import 'package:in4up/features/learn_by_heart/models/recitation_category.dart';
import 'package:in4up/features/learn_by_heart/models/review_state.dart';
import 'package:in4up/features/learn_by_heart/services/anki_cloze_parser.dart';
import 'package:in4up/features/learn_by_heart/services/cloze_generator.dart';
import 'package:in4up/features/learn_by_heart/services/fsrs_engine.dart';
import 'package:in4up/features/learn_by_heart/services/voice_recitation_service.dart';

void main() {
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

  group('Learn By Heart - Vanishing Scaffolding & Cloze Generator Test', () {
    test('Generates 4-level progressive scaffolding display accurately', () {
      const text = 'Ý dẫn đầu các pháp,';
      final keywords = ['Ý dẫn đầu'];

      final tokens = ClozeGenerator.generate(
        text: text,
        keywords: keywords,
        maskRatio: 0.5,
      );

      expect(tokens.isNotEmpty, true);

      // Level 1: Full text
      for (final t in tokens) {
        expect(t.getDisplayForLevel(ClozeLevel.fullText), t.text);
      }

      // Level 3: First-Letter Prompts
      final danToken = tokens.firstWhere((t) => t.cleanWord == 'dẫn');
      final firstLetterDisplay = danToken.getDisplayForLevel(ClozeLevel.firstLetter);
      expect(firstLetterDisplay.startsWith('d'), true);
      expect(firstLetterDisplay.contains('_'), true);

      // Level 4: Ghost Mode
      final ghostDisplay = danToken.getDisplayForLevel(ClozeLevel.ghost);
      expect(ghostDisplay.startsWith('d'), false);
      expect(ghostDisplay.contains('_'), true);
    });

    test('Pali diacritics work properly in First-Letter prompts', () {
      const paliText = 'Manopubbaṅgamā dhammā,';
      final tokens = ClozeGenerator.generate(text: paliText, maskRatio: 1.0);

      final manoToken = tokens.firstWhere((t) => t.cleanWord.startsWith('mano'));
      final prompt = manoToken.getDisplayForLevel(ClozeLevel.firstLetter);
      expect(prompt.startsWith('M'), true);
      expect(prompt.contains('_'), true);
    });
  });

  group('Learn By Heart - Anki Cloze Parser Test', () {
    test('Parses Anki cloze markup {{c1::từ::gợi ý}} correctly', () {
      const ankiText = 'Ý dẫn đầu các {{c1::pháp::từ khóa}}, Ý {{c2::làm chủ}}, ý tạo';
      expect(AnkiClozeParser.hasAnkiCloze(ankiText), true);

      final cardIndices = AnkiClozeParser.getCardIndices(ankiText);
      expect(cardIndices, [1, 2]);

      final stripped = AnkiClozeParser.stripAnkiSyntax(ankiText);
      expect(stripped, 'Ý dẫn đầu các pháp, Ý làm chủ, ý tạo');

      final tokens = AnkiClozeParser.parseToTokens(ankiText, targetCard: 1);
      final phapToken = tokens.firstWhere((t) => t.cleanWord == 'pháp');
      expect(phapToken.isMasked, true);
      expect(phapToken.ghostPrompt, '[từ khóa]');
    });
  });

  group('Learn By Heart - Voice Recitation & Fuzzy Alignment Test', () {
    test('Evaluates spoken text and aligns words accurately', () {
      const target = 'Ý dẫn đầu các pháp Ý làm chủ ý tạo';
      const spoken = 'Ý dẫn đầu các pháp Ý làm chủ ý tạo tác';

      final result = VoiceRecitationService.evaluateRecitation(
        targetText: target,
        spokenText: spoken,
      );

      expect(result.accuracyPercent, greaterThanOrEqualTo(90.0));
      expect(result.suggestedRating, FSRSRating.easy);
    });
  });

  group('Learn By Heart - Chain Recitation Controller Test', () {
    test('Builds sequential line-by-line priming steps', () {
      final item = DhammapadaSeedData.getInitialItems().first;
      final chainController = ChainRecitationController(item);

      expect(chainController.totalSteps, greaterThanOrEqualTo(2));
      expect(chainController.currentStepIndex, 0);

      chainController.revealCurrentTarget();
      expect(chainController.isCurrentRevealed, true);

      chainController.markStepCompleted();
      expect(chainController.currentStep?.isCompleted, true);
    });
  });

  group('Learn By Heart - Internationalization (i18n) Test', () {
    test('Covers en, vi, hi, zh, zh_TW, si languages with valid fallback', () {
      final supportedCodes = ['en', 'vi', 'hi', 'zh', 'zh_TW', 'si'];

      for (final code in supportedCodes) {
        final l10n = LearnByHeartL10n(code);
        expect(l10n.moduleTitle.isNotEmpty, true);
        expect(l10n.vanishingScaffolding.isNotEmpty, true);
        expect(l10n.level1Full.isNotEmpty, true);
        expect(l10n.level2Keywords.isNotEmpty, true);
        expect(l10n.level3FirstLetter.isNotEmpty, true);
        expect(l10n.level4Ghost.isNotEmpty, true);
        expect(l10n.again.isNotEmpty, true);
        expect(l10n.good.isNotEmpty, true);
        expect(l10n.perfectRecite.isNotEmpty, true);
      }

      // Unknown locale falls back to English
      final fallbackL10n = LearnByHeartL10n('unknown_lang');
      expect(fallbackL10n.moduleTitle, 'Memorization · Learn by Heart');
    });
  });
}
