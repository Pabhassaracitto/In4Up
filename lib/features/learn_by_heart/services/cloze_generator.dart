// lib/features/learn_by_heart/services/cloze_generator.dart

import 'dart:math' as math;

/// 4 cấp độ bốc hơi chữ theo tâm lý học nhận thức (Cognitive De-scaffolding Levels)
enum ClozeLevel {
  /// Level 1: Toàn văn (0% ẩn) - Đọc & nghe đối chiếu trọn vẹn
  fullText,

  /// Level 2: Ẩn từ khóa (30% ẩn) - Các từ khóa cốt lõi thành [ ___ ]
  keywords,

  /// Level 3: Mồi chữ cái đầu (First-Letter Mnemonic) - [ Ý d___ đ___ c___ p___ ]
  firstLetter,

  /// Level 4: Chữ bốc hơi 100% (Pure Blind Recall) - Toàn bộ thành vạch nhịp
  ghost,
}

/// Đại diện cho một từ hoặc cụm từ trong cơ chế Cloze thông minh
class ClozeToken {
  final int id;
  final String text;
  final String cleanWord;
  bool isMasked;
  bool isKeyword;
  final String firstLetterPrompt;
  final String ghostPrompt;
  bool isRevealed;

  ClozeToken({
    required this.id,
    required this.text,
    required this.cleanWord,
    required this.isMasked,
    this.isKeyword = false,
    required this.firstLetterPrompt,
    required this.ghostPrompt,
    this.isRevealed = false,
  });

  /// Kiểm tra token có phải là từ cần che/tương tác ở cấp độ này không
  bool isMaskedAtLevel(ClozeLevel level) {
    if (cleanWord.isEmpty) return false;
    switch (level) {
      case ClozeLevel.fullText:
        return false;
      case ClozeLevel.keywords:
        return isKeyword || isMasked;
      case ClozeLevel.firstLetter:
        return true;
      case ClozeLevel.ghost:
        return true;
    }
  }

  /// Chạm để đánh dấu / bỏ đánh dấu chỗ trống — không cần gõ `{{c1::}}`.
  void toggleKeyword() {
    isKeyword = !isKeyword;
    isMasked = isKeyword;
    isRevealed = false;
  }

  /// Hiển thị từ theo cấp độ bốc hơi chữ
  String getDisplayForLevel(ClozeLevel level) {
    if (cleanWord.isEmpty) return text;
    if (isRevealed) return text;

    switch (level) {
      case ClozeLevel.fullText:
        return text;

      case ClozeLevel.keywords:
        return (isKeyword || isMasked) ? ghostPrompt : text;

      case ClozeLevel.firstLetter:
        return firstLetterPrompt;

      case ClozeLevel.ghost:
        return ghostPrompt;
    }
  }
}

/// Bộ sinh bài tập Cloze thông minh đa cấp độ
class ClozeGenerator {
  /// Sinh danh sách tokens hoàn chỉnh cho cả 4 cấp độ
  static List<ClozeToken> generate({
    required String text,
    List<String> keywords = const [],
    double maskRatio = 0.35,
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
        // Dấu câu hoặc khoảng trắng thuần
        tokens.add(ClozeToken(
          id: tokenId++,
          text: tokenStr,
          cleanWord: '',
          isMasked: false,
          firstLetterPrompt: tokenStr,
          ghostPrompt: tokenStr,
          isRevealed: true,
        ));
        continue;
      }

      final isKw = normalizedKeywords.any((kw) => kw.contains(clean) || clean.contains(kw));

      bool shouldMask = isKw;
      if (!shouldMask && clean.length > 2) {
        final hash = (clean.hashCode + i).abs();
        shouldMask = (hash % 100) < (maskRatio * 100);
      }

      // Tạo chuỗi gợi ý chữ cái đầu (First-Letter Prompt)
      final firstLetterPrompt = _buildFirstLetterPrompt(tokenStr, clean);

      // Tạo chuỗi bốc hơi hoàn toàn (Ghost Prompt)
      final ghostPrompt = _buildGhostPrompt(tokenStr, clean);

      tokens.add(ClozeToken(
        id: tokenId++,
        text: tokenStr,
        cleanWord: clean,
        isMasked: shouldMask,
        isKeyword: isKw,
        firstLetterPrompt: firstLetterPrompt,
        ghostPrompt: ghostPrompt,
        isRevealed: false,
      ));
    }

