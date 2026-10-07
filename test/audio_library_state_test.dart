import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/models/audio_library_state.dart';

void main() {
  test('audio library exposes retry only for recoverable load states', () {
    expect(const I4uAudioLibraryState(loadState: I4uAudioLibraryLoadState.error).canRetry, isTrue);
    expect(const I4uAudioLibraryState(loadState: I4uAudioLibraryLoadState.offline).canRetry, isTrue);
    expect(const I4uAudioLibraryState(loadState: I4uAudioLibraryLoadState.ready).canRetry, isFalse);
  });

  test('import state is explicit and reports progress separately', () {
    const state = I4uAudioLibraryState(
      loadState: I4uAudioLibraryLoadState.importing,
      importProgress: .5,
    );
    expect(state.isImporting, isTrue);
    expect(state.importProgress, .5);
  });
}
