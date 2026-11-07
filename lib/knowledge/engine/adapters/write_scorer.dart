/// ═══════════════════════════════════════════════════════════════
/// WRITE SCORER ADAPTER — chính tả 1 từ (ADR-0018 §2, P3)
///
/// Trích các hàm scorer thuần từ `write_studio_screen.dart` thành
/// module reusable. Chế độ 1 từ: user viết từ, chấm score.
///
/// Single-word score = charScore; phrases use orderScore × 0.7 + charScore × 0.3.
///   orderScore = LCS(expected, actual) / |expected|
///   charScore  = 1 - Levenshtein / maxLen
///
/// Thuần — không I/O, deterministic, test đơn giản.
/// ═══════════════════════════════════════════════════════════════
library;

import 'dart:math' as math;

import 'package:in4up/features/dharma/services/dharma_text.dart'
    show foldDiacritics;

/// Kết quả chấm chính tả.
class WriteScoreResult {
  final double score; // 0..1
  final double orderScore;
  final double spellingScore;
  final List<String> missingWords;
  final List<String> extraWords;
  final bool isCorrect; // score >= 0.8

  const WriteScoreResult({
    required this.score,
    required this.orderScore,
    required this.spellingScore,
    required this.missingWords,
    required this.extraWords,
    this.isCorrect = false,
  });

  @override
  String toString() =>
      'WriteScore(score: ${score.toStringAsFixed(3)}, correct: $isCorrect)';
}

/// Scorer chính tả — thuần chức năng.
class WriteScorer {
  WriteScorer._();

  /// Chấm chính tả 1 từ hoặc cụm từ.
  ///
  /// [expected] từ/cụm từ cần viết.
  /// [actual] bài viết của user.
  static WriteScoreResult score({
    required String expected,
    required String actual,
  }) {
    final expectedTokens = tokenize(expected);
    final actualTokens = tokenize(actual);
    final expectedText = expectedTokens.join(' ');
    final actualText = actualTokens.join(' ');

    final lcs = longestCommonSubsequence(expectedTokens, actualTokens);
    final orderScore =
        expectedTokens.isEmpty ? 0.0 : lcs / expectedTokens.length;
    final charScore = stringSimilarity(expectedText, actualText);
    // Token order has no meaning for a single-word spelling attempt.
    // Use character similarity instead of penalizing an entire word as missing
    // for one typo. Do not accept inputs with no supported expected letters.
    final score = expectedTokens.isEmpty
        ? 0.0
        : expectedTokens.length == 1
            ? charScore
            : ((orderScore * 0.7) + (charScore * 0.3))
                .clamp(0.0, 1.0)
                .toDouble();

    final missing = subtractMultiset(expectedTokens, actualTokens);
    final extra = subtractMultiset(actualTokens, expectedTokens);

    return WriteScoreResult(
      score: score,
      orderScore: orderScore,
      spellingScore: charScore,
      missingWords: missing,
      extraWords: extra,
      isCorrect: score >= 0.8,
    );
  }

  /// Normalize từ — lowercase, chỉ [a-z0-9'].
  static String normalizeWord(String input) {
    return foldDiacritics(input)
        .replaceAll(RegExp(r"[^a-z0-9']"), '')
        .trim();
  }

  /// Tokenize + normalize.
  static List<String> tokenize(String input) {
    return input
        .split(RegExp(r'\s+'))
        .map(normalizeWord)
        .where((word) => word.isNotEmpty)
        .toList();
  }

  /// LCS (Longest Common Subsequence) — số từ khớp theo thứ tự.
  static int longestCommonSubsequence(List<String> a, List<String> b) {
    if (a.isEmpty || b.isEmpty) return 0;
    final dp = List.generate(
      a.length + 1,
      (_) => List.filled(b.length + 1, 0),
    );
    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        if (a[i - 1] == b[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1] + 1;
        } else {
          dp[i][j] = math.max(dp[i - 1][j], dp[i][j - 1]);
        }
      }
    }
    return dp[a.length][b.length];
  }

  /// Tương đồng ký tự = 1 - Levenshtein / maxLen.
  static double stringSimilarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;
    final distance = levenshteinDistance(a, b);
    final maxLen = math.max(a.length, b.length);
    return (1 - (distance / maxLen)).clamp(0.0, 1.0).toDouble();
  }

  /// Khoảng cách Levenshtein.
  static int levenshteinDistance(String a, String b) {
    final rows = a.length + 1;
    final cols = b.length + 1;
    final matrix = List.generate(rows, (_) => List.filled(cols, 0));

    for (int i = 0; i < rows; i++) matrix[i][0] = i;
    for (int j = 0; j < cols; j++) matrix[0][j] = j;

    for (int i = 1; i < rows; i++) {
      for (int j = 1; j < cols; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        matrix[i][j] = math.min(
          math.min(matrix[i - 1][j] + 1, matrix[i][j - 1] + 1),
          matrix[i - 1][j - 1] + cost,
        );
      }
    }
    return matrix[rows - 1][cols - 1];
  }

  /// Trừ multiset: phần tử trong a không có trong b.
  static List<String> subtractMultiset(List<String> a, List<String> b) {
    final result = <String>[];
    final bCopy = [...b];
    for (final item in a) {
      final idx = bCopy.indexOf(item);
      if (idx >= 0) {
        bCopy.removeAt(idx);
      } else {
        result.add(item);
      }
    }
    return result;
  }
}
