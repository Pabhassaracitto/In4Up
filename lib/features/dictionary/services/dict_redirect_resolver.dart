import '../models/dict_entry.dart';
import 'dict_entry_links.dart';

/// Resolve MDict redirects only against the caller's current dictionary DB.
/// Original records are preserved when the target is absent, malformed, loops,
/// or exceeds the work budget. No DB or source dictionary is modified.
class DictRedirectResolver {
  DictRedirectResolver._();

  static const int maxDepth = 8;
  static const int maxLookups = 32;
  static const int maxVisitedEntries = 512;

  static Future<List<DictEntry>> resolve(
    List<DictEntry> entries,
    Future<List<DictEntry>> Function(String word) lookup,
  ) async {
    var remaining = maxLookups;
    var remainingVisits = maxVisitedEntries;
    final cache = <String, List<DictEntry>>{};

    Future<List<DictEntry>> visit(
      DictEntry entry,
      Set<String> visited,
      int depth,
    ) async {
      if (remainingVisits <= 0) return <DictEntry>[entry];
      remainingVisits--;
      final target = DictEntryLinks.redirectTarget(entry.definition);
      if (target == null || depth >= maxDepth || visited.contains(target)) {
        return <DictEntry>[entry];
      }
      var matches = cache[target];
      if (matches == null) {
        if (remaining <= 0) return <DictEntry>[entry];
        remaining--;
        try {
          matches = await lookup(target);
        } catch (_) {
          return <DictEntry>[entry];
        }
        cache[target] = matches;
      }
      if (matches.isEmpty) return <DictEntry>[entry];
      final nextVisited = <String>{...visited, target};
      final resolved = <DictEntry>[];
      for (final match in matches) {
        for (final result in await visit(match, nextVisited, depth + 1)) {
          resolved.add(DictEntry(
            headword: entry.headword,
            definition: result.definition,
            phonetic: result.phonetic,
            audioPath: result.audioPath,
            partOfSpeech: result.partOfSpeech,
            dictId: entry.dictId,
          ));
        }
      }
      return resolved;
    }

    final output = <DictEntry>[];
    for (final entry in entries) {
      output.addAll(await visit(entry, <String>{entry.headword}, 0));
    }
    return output;
  }
}
