import 'package:flutter/foundation.dart';

import '../../models/reader_contextual_panel_state.dart';

@immutable
class I4uSemanticBookmarkTarget {
  const I4uSemanticBookmarkTarget({required this.lineIndex, required this.offset});
  final int lineIndex;
  final int offset;
}

class I4uSemanticBookmarkResolver {
  const I4uSemanticBookmarkResolver();

  I4uSemanticBookmarkTarget? resolve({
    required I4uReaderSelectionContext selection,
    required List<String> lines,
  }) {
    if (lines.isEmpty || selection.text.trim().isEmpty) return null;
    final preferred = selection.characterOffset;
    if (preferred != null) {
      var cursor = 0;
      for (var i = 0; i < lines.length; i++) {
        final end = cursor + lines[i].length;
        if (preferred <= end) {
          return I4uSemanticBookmarkTarget(lineIndex: i, offset: preferred - cursor);
        }
        cursor = end + 1;
      }
    }
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].contains(selection.text)) {
        return I4uSemanticBookmarkTarget(lineIndex: i, offset: lines[i].indexOf(selection.text));
      }
    }
    return null;
  }
}
