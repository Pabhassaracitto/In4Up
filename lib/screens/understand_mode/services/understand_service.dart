// lib/screens/understand_mode/services/understand_service.dart

import '../models/understand_line.dart';

class UnderstandService {
  // Calculate comprehension progress
  static double calculateComprehension(List<UnderstandLine> lines) {
    if (lines.isEmpty) return 0.0;

    final totalLines = lines.length;
    final completedLines =
        lines.where((line) => line.comprehensionScore > 0.7).length;

    return completedLines / totalLines;
  }

  // Check if line needs review based on comprehension score
  static bool needsReview(UnderstandLine line) {
    return line.comprehensionScore < 0.7 || line.isDifficult;
  }

  // Extract vocabulary from text
  static List<String> extractVocabulary(String text) {
    final words = text.split(RegExp(r'\s+'));
    final stopWords = {
      'the',
      'a',
      'an',
      'and',
      'or',
      'but',
      'in',
      'on',
      'at',
      'to',
      'for'
    };

    return words
        .where((word) =>
            word.length > 2 && !stopWords.contains(word.toLowerCase()))
        .map((word) => word.toLowerCase())
        .toSet()
        .toList();
  }

  // Calculate reading speed (words per minute)
  static double calculateReadingSpeed(String text, Duration duration) {
    final wordCount = text.split(RegExp(r'\s+')).length;
    final minutes = duration.inMilliseconds / 60000.0;

    return wordCount / minutes;
  }

  // Suggest next lines based on current progress
  static List<int> suggestNextLines(
      List<UnderstandLine> lines, int currentIndex) {
    final suggestions = <int>[];

    // Add next logical lines
    for (int i = currentIndex + 1; i < lines.length; i++) {
      if (!lines[i].isDifficult && lines[i].comprehensionScore > 0.7) {
        suggestions.add(i);
      }
      if (suggestions.length >= 3) break;
    }

    // Add lines that need review
    for (int i = 0; i < lines.length; i++) {
      if (needsReview(lines[i]) && i != currentIndex) {
        suggestions.add(i);
      }
      if (suggestions.length >= 5) break;
    }

    return suggestions;
  }
}
