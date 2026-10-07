import 'package:flutter/foundation.dart';

enum I4uReaderContextAction { dictionary, note, remember, explain, playAudio, bookmark }

enum I4uReaderContextPanelMode { closed, mobileSheet, desktopPanel }

@immutable
class I4uReaderSelectionContext {
  const I4uReaderSelectionContext({
    required this.text,
    required this.sourceId,
    this.blockId,
    this.characterOffset,
  });

  final String text;
  final String sourceId;
  final String? blockId;
  final int? characterOffset;
}

@immutable
class I4uReaderContextualPanelState {
  const I4uReaderContextualPanelState({
    this.mode = I4uReaderContextPanelMode.closed,
    this.selection,
    this.activeAction,
    this.isLoading = false,
    this.errorMessage,
  });

  final I4uReaderContextPanelMode mode;
  final I4uReaderSelectionContext? selection;
  final I4uReaderContextAction? activeAction;
  final bool isLoading;
  final String? errorMessage;

  bool get hasSelection => selection != null && selection!.text.trim().isNotEmpty;
  bool get canRunAction => hasSelection && !isLoading;

  I4uReaderContextualPanelState close() => I4uReaderContextualPanelState(
        selection: selection,
      );
}
