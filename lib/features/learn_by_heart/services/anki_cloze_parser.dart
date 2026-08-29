// lib/features/learn_by_heart/services/anki_cloze_parser.dart

import 'cloze_generator.dart';

/// Bộ phân tích cú pháp Anki Cloze chuẩn ({{c1::từ::gợi ý}})
class AnkiClozeParser {
  static final RegExp _ankiPattern = RegExp(r'\{\{c(\d+)::([^:]+?)(?:::([^}]+?))?\}\}');

  /// Kiểm tra chuỗi có chứa cú pháp Anki Cloze không
  static bool hasAnkiCloze(String text) {
    return _ankiPattern.hasMatch(text);
  }

  /// Trích xuất danh sách các thẻ c1, c2, c3...
  static List<int> getCardIndices(String text) {
    final matches = _ankiPattern.allMatches(text);
    final indices = <int>{};
    for (final m in matches) {
      final idx = int.tryParse(m.group(1) ?? '1');
      if (idx != null) indices.add(idx);
    }
    return indices.toList()..sort();
  }

  /// Chuyển đổi văn bản có Anki Cloze thành văn bản thuần túy (loại bỏ cú pháp)
  static String stripAnkiSyntax(String text) {
    return text.replaceAllMapped(_ankiPattern, (match) => match.group(2) ?? '');
  }

  /// Phân tích văn bản Anki thành danh sách ClozeToken cho một thẻ cụ thể (mặc định thẻ c1)
  static List<ClozeToken> parseToTokens(String text, {int targetCard = 1}) {
    if (text.trim().isEmpty) return [];

    // Tìm tất cả các đoạn Anki và đoạn chữ thường
    final tokens = <ClozeToken>[];
    int tokenId = 0;
    int cursor = 0;

    for (final match in _ankiPattern.allMatches(text)) {
      // 1. Phần chữ trước match
      if (match.start > cursor) {
        final plainBefore = text.substring(cursor, match.start);
        tokens.addAll(_splitPlainSegment(plainBefore, tokenId));
        tokenId += tokens.length;
      }

      // 2. Phần Anki Cloze match
      final cardIdx = int.tryParse(match.group(1) ?? '1') ?? 1;
      final answer = match.group(2) ?? '';
      final hint = match.group(3);
      final isTarget = (cardIdx == targetCard || targetCard == 0);

      final clean = answer.replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '').toLowerCase();
      final ghostPrompt = hint != null && hint.isNotEmpty ? '[$hint]' : '___';
      final firstLetter = clean.isNotEmpty ? clean[0] : '_';
      final firstLetterPrompt = '$firstLetter${'_' * (clean.length > 1 ? clean.length - 1 : 2)}';

      tokens.add(ClozeToken(
        id: tokenId++,
        text: answer,
        cleanWord: clean,
        isMasked: isTarget,
        isKeyword: true,
        firstLetterPrompt: firstLetterPrompt,
        ghostPrompt: ghostPrompt,
        isRevealed: !isTarget,
      ));

      cursor = match.end;
    }

    // 3. Phần chữ còn lại sau match cuối
    if (cursor < text.length) {
      final plainAfter = text.substring(cursor);
      tokens.addAll(_splitPlainSegment(plainAfter, tokenId));
    }

    return tokens;
  }

  static List<ClozeToken> _splitPlainSegment(String segment, int startId) {
    final rawTokens = segment.split(RegExp(r'(\s+)'));
    final list = <ClozeToken>[];
    int currentId = startId;

    for (final t in rawTokens) {
      if (t.trim().isEmpty) continue;
      final clean = t.replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '').toLowerCase();
      final firstLetter = clean.isNotEmpty ? clean[0] : '_';
      final firstLetterPrompt = '$firstLetter${'_' * (clean.length > 1 ? clean.length - 1 : 2)}';

      list.add(ClozeToken(
        id: currentId++,
        text: t,
        cleanWord: clean,
        isMasked: false,
        firstLetterPrompt: firstLetterPrompt,
        ghostPrompt: '___',
        isRevealed: true,
      ));
    }
    return list;
  }
}
