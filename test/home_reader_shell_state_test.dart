import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/models/home_command_center_state.dart';
import 'package:in4up/models/reader_shell_state.dart';

void main() {
  test('Home can hide calm focus rhythm without affecting other cards', () {
    const state = I4uHomeCommandCenterState(
      loadState: I4uHomeLoadState.ready,
      continueSourceId: 'source-1',
      needsAttentionCount: 2,
      showFocusRhythm: true,
    );
    final next = state.copyWith(showFocusRhythm: false);
    expect(next.loadState, I4uHomeLoadState.ready);
    expect(next.continueSourceId, 'source-1');
    expect(next.needsAttentionCount, 2);
    expect(next.showFocusRhythm, isFalse);
  });

  test('Reader exposes retry for error and offline states', () {
    expect(
      const I4uReaderShellState(loadState: I4uReaderLoadState.error).shouldShowRetry,
      isTrue,
    );
    expect(
      const I4uReaderShellState(loadState: I4uReaderLoadState.offline).shouldShowRetry,
      isTrue,
    );
    expect(
      const I4uReaderShellState(loadState: I4uReaderLoadState.ready).shouldShowRetry,
      isFalse,
    );
  });
}
