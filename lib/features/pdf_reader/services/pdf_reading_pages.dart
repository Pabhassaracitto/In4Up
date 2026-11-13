/// Locate the next readable page without treating an empty/scan page as EOF.
/// A session guard is checked after every asynchronous extraction.
Future<({int page, List<T> cues})?> nextPdfReadingPage<T>({
  required int from,
  required int pageCount,
  required Future<List<T>> Function(int page) load,
  required bool Function() isCurrent,
  required bool skipEmpty,
  required void Function() onEmpty,
}) async {
  for (var page = from; page < pageCount && isCurrent(); page++) {
    final cues = await load(page);
    if (!isCurrent()) return null;
    if (cues.isNotEmpty) return (page: page, cues: cues);
    onEmpty();
    if (!skipEmpty) return null;
  }
  return null;
}

/// Text Mode joins each non-empty raw page with two newlines. Resolve its
/// global selection offset without searching for (possibly repeated) words.
Future<({int page, int offset})?> pdfTextModePosition({
  required int offset,
  required int pageCount,
  required Future<String> Function(int page) load,
}) async {
  var start = 0;
  for (var page = 0; page < pageCount; page++) {
    final text = await load(page);
    if (text.isEmpty) continue;
    if (offset < start + text.length + 2) {
      return (page: page, offset: (offset - start).clamp(0, text.length));
    }
    start += text.length + 2;
  }
  return null;
}
