import '../../models/reader_contextual_panel_state.dart';

/// Keeps Reader UX ownership separate from feature implementations discovered
/// in the baseline branch. The shell decides placement; these callbacks decide
/// what capability to invoke.
class I4uReaderContextualActionOrchestrator {
  const I4uReaderContextualActionOrchestrator({
    this.onDictionary,
    this.onNote,
    this.onRemember,
    this.onExplain,
    this.onPlayAudio,
    this.onBookmark,
  });

  final Future<void> Function(I4uReaderSelectionContext context)? onDictionary;
  final Future<void> Function(I4uReaderSelectionContext context)? onNote;
  final Future<void> Function(I4uReaderSelectionContext context)? onRemember;
  final Future<void> Function(I4uReaderSelectionContext context)? onExplain;
  final Future<void> Function(I4uReaderSelectionContext context)? onPlayAudio;
  final Future<void> Function(I4uReaderSelectionContext context)? onBookmark;

  Future<bool> dispatch(
    I4uReaderContextAction action,
    I4uReaderSelectionContext context,
  ) async {
    final callback = switch (action) {
      I4uReaderContextAction.dictionary => onDictionary,
      I4uReaderContextAction.note => onNote,
      I4uReaderContextAction.remember => onRemember,
      I4uReaderContextAction.explain => onExplain,
      I4uReaderContextAction.playAudio => onPlayAudio,
      I4uReaderContextAction.bookmark => onBookmark,
    };
    if (callback == null) return false;
    await callback(context);
    return true;
  }
}
