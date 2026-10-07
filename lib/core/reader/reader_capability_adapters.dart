import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../models/reader_contextual_panel_state.dart';
import '../../models/vocab_context.dart';
import '../../providers/text_provider.dart';
import '../../screens/read_mode/controllers/read_mode_controller.dart';
import '../../widgets/selection_save_sheet.dart';
import 'reader_remember_handoff.dart';
import 'semantic_bookmark_resolver.dart';

class I4uReaderCapabilityAdapters {
  const I4uReaderCapabilityAdapters._();

  static Future<void> remember(
    BuildContext context,
    I4uRememberHandoff handoff,
  ) {
    final tp = context.read<TextProvider>();
    final title = tp.currentDocument?.title ?? 'Đọc';
    return SelectionSaveSheet.show(
      context,
      text: handoff.text,
      sourceLabel: title,
      contextBuilder: (sample) => VocabContext.fromStory(
        storyTitle: title,
        lineIndex: -1,
        surroundingText: handoff.text,
        sourceRef: tp.currentContextSourceRef,
        sourceRefType: tp.currentContextSourceRefType,
        anchorText: sample,
      ),
    );
  }

  static bool bookmark(
    ReadModeController controller,
    I4uReaderSelectionContext selection,
    List<String> lines,
  ) {
    final target = const I4uSemanticBookmarkResolver().resolve(
      selection: selection,
      lines: lines,
    );
    if (target == null) return false;
    controller.bookmarkLine(target.lineIndex);
    return true;
  }
}
