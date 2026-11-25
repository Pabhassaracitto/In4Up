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
  static const int maxResolvedEntries = 512;

  static Future<List<DictEntry>> resolve(
    List<DictEntry> entries,
    Future<List<DictEntry>> Function(String word) lookup, {
    void Function()? onTruncated,
  }) async {
    var remaining = maxLookups;
    var remainingVisits = maxVisitedEntries;
    final cache = <String, List<DictEntry>>{};

    Future<List<DictEntry>> visit(
      DictEntry entry,
      Set<String> visited,
      int depth,
    ) async {
      if (remainingVisits <= 0) {
        onTruncated?.call();
        return <DictEntry>[entry];
      }
      remainingVisits--;
      final target = DictEntryLinks.redirectTarget(entry.definition);
      if (target == null || depth >= maxDepth || visited.contains(target)) {
        return <DictEntry>[entry];
      }
      var matches = cache[target];
      if (matches == null) {
        if (remaining <= 0) {
          onTruncated?.call();
          return <DictEntry>[entry];
        }
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
          if (resolved.length >= maxResolvedEntries) {
            onTruncated?.call();
            return resolved;
          }
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
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final resolved = await visit(entry, <String>{entry.headword}, 0);
      final remaining = maxResolvedEntries - output.length;
      if (resolved.length > remaining) onTruncated?.call();
      output.addAll(resolved.take(remaining));
      if (output.length >= maxResolvedEntries && i + 1 < entries.length) {
        onTruncated?.call();
        break;
      }
    }
    return output;
  }
}
