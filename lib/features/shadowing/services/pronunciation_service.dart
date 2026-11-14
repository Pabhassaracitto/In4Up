// lib/services/pronunciation_service.dart
// Service đánh giá phát âm

import 'dart:math' as math;

import '../models/phoneme_models.dart';
import '../models/shadowing_result.dart';
import 'cmu_dictionary_service.dart';
import 'phoneme_analyzer.dart';
import 'shadowing_text_scorer.dart';

class PronunciationService {
  /// So sánh toàn bộ câu mẫu bằng alignment thuần, không dùng điểm ngẫu nhiên.
  static ShadowingResult analyze({
    required String originalText,
    required String recognizedText,
    List<double> originalWaveform = const [],
    List<double> userWaveform = const [],
    Duration originalDuration = Duration.zero,
    Duration userDuration = Duration.zero,
  }) {
    final textScore = ShadowingTextScorer.score(originalText, recognizedText);
    final wordResults = <WordResult>[];
    for (final alignment in textScore.alignments) {
      final expected = alignment.expected;
      final recognized = alignment.recognized;
      final phonemeResult = PhonemeAnalyzer.getPhonemes(expected);
      final status = alignment.isCorrect
          ? WordStatus.correct
          : recognized == null
              ? WordStatus.missed
              : WordStatus.substituted;
      wordResults.add(WordResult(
        expectedWord: expected,
        recognizedWord: recognized,
        status: status,
        score: alignment.credit,
        phonemeScores: _estimatePhonemeScores(
          recognized,
          phonemeResult.phonemes,
          alignment.credit,
        ),
        phonemeResult: phonemeResult,
      ));
    }

    final acousticAnalysis =
        originalWaveform.isNotEmpty && userWaveform.isNotEmpty
            ? _analyzeAcoustics(originalWaveform, userWaveform)
            : null;

    return ShadowingResult(
      originalText: originalText,
      recognizedText: recognizedText,
      wordResults: wordResults,
      extraWordCount: textScore.extraWordCount,
      acousticAnalysis: acousticAnalysis,
      originalWaveform: originalWaveform,
      userWaveform: userWaveform,
      originalDuration: originalDuration,
      userDuration: userDuration,
    );
  }

  /// Đây là ước lượng từ độ khớp chữ, không phải đo acoustic từng âm vị.
  /// Giữ tính xác định để cùng một bản ghi không ra điểm khác nhau mỗi lần mở lại.
  static List<PhonemeScore> _estimatePhonemeScores(
    String? recognizedWord,
    List<String> expectedPhonemes,
    double wordCredit,
  ) {
    return expectedPhonemes.map((p) {
      final score = recognizedWord == null ? 0.0 : wordCredit;
      final PhonemeStatus status;
      if (recognizedWord == null || score < 0.5) {
        status = PhonemeStatus.missed;
      } else if (score >= 1.0) {
        status = PhonemeStatus.correct;
      } else if (score >= 0.7) {
        status = PhonemeStatus.acceptable;
      } else {
        status = PhonemeStatus.needsWork;
      }
      return PhonemeScore(
        phoneme: p,
        type: CMUDictionaryService.getPhonemeType(p),
        score: score,
        status: status,
      );
    }).toList();
  }

  static AcousticAnalysis _analyzeAcoustics(
    List<double> original,
    List<double> user,
  ) {
    final similarity = _waveformSimilarity(original, user);

    return AcousticAnalysis(
      pitchScore: similarity,
      energyScore: similarity,
      rhythmScore: similarity,
      spectralScore: similarity,
    );
  }

  static double _waveformSimilarity(List<double> a, List<double> b) {
    if (a.isEmpty || b.isEmpty) return 0.5;

    // Resample to same length
    final targetLen = math.min(100, math.min(a.length, b.length));
    final resampledA = _resample(a, targetLen);
    final resampledB = _resample(b, targetLen);

    // Calculate correlation
    double sum = 0.0;
    for (int i = 0; i < targetLen; i++) {
      sum += (1.0 - (resampledA[i] - resampledB[i]).abs());
    }

    return sum / targetLen;
  }

  static List<double> _resample(List<double> data, int targetLength) {
    final result = <double>[];
    for (int i = 0; i < targetLength; i++) {
      final srcIdx = (i * data.length / targetLength).floor();
      result.add(data[srcIdx.clamp(0, data.length - 1)]);
    }
    return result;
  }
}
