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

  /// Sang câu hỏi/nhiệm vụ kế tiếp: nháp của câu TRƯỚC được xoá là chủ ý
  /// (đã submit hoặc người học chủ động bỏ), gợi ý cũng về mức 0.
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

  /// Nguồn đã đổi (revision khác) ⇒ phiên cũ trở thành "stale".
  ///
  /// C-31: đây là sự kiện do HỆ THỐNG, không phải người học — nên không được
  /// xoá nháp trả lời đang gõ dở, số bước hay mức gợi ý. Người học chỉ mất
  /// nháp khi chính họ chuyển bước ([nextStep]) hoặc đổi nhiệm vụ ([start]).
  void markStale() => value = I4uUnderstandWorkspaceState(
        loadState: value.loadState,
        source: value.source,
        task: value.task,
        sessionState: I4uCoachSessionState.stale,
        step: value.step,
        answerDraft: value.answerDraft,
        hintLevel: value.hintLevel,
      );
}
