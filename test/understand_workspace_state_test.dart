import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/models/understand_workspace_state.dart';

void main() {
  test('Understand requires source context before starting', () {
    expect(
      const I4uUnderstandWorkspaceState(loadState: I4uUnderstandLoadState.ready).canStart,
      isFalse,
    );
  });

  test('Coach cannot submit an empty answer', () {
    expect(
      const I4uUnderstandWorkspaceState(
        loadState: I4uUnderstandLoadState.ready,
        sessionState: I4uCoachSessionState.active,
      ).canSubmit,
      isFalse,
    );
  });
}
