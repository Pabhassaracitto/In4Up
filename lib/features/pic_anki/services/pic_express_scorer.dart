/// Pic Express — chấm miêu tả so với entity user gắn (không cần VLM).
library;

class PicDescribeScore {
  final double coverage;
  final int matched;
  final int total;
  final List<String> missing;
  final List<String> hit;

  const PicDescribeScore({
    required this.coverage,
    required this.matched,
    required this.total,
    required this.missing,
    required this.hit,
  });

  /// Map 0–5 gần SM-2 quality (không gộp skill — chỉ rubric Express).
  int get qualityHint {
    if (total == 0) return 0;
    if (coverage >= 0.9) return 5;
    if (coverage >= 0.7) return 4;
    if (coverage >= 0.4) return 3;
    if (coverage > 0) return 2;
    return 1;
  }
}

class PicExpressScorer {
  PicExpressScorer._();

  static final RegExp _splitter = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

  static String normalize(String raw) =>
      raw.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static Set<String> tokens(String raw) {
    final n = normalize(raw);
    if (n.isEmpty) return <String>{};
    return n
        .split(_splitter)
        .where((t) => t.length >= 2)
        .toSet();
  }

  static PicDescribeScore score({
    required List<String> entities,
    required String answer,
  }) {
    final cleanEntities = entities
        .map(normalize)
        .where((e) => e.isNotEmpty)
        .toList();
    if (cleanEntities.isEmpty) {
      return const PicDescribeScore(
        coverage: 0,
        matched: 0,
        total: 0,
        missing: <String>[],
        hit: <String>[],
      );
    }
    final answerNorm = normalize(answer);
    final answerTok = tokens(answer);
    final hit = <String>[];
    final missing = <String>[];
    for (final entity in cleanEntities) {
      final eTok = tokens(entity);
      final matchedPhrase = answerNorm.contains(entity);
      final matchedTokens =
          eTok.isNotEmpty && eTok.every(answerTok.contains);
      if (matchedPhrase || matchedTokens) {
        hit.add(entity);
      } else {
        missing.add(entity);
      }
    }
    final matched = hit.length;
    return PicDescribeScore(
      coverage: matched / cleanEntities.length,
      matched: matched,
      total: cleanEntities.length,
      missing: missing,
      hit: hit,
    );
  }
}
