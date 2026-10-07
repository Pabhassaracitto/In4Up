import 'package:flutter/foundation.dart';

import '../../models/i4u_shell_contracts.dart';
import '../../models/understand_workspace_state.dart';

@immutable
class I4uCoachFeedback {
  const I4uCoachFeedback({required this.text, this.isCorrect, this.hint});
  final String text;
  final bool? isCorrect;
  final String? hint;
}

class I4uCoachFlowController extends ValueNotifier<I4uUnderstandWorkspaceState> {
  I4uCoachFlowController() : super(const I4uUnderstandWorkspaceState());

  void loadSource(I4uSourceFingerprint source) {
    value = I4uUnderstandWorkspaceState(
      loadState: I4uUnderstandLoadState.ready,
      source: source,
    );
  }

  void start(I4uCoachTask task) {
    if (!value.canStart) return;
    value = I4uUnderstandWorkspaceState(
      loadState: value.loadState,
      source: value.source,
      task: task,
      sessionState: I4uCoachSessionState.active,
    );
  }

  void updateDraft(String draft) {
    value = I4uUnderstandWorkspaceState(
      loadState: value.loadState,
      source: value.source,
      task: value.task,
      sessionState: value.sessionState,
      step: value.step,
      answerDraft: draft,
      hintLevel: value.hintLevel,
    );
  }

  void submit() {
    if (!value.canSubmit) return;
    value = I4uUnderstandWorkspaceState(
      loadState: value.loadState,
      source: value.source,
      task: value.task,
      sessionState: I4uCoachSessionState.submitting,
      step: value.step,
      answerDraft: value.answerDraft,
      hintLevel: value.hintLevel,
    );
  }

  void showFeedback() {
    value = I4uUnderstandWorkspaceState(
      loadState: value.loadState,
      source: value.source,
      task: value.task,
      sessionState: I4uCoachSessionState.feedback,
      step: value.step,
      answerDraft: value.answerDraft,
      hintLevel: value.hintLevel,
    );
  }

  void nextStep() {
    value = I4uUnderstandWorkspaceState(
      loadState: value.loadState,
      source: value.source,
      task: value.task,
      sessionState: I4uCoachSessionState.active,
      step: value.step + 1,
    );
  }

  void requestHint() {
    value = I4uUnderstandWorkspaceState(
      loadState: value.loadState,
      source: value.source,
      task: value.task,
      sessionState: value.sessionState,
      step: value.step,
      answerDraft: value.answerDraft,
      hintLevel: value.hintLevel + 1,
    );
  }

  void markStale() => value = I4uUnderstandWorkspaceState(
        loadState: value.loadState,
        source: value.source,
        task: value.task,
        sessionState: I4uCoachSessionState.stale,
        step: value.step,
      );
}
