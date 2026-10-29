import 'package:flutter/foundation.dart';

@immutable
class DocumentSummarySignals {
  final int sourceWordCount;
  final int draftWordCount;
  final double compressionRatio;

  /// Tỷ lệ trigram trong draft xuất hiện nguyên văn trong source.
  /// Đây là tín hiệu quan sát, không phải điểm đạo văn hay chất lượng.
  final double copiedPhraseRatio;

  /// Tỷ lệ keyword quan sát được trong draft.
  final double keywordPresenceRatio;
  final List<String> presentKeywords;
  final List<String> absentKeywords;

  const DocumentSummarySignals({
    required this.sourceWordCount,
    required this.draftWordCount,
    required this.compressionRatio,
    required this.copiedPhraseRatio,
    required this.keywordPresenceRatio,
    required this.presentKeywords,
    required this.absentKeywords,
  });

  String get compressionLabel =>
      '${(compressionRatio * 100).round()}% độ dài nguồn';

  String get copiedPhraseLabel =>
      '${(copiedPhraseRatio * 100).round()}% cụm 3 từ trùng nguồn';

  String get keywordPresenceLabel =>
      '${(keywordPresenceRatio * 100).round()}% từ khóa quan sát được';
}

/// Sinh tín hiệu deterministic cho summary dài mà không giả vờ hiểu semantic.
class DocumentSummarySignalService {
  DocumentSummarySignalService._();

  static const Set<String> _stopWords = {
    'the', 'a', 'an', 'and', 'or', 'but', 'if', 'then', 'than', 'to', 'of',
    'in', 'on', 'at', 'for', 'from', 'with', 'by', 'as', 'is', 'are', 'was',
    'were', 'be', 'been', 'being', 'it', 'its', 'this', 'that', 'these',
    'those', 'he', 'she', 'they', 'we', 'you', 'i', 'his', 'her', 'their',
    'our', 'your', 'not', 'no', 'so', 'do', 'does', 'did', 'have', 'has',
    'had', 'will', 'would', 'can', 'could', 'may', 'might', 'must', 'should',
    // Stop words tiếng Việt thông dụng; danh sách cố ý ngắn và minh bạch.
    'và', 'là', 'của', 'có', 'cho', 'trong', 'một', 'những', 'các', 'được',
    'với', 'đã', 'đang', 'sẽ', 'này', 'đó', 'từ', 'khi', 'thì', 'mà', 'như',
  };

  static DocumentSummarySignals analyze({
    required String sourceText,
    required String draftText,
    int keywordLimit = 10,
  }) {
    final sourceTokens = _tokenize(sourceText);
    final draftTokens = _tokenize(draftText);
    final sourceCount = sourceTokens.length;
    final draftCount = draftTokens.length;
    final compression = sourceCount == 0 ? 0.0 : draftCount / sourceCount;

    final keywords = _topKeywords(sourceTokens, keywordLimit);
    final draftSet = draftTokens.toSet();
    final present = keywords.where(draftSet.contains).toList();
    final absent = keywords.where((word) => !draftSet.contains(word)).toList();
    final keywordRatio =
        keywords.isEmpty ? 0.0 : present.length / keywords.length;

    return DocumentSummarySignals(
      sourceWordCount: sourceCount,
      draftWordCount: draftCount,
      compressionRatio: compression,
      copiedPhraseRatio: _copiedPhraseRatio(sourceTokens, draftTokens),
      keywordPresenceRatio: keywordRatio,
      presentKeywords: present,
      absentKeywords: absent,
    );
  }

  static List<String> _topKeywords(List<String> tokens, int limit) {
    final counts = <String, int>{};
    final firstPosition = <String, int>{};
    for (var index = 0; index < tokens.length; index++) {
      final token = tokens[index];
      if (token.length < 3 || _stopWords.contains(token)) continue;
      counts[token] = (counts[token] ?? 0) + 1;
      firstPosition.putIfAbsent(token, () => index);
    }

    final ranked = counts.keys.toList()
      ..sort((a, b) {
        final frequency = counts[b]!.compareTo(counts[a]!);
        if (frequency != 0) return frequency;
        final length = b.length.compareTo(a.length);
        if (length != 0) return length;
        return firstPosition[a]!.compareTo(firstPosition[b]!);
      });
    return ranked.take(limit).toList();
  }

  static double _copiedPhraseRatio(
    List<String> sourceTokens,
    List<String> draftTokens,
  ) {
    if (draftTokens.isEmpty || sourceTokens.isEmpty) return 0.0;

    if (draftTokens.length < 3) {
      final sourceSet = sourceTokens.toSet();
      final copied = draftTokens.where(sourceSet.contains).length;
      return copied / draftTokens.length;
    }

    final sourceTrigrams = <String>{};
    for (var i = 0; i <= sourceTokens.length - 3; i++) {
      sourceTrigrams.add(
        '${sourceTokens[i]}\u0000${sourceTokens[i + 1]}\u0000${sourceTokens[i + 2]}',
      );
    }

    var copied = 0;
    final total = draftTokens.length - 2;
    for (var i = 0; i <= draftTokens.length - 3; i++) {
      final trigram =
          '${draftTokens[i]}\u0000${draftTokens[i + 1]}\u0000${draftTokens[i + 2]}';
      if (sourceTrigrams.contains(trigram)) copied++;
    }
    return total == 0 ? 0.0 : copied / total;
  }

  static List<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .map(_trimNonWordEdges)
        .where((token) => token.isNotEmpty)
        .toList();
  }

  static String _trimNonWordEdges(String token) {
    var start = 0;
    var end = token.length;
    while (start < end && !_isWordChar(token[start])) {
      start++;
    }
    while (end > start && !_isWordChar(token[end - 1])) {
      end--;
    }
    return token.substring(start, end);
  }

  static bool _isWordChar(String value) {
    if (value.toUpperCase() != value.toLowerCase() ||
        RegExp(r'[0-9]').hasMatch(value) ||
        value == "'") {
      return true;
    }

    final codeUnit = value.codeUnitAt(0);
    if (codeUnit >= 0xD800 && codeUnit <= 0xDFFF) return false;
    if (codeUnit < 0x80) return false;
    return !'“”‘’«»…—–，。！？；：（）【】《》'.contains(value);
  }
}
