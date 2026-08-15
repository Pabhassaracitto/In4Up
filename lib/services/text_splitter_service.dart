// lib/services/text_splitter_service.dart

/// Dịch vụ tách dòng tự động thông minh
class TextSplitterService {
  /// Tách text thành các dòng theo quy tắc
  ///
  /// [mode]:
  ///   - sentence: theo dấu . ! ?
  ///   - clause: theo dấu , ; : (nếu đủ dài)
  ///   - smart: kết hợp cả hai
  ///   - paragraph: theo đoạn văn (\n\n)
  ///
  /// [minWordsBeforeSplit]: số từ tối thiểu trước khi tách tại dấu phẩy
  static List<String> split(
    String text, {
    SplitMode mode = SplitMode.smart,
    int minWordsBeforeSplit = 4,
    int maxWordsPerLine = 20,
  }) {
    if (text.trim().isEmpty) return [];

    switch (mode) {
      case SplitMode.sentence:
        return _splitBySentence(text);
      case SplitMode.clause:
        return _splitByClause(text, minWordsBeforeSplit);
      case SplitMode.smart:
        return _splitSmart(text, minWordsBeforeSplit, maxWordsPerLine);
      case SplitMode.paragraph:
        return _splitByParagraph(text);
      case SplitMode.line:
        return _splitByLine(text);
      case SplitMode.none:
        return [text];
    }
  }

  /// Tách theo câu (dấu . ! ?)
  static List<String> _splitBySentence(String text) {
    // Giữ dấu câu ở cuối mỗi phần
    final parts = text.split(RegExp(r'(?<=[.!?])\s+'));
    return parts.map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
  }

  /// Tách theo mệnh đề (dấu , ; :) nếu đủ dài
  static List<String> _splitByClause(String text, int minWords) {
    final sentences = _splitBySentence(text);
    final result = <String>[];

    for (final sentence in sentences) {
      if (_wordCount(sentence) <= minWords * 2) {
        // Câu ngắn → giữ nguyên
        result.add(sentence);
        continue;
      }

      // Tách theo dấu phẩy/chấm phẩy
      final clauses = sentence.split(RegExp(r'(?<=[,;:])\s+'));
      final buffer = StringBuffer();
      int wordsSoFar = 0;

      for (int i = 0; i < clauses.length; i++) {
        final clause = clauses[i];
        final clauseWords = _wordCount(clause);

        if (wordsSoFar > 0 && wordsSoFar >= minWords) {
          // Đã đủ từ → tách
          result.add(buffer.toString().trim());
          buffer.clear();
          wordsSoFar = 0;
        }

        if (buffer.isNotEmpty) buffer.write(' ');
        buffer.write(clause);
        wordsSoFar += clauseWords;
      }

      if (buffer.isNotEmpty) {
        result.add(buffer.toString().trim());
      }
    }

    return result.where((r) => r.isNotEmpty).toList();
  }

  /// ★ Tách thông minh: kết hợp câu + mệnh đề + giới hạn từ
  static List<String> _splitSmart(
    String text,
    int minWordsBeforeSplit,
    int maxWordsPerLine,
  ) {
    // Bước 1: Tách theo đoạn văn trước
    final paragraphs = text.split(RegExp(r'\n\s*\n'));
    final result = <String>[];

    for (final paragraph in paragraphs) {
      if (paragraph.trim().isEmpty) continue;

      // Bước 2: Tách theo câu
      final sentences = paragraph.split(RegExp(r'(?<=[.!?])\s+'));

      for (final sentence in sentences) {
        final trimmed = sentence.trim();
        if (trimmed.isEmpty) continue;

        final words = _wordCount(trimmed);

        if (words <= maxWordsPerLine) {
          // Câu vừa đủ → giữ nguyên
          result.add(trimmed);
        } else {
          // Câu quá dài → tách theo mệnh đề
          final clauses = _splitLongSentence(
            trimmed,
            minWordsBeforeSplit,
            maxWordsPerLine,
          );
          result.addAll(clauses);
        }
      }
    }

    return result.where((r) => r.isNotEmpty).toList();
  }

