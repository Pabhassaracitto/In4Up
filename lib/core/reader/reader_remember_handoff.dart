import 'package:flutter/foundation.dart';

import '../../models/reader_contextual_panel_state.dart';

@immutable
class I4uRememberHandoff {
  const I4uRememberHandoff({
    required this.text,
    required this.sourceId,
    this.blockId,
    this.characterOffset,
  });

  final String text;
  final String sourceId;
  final String? blockId;
  final int? characterOffset;

  factory I4uRememberHandoff.fromSelection(I4uReaderSelectionContext selection) =>
      I4uRememberHandoff(
        text: selection.text.trim(),
        sourceId: selection.sourceId,
        blockId: selection.blockId,
        characterOffset: selection.characterOffset,
      );
}
