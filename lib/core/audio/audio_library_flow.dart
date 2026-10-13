import 'package:flutter/foundation.dart';

import '../../models/audio_library_state.dart';

enum I4uAudioLibraryAction { open, import, retry, select, play, openExpanded }

@immutable
class I4uAudioLibraryFlowState {
  const I4uAudioLibraryFlowState({
    this.loadState = I4uAudioLibraryLoadState.idle,
    this.selectedAudioId,
    this.isPlayerExpanded = false,
  });

  final I4uAudioLibraryLoadState loadState;
  final String? selectedAudioId;
  final bool isPlayerExpanded;
}

class I4uAudioLibraryFlowController extends ValueNotifier<I4uAudioLibraryFlowState> {
  I4uAudioLibraryFlowController() : super(const I4uAudioLibraryFlowState());

  void beginLoading() => value = I4uAudioLibraryFlowState(
        loadState: I4uAudioLibraryLoadState.loading,
        selectedAudioId: value.selectedAudioId,
      );

  void completeLoading({required bool hasItems}) => value = I4uAudioLibraryFlowState(
        loadState: hasItems ? I4uAudioLibraryLoadState.ready : I4uAudioLibraryLoadState.empty,
        selectedAudioId: value.selectedAudioId,
      );

  void beginImport() => value = I4uAudioLibraryFlowState(
        loadState: I4uAudioLibraryLoadState.importing,
        selectedAudioId: value.selectedAudioId,
      );

  void select(String audioId) => value = I4uAudioLibraryFlowState(
        loadState: I4uAudioLibraryLoadState.ready,
        selectedAudioId: audioId,
      );

  void expandPlayer() => value = I4uAudioLibraryFlowState(
        loadState: value.loadState,
        selectedAudioId: value.selectedAudioId,
        isPlayerExpanded: true,
      );

  void collapsePlayer() => value = I4uAudioLibraryFlowState(
        loadState: value.loadState,
        selectedAudioId: value.selectedAudioId,
      );
}
