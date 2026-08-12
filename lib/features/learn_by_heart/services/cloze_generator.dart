// lib/features/learn_by_heart/services/cloze_generator.dart

import 'dart:math' as math;

/// Đại diện cho một từ hoặc cụm trong bài tập điền chỗ trống (Cloze)
class ClozeToken {
  final int id;
  final String text;
  final String cleanWord;
  final bool isMasked;
  final bool isKeyword;
  bool isRevealed;

  ClozeToken({
    required this.id,
    required this.text,
    required this.cleanWord,
    required this.isMasked,
    this.isKeyword = false,
    this.isRevealed = false,
  });

  String get displayWord {
    if (!isMasked || isRevealed) return text;
    // Hiển thị dạng [ ___ ] giữ tương đối độ dài từ
    final length = math.max(3, cleanWord.length);
    return '_' * length;
  }
}

/// Bộ phân tích và tạo bài tập Active Recall (Cloze Deletion)
class ClozeGenerator {
  /// Tạo danh sách tokens từ văn bản kèm danh sách từ khóa
  static List<ClozeToken> generate({
    required String text,
    List<String> keywords = const [],
    double maskRatio = 0.35, // Tỷ lệ ẩn từ (35%)
  }) {
    if (text.trim().isEmpty) return [];

    final rawTokens = text.split(RegExp(r'(\s+)'));
    final tokens = <ClozeToken>[];
    final normalizedKeywords = keywords
        .map((k) => k.trim().toLowerCase())
        .where((k) => k.isNotEmpty)
        .toList();

    int tokenId = 0;
    for (int i = 0; i < rawTokens.length; i++) {
      final tokenStr = rawTokens[i];
      if (tokenStr.trim().isEmpty) continue;

      final clean = tokenStr.replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '').toLowerCase();
      if (clean.isEmpty) {
        tokens.add(ClozeToken(
          id: tokenId++,
          text: tokenStr,
          cleanWord: clean,
          isMasked: false,
          isRevealed: true,
        ));
        continue;
      }

      // Kiểm tra có phải từ khóa ưu tiên ẩn không
      final isKw = normalizedKeywords.any((kw) => kw.contains(clean) || clean.contains(kw));

      // Ẩn nếu là từ khóa hoặc dựa theo tỷ lệ ngẫu nhiên có kiểm soát
      bool shouldMask = isKw;
      if (!shouldMask && clean.length > 2) {
        // Deterministic pseudo-hash để tránh đổi vị trí liên tục trong cùng bài
        final hash = (clean.hashCode + i).abs();
        shouldMask = (hash % 100) < (maskRatio * 100);
      }

      tokens.add(ClozeToken(
        id: tokenId++,
        text: tokenStr,
        cleanWord: clean,
        isMasked: shouldMask,
        isKeyword: isKw,
        isRevealed: !shouldMask,
      ));
    }

    return tokens;
  }

  /// Tự động ẩn một phần (Ví dụ nửa câu sau trong dạng Audio -> Recall)
  static List<ClozeToken> generateHalfMask(String text) {
    final rawTokens = text.split(RegExp(r'(\s+)'));
    final tokens = <ClozeToken>[];
    final halfIndex = (rawTokens.length / 2).floor();

    int tokenId = 0;
    for (int i = 0; i < rawTokens.length; i++) {
      final tokenStr = rawTokens[i];
      if (tokenStr.trim().isEmpty) continue;

      final clean = tokenStr.replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');
      final isMasked = i >= halfIndex && clean.isNotEmpty;

      tokens.add(ClozeToken(
        id: tokenId++,
        text: tokenStr,
        cleanWord: clean,
        isMasked: isMasked,
        isRevealed: !isMasked,
      ));
    }

    return tokens;
  }
}
