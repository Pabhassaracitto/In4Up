import 'package:flutter/foundation.dart';

enum I4uHomeLoadState { idle, loading, ready, empty, offline, error }

@immutable
class I4uHomeCommandCenterState {
  const I4uHomeCommandCenterState({
    this.loadState = I4uHomeLoadState.idle,
    this.continueSourceId,
    this.needsAttentionCount = 0,
    this.recentActivityCount = 0,
    this.showFocusRhythm = true,
  });

  final I4uHomeLoadState loadState;
  final String? continueSourceId;
  final int needsAttentionCount;
  final int recentActivityCount;
  final bool showFocusRhythm;

  I4uHomeCommandCenterState copyWith({
    I4uHomeLoadState? loadState,
    String? continueSourceId,
    int? needsAttentionCount,
    int? recentActivityCount,
    bool? showFocusRhythm,
  }) => I4uHomeCommandCenterState(
        loadState: loadState ?? this.loadState,
        continueSourceId: continueSourceId ?? this.continueSourceId,
        needsAttentionCount: needsAttentionCount ?? this.needsAttentionCount,
        recentActivityCount: recentActivityCount ?? this.recentActivityCount,
        showFocusRhythm: showFocusRhythm ?? this.showFocusRhythm,
      );
}
