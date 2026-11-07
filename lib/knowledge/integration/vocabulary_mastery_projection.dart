import '../../models/skill_review_data.dart';
import '../../models/word_entry.dart';
import '../engine/ema_engine.dart' show MasteryVector;
import '../models/learning_state.dart' show SkillDimension;

/// Read-only projection for the six-skill visualization.
///
/// The existing WordEntry remains the source of truth for all three input
/// scores and their separate SM-2 histories. These scores are *not* EMAs.
/// Output is included only when an actual output vector with evidence flags is
/// supplied; the current app does not yet persist or supply such vectors.
class VocabularyMasteryProjection {
  final String unitId;
  final Map<SkillDimension, double?> values;
  final bool useIsPartial;

  VocabularyMasteryProjection._({
    required this.unitId,
    required Map<SkillDimension, double?> values,
    required this.useIsPartial,
  }) : values = Map.unmodifiable(values);

  factory VocabularyMasteryProjection.fromWord(
    WordEntry word, {
    MasteryVector? output,
  }) {
    return VocabularyMasteryProjection._(
      unitId: word.id,
      values: {
        SkillDimension.understanding: _legacyScore(word.understandData),
        SkillDimension.listening: _legacyScore(word.listenData),
        SkillDimension.reading: _legacyScore(word.readData),
        SkillDimension.use: output != null && output.hasUse
            ? _finiteScore(output.useDisplay)
            : null,
        SkillDimension.speak: output != null && output.hasSpeak
            ? _finiteScore(output.speak)
            : null,
        SkillDimension.write: output != null && output.hasWrite
            ? _finiteScore(output.write)
            : null,
      },
      useIsPartial: output?.useIsPartial ?? false,
    );
  }
}

// Older entries have no per-skill "manually set" flag. A non-zero stored
// score (including a Venn or slider edit) is meaningful; a reviewed zero is
// also meaningful. An untouched zero with no history is ambiguous, so show it
// as unknown instead of inventing an assessment. A manually set zero on an
// otherwise untouched legacy entry is indistinguishable and remains unknown.
double? _legacyScore(SkillReviewData data) {
  final hasHistory = data.totalReviews > 0 ||
      data.repetitions > 0 ||
      data.interval > 0 ||
      data.nextReview != null;
  if (data.score == 0 && !hasHistory) return null;
  return _finiteScore(data.score);
}

double? _finiteScore(double value) =>
    value.isFinite ? value.clamp(0.0, 1.0).toDouble() : null;
