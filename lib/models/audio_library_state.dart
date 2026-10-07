import 'package:flutter/foundation.dart';

import 'i4u_shell_contracts.dart';

enum I4uAudioLibraryLoadState { idle, loading, ready, empty, importing, offline, error }

@immutable
class I4uAudioLibraryState {
  const I4uAudioLibraryState({
    this.loadState = I4uAudioLibraryLoadState.idle,
    this.selectedAudioId,
    this.currentSource,
    this.importProgress,
    this.errorMessage,
  });

  final I4uAudioLibraryLoadState loadState;
  final String? selectedAudioId;
  final I4uSourceFingerprint? currentSource;
  final double? importProgress;
  final String? errorMessage;

  bool get canRetry => loadState == I4uAudioLibraryLoadState.error || loadState == I4uAudioLibraryLoadState.offline;
  bool get isImporting => loadState == I4uAudioLibraryLoadState.importing;
  bool get hasSelection => selectedAudioId != null;
}
