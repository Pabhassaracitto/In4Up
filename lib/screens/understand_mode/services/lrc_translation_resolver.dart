import '../../../models/text_item.dart';

/// Finds the saved Read-tab translation that belongs to an LRC line.
///
/// Listen and Understand must use the same resolver so enabling translation in
/// the shared karaoke settings produces identical output in both tabs.
String? resolveLrcTranslation(
  List<TextItem> textLines,
  String lrcText,
) {
  final normalizedLrc = _normalize(lrcText);
  if (normalizedLrc.isEmpty) return null;

  final translatedLines = textLines.where((line) {
    return _normalize(line.content).isNotEmpty &&
        line.translation?.trim().isNotEmpty == true;
  });

  for (final line in translatedLines) {
    if (_normalize(line.content) == normalizedLrc) {
      return line.translation!.trim();
    }
  }

  // LRC/STT segmentation can wrap one Read line into a longer lyric line (or
  // the reverse). Prefer the longest contained source to avoid a short common
  // phrase winning over a more specific match.
  TextItem? bestContainedMatch;
  var bestLength = -1;
  for (final line in translatedLines) {
    final source = _normalize(line.content);
    if (normalizedLrc.contains(source) || source.contains(normalizedLrc)) {
      final matchLength = source.length;
      if (matchLength > bestLength) {
        bestContainedMatch = line;
        bestLength = matchLength;
      }
    }
  }

  return bestContainedMatch?.translation?.trim();
}

String _normalize(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
