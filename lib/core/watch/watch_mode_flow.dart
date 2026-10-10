import 'package:flutter/foundation.dart';

import '../../models/i4u_shell_contracts.dart';
import '../../models/watch_mode_state.dart';

@immutable
class I4uWatchHandoff {
  const I4uWatchHandoff({required this.source, required this.timestampMs, this.selectedSubtitle});
  final I4uSourceFingerprint source;
  final int timestampMs;
  final String? selectedSubtitle;
}

class I4uWatchModeFlowController extends ValueNotifier<I4uWatchModeState> {
  I4uWatchModeFlowController() : super(const I4uWatchModeState());

  void beginLoading() => value = I4uWatchModeState(
        loadState: I4uWatchLoadState.loading,
        subtitleMode: value.subtitleMode,
      );

  void ready({required I4uSourceFingerprint source, bool transcriptAvailable = false}) => value = I4uWatchModeState(
        loadState: I4uWatchLoadState.ready,
        subtitleMode: value.subtitleMode,
        source: source,
        isTranscriptAvailable: transcriptAvailable,
        currentTimestampMs: value.currentTimestampMs,
      );

  void setSubtitleMode(I4uSubtitleMode mode) => value = I4uWatchModeState(
        loadState: value.loadState,
        subtitleMode: mode,
        isVideoPlaying: value.isVideoPlaying,
        currentTimestampMs: value.currentTimestampMs,
        source: value.source,
        isTranscriptAvailable: value.isTranscriptAvailable,
      );

  void setTimestamp(int timestampMs) => value = I4uWatchModeState(
        loadState: value.loadState,
        subtitleMode: value.subtitleMode,
        isVideoPlaying: value.isVideoPlaying,
        currentTimestampMs: timestampMs.clamp(0, 86400000).toInt(),
        source: value.source,
        isTranscriptAvailable: value.isTranscriptAvailable,
      );

  I4uWatchHandoff? handoffToUnderstand({String? selectedSubtitle}) {
    final source = value.source;
    if (!value.canHandoffToUnderstand || source == null) return null;
    return I4uWatchHandoff(
      source: source,
      timestampMs: value.currentTimestampMs,
      selectedSubtitle: selectedSubtitle,
    );
  }
}
