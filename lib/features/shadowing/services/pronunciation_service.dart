// lib/services/pronunciation_service.dart
// Service đánh giá phát âm

import 'dart:math' as math;

import '../models/phoneme_models.dart';
import '../models/shadowing_result.dart';
import 'cmu_dictionary_service.dart';
import 'phoneme_analyzer.dart';

class PronunciationService {
  /// So sánh text và tính điểm
  static ShadowingResult analyze({
    required String originalText,
    required String recognizedText,
    List<double> originalWaveform = const [],
    List<double> userWaveform = const [],
    Duration originalDuration = Duration.zero,
    Duration userDuration = Duration.zero,
  }) {
    final originalWords = _normalize(originalText).split(' ');
    final recognizedWords = _normalize(recognizedText).split(' ');

    final wordResults = <WordResult>[];

    for (int i = 0; i < originalWords.length; i++) {
      final expected = originalWords[i];
      final recognized = i < recognizedWords.length ? recognizedWords[i] : null;

      final phonemeResult = PhonemeAnalyzer.getPhonemes(expected);
      final phonemeScores = _estimatePhonemeScores(
        expected,
        recognized,
        phonemeResult.phonemes,
      );

      final wordScore = _calculateWordScore(expected, recognized);
      final status = _getWordStatus(expected, recognized);

      wordResults.add(WordResult(
        expectedWord: expected,
        recognizedWord: recognized,
        status: status,
        score: wordScore,
        phonemeScores: phonemeScores,
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
      acousticAnalysis: acousticAnalysis,
      originalWaveform: originalWaveform,
      userWaveform: userWaveform,
      originalDuration: originalDuration,
      userDuration: userDuration,
    );
  }

  static String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static double _calculateWordScore(String expected, String? recognized) {
    if (recognized == null) return 0.0;
    if (expected.toLowerCase() == recognized.toLowerCase()) return 1.0;

    // Jaro-Winkler similarity
    return _jaroWinkler(expected.toLowerCase(), recognized.toLowerCase());
  }

  static WordStatus _getWordStatus(String expected, String? recognized) {
    if (recognized == null) return WordStatus.missed;
    if (expected.toLowerCase() == recognized.toLowerCase()) {
      return WordStatus.correct;
    }
    return WordStatus.substituted;
  }

  static List<PhonemeScore> _estimatePhonemeScores(
    String expectedWord,
    String? recognizedWord,
    List<String> expectedPhonemes,
  ) {
    if (recognizedWord == null) {
      return expectedPhonemes
          .map((p) => PhonemeScore(
                phoneme: p,
                type: CMUDictionaryService.getPhonemeType(p),
                score: 0.0,
                status: PhonemeStatus.missed,
              ))
          .toList();
    }

    if (expectedWord.toLowerCase() == recognizedWord.toLowerCase()) {
      // Từ đúng - cho điểm cao
      final random = math.Random();
      return expectedPhonemes
          .map((p) => PhonemeScore(
                phoneme: p,
                type: CMUDictionaryService.getPhonemeType(p),
                score: 0.85 + random.nextDouble() * 0.15,
                status: PhonemeStatus.correct,
              ))
          .toList();
    }

    // Từ gần đúng - phân tích chi tiết
    final diffPositions =
        _findDifferencePositions(expectedWord, recognizedWord);

    return expectedPhonemes.asMap().entries.map((entry) {
      final idx = entry.key;
      final phoneme = entry.value;
      final phonemePosition = idx / expectedPhonemes.length;

      bool isInErrorZone = diffPositions.any((pos) {
        final normalizedPos = pos / expectedWord.length;
        return (normalizedPos - phonemePosition).abs() < 0.2;
      });

      double score;
      PhonemeStatus status;

      if (isInErrorZone) {
        score = 0.3 + math.Random().nextDouble() * 0.4;
        status = PhonemeStatus.needsWork;
      } else {
        score = 0.75 + math.Random().nextDouble() * 0.25;
        status =
            score >= 0.8 ? PhonemeStatus.correct : PhonemeStatus.acceptable;
      }

      return PhonemeScore(
        phoneme: phoneme,
        type: CMUDictionaryService.getPhonemeType(phoneme),
        score: score,
        status: status,
      );
    }).toList();
  }

  static List<int> _findDifferencePositions(String a, String b) {
    final positions = <int>[];
    final minLen = math.min(a.length, b.length);

    for (int i = 0; i < minLen; i++) {
      if (a[i].toLowerCase() != b[i].toLowerCase()) {
        positions.add(i);
      }
    }

    if (a.length != b.length) {
      positions.add(minLen);
    }

    return positions;
  }

  static double _jaroWinkler(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    final jaro = _jaro(s1, s2);

    int prefix = 0;
    for (int i = 0; i < math.min(4, math.min(s1.length, s2.length)); i++) {
      if (s1[i] == s2[i]) {
        prefix++;
      } else {
        break;
      }
    }

    return jaro + (prefix * 0.1 * (1 - jaro));
  }

  static double _jaro(String s1, String s2) {
    final len1 = s1.length;
    final len2 = s2.length;

    final matchWindow = (math.max(len1, len2) / 2 - 1).floor();

    final s1Matches = List<bool>.filled(len1, false);
    final s2Matches = List<bool>.filled(len2, false);

    int matches = 0;
    int transpositions = 0;

    for (int i = 0; i < len1; i++) {
      final start = math.max(0, i - matchWindow);
      final end = math.min(i + matchWindow + 1, len2);

      for (int j = start; j < end; j++) {
        if (s2Matches[j] || s1[i] != s2[j]) continue;
        s1Matches[i] = s2Matches[j] = true;
        matches++;
        break;
      }
    }

    if (matches == 0) return 0.0;

    int k = 0;
    for (int i = 0; i < len1; i++) {
      if (!s1Matches[i]) continue;
      while (!s2Matches[k]) {
        k++;
      }
      if (s1[i] != s2[k]) transpositions++;
      k++;
    }

    return (matches / len1 +
            matches / len2 +
            (matches - transpositions / 2) / matches) /
        3;
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
