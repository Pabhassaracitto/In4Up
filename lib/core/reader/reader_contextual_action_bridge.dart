import 'package:flutter/widgets.dart';

import '../../models/reader_contextual_panel_state.dart';
import '../../screens/read_mode/services/read_text_action_runner.dart';
import '../../screens/read_mode/widgets/read_text_action_hooks.dart';
import 'reader_contextual_action_orchestrator.dart';

/// Maps the new contextual panel to existing Reader capabilities without
/// importing the old toolbar layout into the new shell.
class I4uReaderContextualActionBridge {
  const I4uReaderContextualActionBridge({
    required this.context,
    this.onNote,
    this.onRemember,
    this.onBookmark,
  });

  final BuildContext context;
  final Future<void> Function(I4uReaderSelectionContext selection)? onNote;
  final Future<void> Function(I4uReaderSelectionContext selection)? onRemember;
  final Future<void> Function(I4uReaderSelectionContext selection)? onBookmark;

  I4uReaderContextualActionOrchestrator build() {
    return I4uReaderContextualActionOrchestrator(
      onDictionary: (selection) => _run(selection, ReadTextAction.dictionary),
      onExplain: (selection) => _run(selection, ReadTextAction.grammar),
      onPlayAudio: (selection) => _run(selection, ReadTextAction.pronounce),
      onNote: onNote,
      onRemember: onRemember,
      onBookmark: onBookmark,
    );
  }

  Future<void> _run(
    I4uReaderSelectionContext selection,
    ReadTextAction action,
  ) => ReadTextActionRunner.run(context, action, selectedText: selection.text);
}
