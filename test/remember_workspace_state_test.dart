import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/models/remember_workspace_state.dart';

void main() {
  test('review requires ready cards before starting', () {
    expect(
      const I4uRememberWorkspaceState(
        loadState: I4uRememberLoadState.ready,
        totalCount: 0,
      ).canStart,
      isFalse,
    );
  });

  test('memorization stage is progressively disclosed', () {
    const state = I4uRememberWorkspaceState(
      loadState: I4uRememberLoadState.ready,
      totalCount: 5,
      stage: I4uMemorizationStage.recognize,
    );
    expect(state.isProgressiveStage, isTrue);
    expect(state.stage, I4uMemorizationStage.recognize);
  });
}
