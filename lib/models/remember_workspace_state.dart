import 'package:flutter/foundation.dart';

import 'i4u_shell_contracts.dart';

enum I4uRememberLoadState { idle, loading, ready, empty, offline, error }
enum I4uReviewSessionState { idle, active, revealed, rating, paused, completed }
enum I4uReviewRating { notRemembered, difficult, remembered, mastered }
enum I4uMemorizationStage { recognize, recall, reconstruct, recite, integrate }

@immutable
class I4uRememberWorkspaceState {
  const I4uRememberWorkspaceState({
    this.loadState = I4uRememberLoadState.idle,
    this.sessionState = I4uReviewSessionState.idle,
    this.stage,
    this.source,
    this.currentCardId,
    this.rating,
    this.completedCount = 0,
    this.totalCount = 0,
  });

  final I4uRememberLoadState loadState;
  final I4uReviewSessionState sessionState;
  final I4uMemorizationStage? stage;
  final I4uSourceFingerprint? source;
  final String? currentCardId;
  final I4uReviewRating? rating;
  final int completedCount;
  final int totalCount;

  bool get canStart => loadState == I4uRememberLoadState.ready && totalCount > 0;
  bool get isProgressiveStage => stage != null;
  bool get isComplete => sessionState == I4uReviewSessionState.completed;
}
