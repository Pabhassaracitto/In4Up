import 'package:flutter/foundation.dart';

enum I4uAudioRecoveryAction { retry, chooseFile, useCachedLibrary, openSettings, dismiss }

enum I4uAudioErrorKind { importFailed, missingFile, permissionDenied, offline, unsupportedFormat, unknown }

@immutable
class I4uAudioRecoveryState {
  const I4uAudioRecoveryState({
    required this.kind,
    required this.message,
    this.canUseCache = false,
  });

  final I4uAudioErrorKind kind;
  final String message;
  final bool canUseCache;

  List<I4uAudioRecoveryAction> get actions {
    switch (kind) {
      case I4uAudioErrorKind.permissionDenied:
        return const [I4uAudioRecoveryAction.openSettings, I4uAudioRecoveryAction.dismiss];
      case I4uAudioErrorKind.offline:
        return canUseCache
            ? const [I4uAudioRecoveryAction.useCachedLibrary, I4uAudioRecoveryAction.dismiss]
            : const [I4uAudioRecoveryAction.retry, I4uAudioRecoveryAction.dismiss];
      case I4uAudioErrorKind.unsupportedFormat:
        return const [I4uAudioRecoveryAction.chooseFile, I4uAudioRecoveryAction.dismiss];
      default:
        return const [I4uAudioRecoveryAction.retry, I4uAudioRecoveryAction.dismiss];
    }
  }
}
