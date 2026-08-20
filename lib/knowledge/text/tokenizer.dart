/// ═══════════════════════════════════════════════════════════════
/// TOKENIZER — tách từ có vị trí, hỗ trợ tiếng Việt + số thập phân
///
/// Handoff MVA v2.0 — Task 4.
///  * Số nguyên/thập phân giữ NGUYÊN một token: "3.14", "1.000,25".
///  * Từ Latin (kể cả dấu tiếng Việt — \p{L} unicode), dấu nháy đơn
///    ("don't") và gạch nối trong từ ("state-of-the-art").
///  * Ghép từ ghép Việt bằng Trie (longest match): "sinh viên" là MỘT
///    token compound, không phải "sinh" + "viên".
/// Thuần dart:core — không import ngoài.
/// ═══════════════════════════════════════════════════════════════
library;

import 'vietnamese_trie.dart';

/// Một token có vị trí (offset) trong chuỗi ĐÃ normalize.
class Token {
  final String text;
  final int start;
  final int end;

  /// Token là từ (không phải số).
  final bool isWord;

  /// Token là số (nguyên/thập phân, có thể chứa '.' / ',').
  final bool isNumber;

  /// Từ ghép nhiều tiếng (ví dụ "sinh viên") — gộp bởi Trie.
  final bool isCompound;

  /// Số tiếng trong token compound (1 nếu không phải compound).
  final int wordCount;

  const Token({
    required this.text,
    required this.start,
    required this.end,
    required this.isWord,
    required this.isNumber,
    this.isCompound = false,
    this.wordCount = 1,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'text': text,
        'start': start,
        'end': end,
        'isWord': isWord,
        'isNumber': isNumber,
        'isCompound': isCompound,
        'wordCount': wordCount,
      };

  factory Token.fromJson(Map<String, dynamic> json) => Token(
        text: json['text'] as String,
        start: json['start'] as int,
        end: json['end'] as int,
        isWord: json['isWord'] as bool? ?? false,
        isNumber: json['isNumber'] as bool? ?? false,
        isCompound: json['isCompound'] as bool? ?? false,
        wordCount: json['wordCount'] as int? ?? 1,
      );
}

/// Tách token — mọi offset tính trên chuỗi truyền vào.
class TextTokenizer {
  TextTokenizer._();

  /// Số đứng trước để không bị nuốt dấu phân tách thập phân.
  static final RegExp _tokenPattern = RegExp(
    r"\d+(?:[.,]\d+)*" // 3.14 | 1.000,25 | 2026
    r"|[\p{L}]+(?:['-][\p{L}]+)*", // từ (unicode), don't, state-of-the-art
    unicode: true,
  );

  /// Tách token; [trie] để gộp từ ghép (truyền null để bỏ qua).
  static List<Token> tokenize(String text, {VietnameseTrie? trie}) {
    final raw = <Token>[];
    for (final m in _tokenPattern.allMatches(text)) {
      final t = m.group(0)!;
      final isNumber = t.codeUnitAt(0) >= 0x30 && t.codeUnitAt(0) <= 0x39;
      raw.add(Token(
        text: t,
        start: m.start,
        end: m.end,
        isWord: !isNumber,
        isNumber: isNumber,
      ));
    }
    if (trie == null) return List.unmodifiable(raw);
    return List.unmodifiable(_mergeCompounds(text, raw, trie));
  }

  /// Gộp chuỗi từ liền nhau thành token compound khi Trie khớp.
  static List<Token> _mergeCompounds(
    String text,
    List<Token> raw,
    VietnameseTrie trie,
  ) {
    final lowered = <String>[];
    final wordIndexes = <int>[];
    for (var i = 0; i < raw.length; i++) {
      if (raw[i].isWord) {
        lowered.add(raw[i].text.toLowerCase());
        wordIndexes.add(i);
      }
    }

    final merged = <Token>[];
    var w = 0; // con trỏ trên danh sách từ-thuần
    var r = 0; // con trỏ trên danh sách token thô
    while (r < raw.length) {
      if (!raw[r].isWord) {
        merged.add(raw[r]);
        r++;
        continue;
      }
      final matchLen = trie.longestMatch(lowered, w);
      // Chỉ gộp khi các từ LIỀN KỀ TRONG CHUỖI (đúng 1 space giữa hai từ,
      // vì text đã normalize) — không gộp xuyên dấu câu ("sinh, viên").
      var adjacent = true;
      for (var k = 0; k < matchLen - 1; k++) {
        final cur = raw[wordIndexes[w + k]];
        final nxt = raw[wordIndexes[w + k + 1]];
        if (nxt.start != cur.end + 1) {
          adjacent = false;
          break;
        }
      }
      if (matchLen >= 2 && adjacent) {
        final first = raw[wordIndexes[w]];
        final last = raw[wordIndexes[w + matchLen - 1]];
        merged.add(Token(
          text: text.substring(first.start, last.end),
          start: first.start,
          end: last.end,
          isWord: true,
          isNumber: false,
          isCompound: true,
          wordCount: matchLen,
        ));
        // bỏ qua các token thô đã gộp (kể cả token phi-từ xen giữa cụm).
        final skipUntil = last.end;
        while (r < raw.length && raw[r].start < skipUntil) {
          r++;
        }
        w += matchLen;
      } else {
        merged.add(raw[r]);
        r++;
        w++;
      }
    }
    return merged;
  }
}
