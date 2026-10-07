import 'package:flutter/foundation.dart';

import 'i4u_shell_contracts.dart';

enum I4uUnderstandLoadState { idle, loading, ready, unavailable, error }
enum I4uCoachTask { explain, syntax, summarize, ask, quiz }
enum I4uCoachSessionState { idle, active, submitting, feedback, paused, stale }

@immutable
class I4uUnderstandWorkspaceState {
  const I4uUnderstandWorkspaceState({
    this.loadState = I4uUnderstandLoadState.idle,
    this.source,
    this.task,
    this.sessionState = I4uCoachSessionState.idle,
    this.step = 0,
    this.answerDraft = '',
    this.hintLevel = 0,
  });

  final I4uUnderstandLoadState loadState;
  final I4uSourceFingerprint? source;
  final I4uCoachTask? task;
  final I4uCoachSessionState sessionState;
  final int step;
  final String answerDraft;
  final int hintLevel;

  bool get hasSource => source != null;
  bool get canStart => hasSource && loadState == I4uUnderstandLoadState.ready;
  bool get canSubmit => sessionState == I4uCoachSessionState.active && answerDraft.trim().isNotEmpty;
  bool get isStale => sessionState == I4uCoachSessionState.stale;
}
