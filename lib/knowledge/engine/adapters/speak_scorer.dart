/// ═══════════════════════════════════════════════════════════════
/// SPEAK SCORER ADAPTER — phát âm 1 từ (ADR-0015 §1.2, P3)
///
/// Wrapper nhẹ quanh `PronunciationService.analyze` — chế độ 1 từ.
/// User phát âm từ đơn → STT nhận dạng → chấm score.
///
/// Tier expensive → cần cache hoặc offline (ADR-0021).
/// ═══════════════════════════════════════════════════════════════
library;

import 'package:in4up/features/shadowing/models/phoneme_models.dart' show WordStatus;
import 'package:in4up/features/shadowing/services/pronunciation_service.dart';

/// Kết quả chấm phát âm 1 từ.
class SpeakScoreResult {
  final double score; // 0..1
  final WordStatus status;
  final bool isCorrect; // score >= 0.6 (q >= 3 → scoreNor >= 0.6)

  const SpeakScoreResult({
    required this.score,
    required this.status,
    this.isCorrect = false,
  });

  @override
  String toString() =>
      'SpeakScore(score: ${score.toStringAsFixed(3)}, correct: $isCorrect)';
}

/// Scorer phát âm 1 từ — wrapper `PronunciationService`.
class SpeakScorer {
  SpeakScorer._();

  /// Chấm phát âm 1 từ.
  ///
  /// [word] từ cần phát âm.
  /// [recognizedText] văn bản STT nhận dạng từ user.
  ///
  /// score ∈ [0,1]. isCorrect = score >= 0.6 (q >= 3).
  static SpeakScoreResult score({
    required String word,
    required String recognizedText,
  }) {
    final result = PronunciationService.analyze(
      originalText: word,
      recognizedText: recognizedText,
    );

    final wordResult = result.wordResults.isNotEmpty
        ? result.wordResults.first
        : null;
    final score = wordResult?.score ?? 0.0;
    final status = wordResult?.status ?? WordStatus.missed;

    return SpeakScoreResult(
      score: score,
      status: status,
      isCorrect: score >= 0.6,
    );
  }
}
