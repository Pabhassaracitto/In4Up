import 'package:flutter/foundation.dart';

import 'i4u_shell_contracts.dart';

enum I4uWatchLoadState { idle, loading, ready, empty, offline, error }

enum I4uSubtitleMode { hidden, original, translated, bilingual }

@immutable
class I4uWatchModeState {
  const I4uWatchModeState({
    this.loadState = I4uWatchLoadState.idle,
    this.subtitleMode = I4uSubtitleMode.original,
    this.isVideoPlaying = false,
    this.currentTimestampMs = 0,
    this.source,
    this.isTranscriptAvailable = false,
  });

  final I4uWatchLoadState loadState;
  final I4uSubtitleMode subtitleMode;
  final bool isVideoPlaying;
  final int currentTimestampMs;
  final I4uSourceFingerprint? source;
  final bool isTranscriptAvailable;

  bool get canRetry => loadState == I4uWatchLoadState.error || loadState == I4uWatchLoadState.offline;
  bool get canHandoffToUnderstand => source != null && loadState == I4uWatchLoadState.ready;
}
