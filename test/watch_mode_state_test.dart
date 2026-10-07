import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/models/watch_mode_state.dart';

void main() {
  test('watch mode exposes retry only for recoverable states', () {
    expect(const I4uWatchModeState(loadState: I4uWatchLoadState.offline).canRetry, isTrue);
    expect(const I4uWatchModeState(loadState: I4uWatchLoadState.ready).canRetry, isFalse);
  });

  test('handoff requires a ready source context', () {
    expect(const I4uWatchModeState(loadState: I4uWatchLoadState.ready).canHandoffToUnderstand, isFalse);
  });
}
