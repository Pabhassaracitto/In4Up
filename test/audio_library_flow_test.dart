import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/core/audio/audio_library_flow.dart';
import 'package:in4up/models/audio_library_state.dart';

void main() {
  test('audio library flow preserves selection through player expansion', () {
    final flow = I4uAudioLibraryFlowController();
    flow.beginLoading();
    flow.completeLoading(hasItems: true);
    flow.select('audio-1');
    flow.expandPlayer();
    expect(flow.value.loadState, I4uAudioLibraryLoadState.ready);
    expect(flow.value.selectedAudioId, 'audio-1');
    expect(flow.value.isPlayerExpanded, isTrue);
    flow.collapsePlayer();
    expect(flow.value.selectedAudioId, 'audio-1');
  });

  test('empty library remains explicit after loading', () {
    final flow = I4uAudioLibraryFlowController();
    flow.beginLoading();
    flow.completeLoading(hasItems: false);
    expect(flow.value.loadState, I4uAudioLibraryLoadState.empty);
  });
}
