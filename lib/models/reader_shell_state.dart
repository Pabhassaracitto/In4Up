import 'package:flutter/foundation.dart';

import 'i4u_shell_contracts.dart';

enum I4uReaderLoadState { idle, pickingSource, loading, ready, empty, offline, error }

enum I4uReaderPanel { none, typography, selectionActions, contextualTools }

@immutable
class I4uReaderShellState {
  const I4uReaderShellState({
    this.loadState = I4uReaderLoadState.idle,
    this.source,
    this.anchor,
    this.panel = I4uReaderPanel.none,
    this.hasUnsavedNote = false,
  });

  final I4uReaderLoadState loadState;
  final I4uSourceFingerprint? source;
  final I4uSemanticReadingAnchor? anchor;
  final I4uReaderPanel panel;
  final bool hasUnsavedNote;

  bool get canReturnToSource => source != null;
  bool get shouldShowRetry => loadState == I4uReaderLoadState.error || loadState == I4uReaderLoadState.offline;
}