  /// Tách câu dài thành các mệnh đề
  static List<String> _splitLongSentence(
    String sentence,
    int minWords,
    int maxWords,
  ) {
    final result = <String>[];

    // Ưu tiên tách tại dấu ; trước
    var parts = sentence.split(RegExp(r'(?<=[;])\s+'));
    if (parts.length == 1) {
      // Không có dấu ; → thử dấu ,
      parts = sentence.split(RegExp(r'(?<=[,])\s+'));
    }

    if (parts.length == 1) {
      // Không có dấu phẩy → thử dấu : hoặc -
      parts = sentence.split(RegExp(r'(?<=[:–—])\s+'));
    }

    if (parts.length == 1) {
      // Vẫn không tách được → cắt cứng theo số từ
      result.addAll(_splitByWordCount(sentence, maxWords));
      return result;
    }

    // Gộp các phần nhỏ lại nếu quá ngắn
    final buffer = StringBuffer();
    int wordsSoFar = 0;

    for (final part in parts) {
      final partWords = _wordCount(part);

      if (wordsSoFar >= minWords && wordsSoFar + partWords > maxWords) {
        result.add(buffer.toString().trim());
        buffer.clear();
        wordsSoFar = 0;
      }

      if (buffer.isNotEmpty) buffer.write(' ');
      buffer.write(part);
      wordsSoFar += partWords;
    }

    if (buffer.isNotEmpty) {
      result.add(buffer.toString().trim());
    }

    return result;
  }

  /// Cắt cứng theo số từ
  static List<String> _splitByWordCount(String text, int maxWords) {
    final words = text.split(RegExp(r'\s+'));
    final result = <String>[];

    for (int i = 0; i < words.length; i += maxWords) {
      final end = (i + maxWords).clamp(0, words.length);
      result.add(words.sublist(i, end).join(' '));
    }

    return result;
  }

  /// Tách theo đoạn văn
  static List<String> _splitByParagraph(String text) {
    return text
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
  }

  /// Tách theo dòng (mỗi \n)
  static List<String> _splitByLine(String text) {
    return text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
  }

  /// Đếm từ
  static int _wordCount(String text) {
    return text.trim().split(RegExp(r'\s+')).length;
  }

  /// Preview: cho xem kết quả trước khi apply
  static SplitPreview preview(
    String text, {
    SplitMode mode = SplitMode.smart,
    int minWordsBeforeSplit = 4,
    int maxWordsPerLine = 20,
  }) {
    final lines = split(
      text,
      mode: mode,
      minWordsBeforeSplit: minWordsBeforeSplit,
      maxWordsPerLine: maxWordsPerLine,
    );

    return SplitPreview(
      lines: lines,
      totalLines: lines.length,
      avgWordsPerLine: lines.isEmpty
          ? 0.0
          : lines.map((l) => _wordCount(l)).reduce((a, b) => a + b) /
              lines.length,
      originalLineCount:
          text.split('\n').where((l) => l.trim().isNotEmpty).length,
    );
  }
}

enum SplitMode {
  none, // Không tách
  line, // Theo dòng (\n)
  sentence, // Theo câu (. ! ?)
  clause, // Theo mệnh đề (, ; :)
  smart, // Thông minh (kết hợp)
  paragraph, // Theo đoạn (\n\n)
}

extension SplitModeExt on SplitMode {
  String get label {
    switch (this) {
      case SplitMode.none:
        return 'Content';
      case SplitMode.line:
        return 'Content';
      case SplitMode.sentence:
        return 'Content';
      case SplitMode.clause:
        return 'Content';
      case SplitMode.smart:
        return 'Content';
      case SplitMode.paragraph:
        return 'Content';
    }
  }

  String get description {
    switch (this) {
      case SplitMode.none:
        return 'Content';
      case SplitMode.line:
        return 'Content';
      case SplitMode.sentence:
        return 'Content';
      case SplitMode.clause:
        return 'Content';
      case SplitMode.smart:
        return 'Content';
      case SplitMode.paragraph:
        return 'Content';
    }
  }
}

class SplitPreview {
  final List<String> lines;
  final int totalLines;
  final double avgWordsPerLine;
  final int originalLineCount;

  const SplitPreview({
    required this.lines,
    required this.totalLines,
    required this.avgWordsPerLine,
    required this.originalLineCount,
  });
}