import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/core/audio/audio_library_recovery.dart';

void main() {
  test('offline library prefers cache when available', () {
    const state = I4uAudioRecoveryState(
      kind: I4uAudioErrorKind.offline,
      message: 'offline',
      canUseCache: true,
    );
    expect(state.actions.first, I4uAudioRecoveryAction.useCachedLibrary);
  });

  test('permission error offers settings rather than blind retry', () {
    const state = I4uAudioRecoveryState(
      kind: I4uAudioErrorKind.permissionDenied,
      message: 'permission',
    );
    expect(state.actions.first, I4uAudioRecoveryAction.openSettings);
  });
}
