// lib/features/canon/models/canon_search_result.dart

import 'canon_entry.dart';

class CanonSearchHit {
  final CanonEntry entry;
  final double score;
  final List<String> matchedTerms;
  final String snippet; // đoạn trích có highlight context

  const CanonSearchHit({
    required this.entry,
    required this.score,
    required this.matchedTerms,
    required this.snippet,
  });
}

class CanonSearchResult {
  final String query;
  final List<CanonSearchHit> hits;
  final int total;
  final Duration elapsed;
  final bool isExact;

  const CanonSearchResult({
    required this.query,
    required this.hits,
    required this.total,
    required this.elapsed,
    this.isExact = false,
  });

  bool get isEmpty => hits.isEmpty;
  bool get isNotEmpty => hits.isNotEmpty;
}
