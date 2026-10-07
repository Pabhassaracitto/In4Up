import 'package:flutter/foundation.dart';

import '../../models/remember_workspace_state.dart';

class I4uRememberFlowController extends ValueNotifier<I4uRememberWorkspaceState> {
  I4uRememberFlowController() : super(const I4uRememberWorkspaceState());

  void load({required int totalCount}) => value = I4uRememberWorkspaceState(
        loadState: totalCount > 0 ? I4uRememberLoadState.ready : I4uRememberLoadState.empty,
        totalCount: totalCount,
      );

  void startReview(String cardId) {
    if (!value.canStart) return;
    value = I4uRememberWorkspaceState(
      loadState: value.loadState,
      sessionState: I4uReviewSessionState.active,
      currentCardId: cardId,
      completedCount: value.completedCount,
      totalCount: value.totalCount,
    );
  }

  void reveal() => value = I4uRememberWorkspaceState(
        loadState: value.loadState,
        sessionState: I4uReviewSessionState.revealed,
        currentCardId: value.currentCardId,
        completedCount: value.completedCount,
        totalCount: value.totalCount,
      );

  void rate(I4uReviewRating rating) {
    if (value.sessionState != I4uReviewSessionState.revealed) return;
    value = I4uRememberWorkspaceState(
      loadState: value.loadState,
      sessionState: I4uReviewSessionState.rating,
      currentCardId: value.currentCardId,
      rating: rating,
      completedCount: value.completedCount,
      totalCount: value.totalCount,
    );
  }

  void nextCard(String cardId) {
    final completed = value.completedCount + 1;
    value = I4uRememberWorkspaceState(
      loadState: value.loadState,
      sessionState: completed >= value.totalCount
          ? I4uReviewSessionState.completed
          : I4uReviewSessionState.active,
      currentCardId: completed >= value.totalCount ? null : cardId,
      completedCount: completed,
      totalCount: value.totalCount,
    );
  }

  void pause() => value = I4uRememberWorkspaceState(
        loadState: value.loadState,
        sessionState: I4uReviewSessionState.paused,
        currentCardId: value.currentCardId,
        completedCount: value.completedCount,
        totalCount: value.totalCount,
      );

  void startStage(I4uMemorizationStage stage, String cardId) {
    if (!value.canStart) return;
    value = I4uRememberWorkspaceState(
      loadState: value.loadState,
      sessionState: I4uReviewSessionState.active,
      stage: stage,
      currentCardId: cardId,
      completedCount: value.completedCount,
      totalCount: value.totalCount,
    );
  }
}
