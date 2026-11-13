import '../../../services/text_splitter_service.dart';

/// Offsets belong to the original text, not a normalized copy.
class ReaderCue {
  const ReaderCue(this.text, this.start, this.end);
  final String text;
  final int start;
  final int end;
}

List<ReaderCue> readerCues(String text) {
  final result = <ReaderCue>[];
  var cursor = 0;
  for (final sentence in TextSplitterService.split(text, mode: SplitMode.sentence)) {
    final start = text.indexOf(sentence, cursor);
    if (start < 0) continue;
    // Bound even punctuation-free/CJK paragraphs below platform TTS limits.
    var offset = start;
    final end = start + sentence.length;
    while (offset < end) {
      var next = (offset + 400).clamp(0, end);
      if (next < end) {
        final space = text.lastIndexOf(' ', next);
        if (space > offset) next = space + 1;
        final code = text.codeUnitAt(next - 1);
        if (code >= 0xD800 && code <= 0xDBFF) next--;
      }
      final raw = text.substring(offset, next);
      final trimmed = raw.trim();
      if (trimmed.isNotEmpty) {
        final at = offset + raw.indexOf(trimmed);
        result.add(ReaderCue(trimmed, at, at + trimmed.length));
      }
      offset = next;
    }
    cursor = end;
  }
  return result;
}

int readerCueAt(List<ReaderCue> cues, int offset) {
  final index = cues.indexWhere((cue) => cue.end > offset);
  return index < 0 ? (cues.isEmpty ? 0 : cues.length - 1) : index;
}