    return tokens;
  }

  static final _wordPattern = RegExp(r'[\p{L}\p{N}]+', unicode: true);

  static const _stopwords = {
    'và', 'của', 'các', 'là', 'một', 'những', 'trong', 'với', 'cho',
    'không', 'được', 'có', 'để', 'trên', 'này', 'đó', 'từ', 'về', 'như',
    'thì', 'khi', 'đã', 'sẽ', 'hay', 'hoặc', 'nếu', 'vì', 'do', 'bởi',
    'the', 'a', 'an', 'of', 'to', 'and', 'in', 'is', 'it', 'for', 'on',
    'at', 'by', 'as', 'or', 'be', 'this', 'that', 'with', 'from',
    'ca', 'va', 'kho', 'ti',
  };

  /// Tách từ (Unicode) — dùng cho chip chạm chọn chỗ trống.
  static List<String> wordsIn(String text) {
    return _wordPattern
        .allMatches(text)
        .map((m) => m.group(0)!)
        .where((w) => w.trim().isNotEmpty)
        .toList();
  }

  /// Gợi ý từ khóa: bỏ stopword, ưu tiên từ dài, không trùng.
  static List<String> suggestKeywords(String text, {int max = 8}) {
    final seen = <String>{};
    final scored = <String>[];
    for (final word in wordsIn(text)) {
      final key = word.toLowerCase();
      if (key.length < 4 || _stopwords.contains(key) || !seen.add(key)) {
        continue;
      }
      scored.add(word);
    }
    scored.sort((a, b) => b.length.compareTo(a.length));
    if (scored.length <= max) return scored;
    return scored.take(max).toList();
  }

  /// Trích xuất ký tự đầu và tạo chuỗi [ d___, ] giữ nguyên dấu câu
  static String _buildFirstLetterPrompt(String tokenStr, String cleanWord) {
    if (tokenStr.isEmpty || cleanWord.isEmpty) return tokenStr;

    int firstLetterIdx = -1;
    for (int i = 0; i < tokenStr.length; i++) {
      if (RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(tokenStr[i])) {
        firstLetterIdx = i;
        break;
      }
    }

    if (firstLetterIdx == -1) return tokenStr;

    final prefix = tokenStr.substring(0, firstLetterIdx);
    final firstChar = tokenStr[firstLetterIdx];

    int lastLetterIdx = tokenStr.length - 1;
    while (lastLetterIdx >= 0 && !RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(tokenStr[lastLetterIdx])) {
      lastLetterIdx--;
    }

    final suffix = lastLetterIdx + 1 < tokenStr.length ? tokenStr.substring(lastLetterIdx + 1) : '';
    final blankCount = math.max(2, math.min(5, cleanWord.length - 1));
    final blanks = '_' * blankCount;

    return '$prefix$firstChar$blanks$suffix';
  }

  /// Tạo chuỗi ẩn hoàn toàn giữ nguyên dấu câu: [ _____ , ]
  static String _buildGhostPrompt(String tokenStr, String cleanWord) {
    if (tokenStr.isEmpty || cleanWord.isEmpty) return tokenStr;

    int firstLetterIdx = -1;
    for (int i = 0; i < tokenStr.length; i++) {
      if (RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(tokenStr[i])) {
        firstLetterIdx = i;
        break;
      }
    }

    if (firstLetterIdx == -1) return tokenStr;

    final prefix = tokenStr.substring(0, firstLetterIdx);
    int lastLetterIdx = tokenStr.length - 1;
    while (lastLetterIdx >= 0 && !RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(tokenStr[lastLetterIdx])) {
      lastLetterIdx--;
    }

    final suffix = lastLetterIdx + 1 < tokenStr.length ? tokenStr.substring(lastLetterIdx + 1) : '';
    final blankCount = math.max(3, math.min(6, cleanWord.length));
    final blanks = '_' * blankCount;

    return '$prefix$blanks$suffix';
  }
}
