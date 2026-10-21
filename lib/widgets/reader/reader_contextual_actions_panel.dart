import 'package:flutter/material.dart';

import '../../models/reader_contextual_panel_state.dart';

class I4uReaderContextualActionsPanel extends StatelessWidget {
  const I4uReaderContextualActionsPanel({
    super.key,
    required this.state,
    required this.onAction,
    required this.onClose,
  });

  final I4uReaderContextualPanelState state;
  final ValueChanged<I4uReaderContextAction> onAction;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    if (state.mode == I4uReaderContextPanelMode.closed || !state.hasSelection) {
      return const SizedBox.shrink();
    }
    final actions = [
      (I4uReaderContextAction.dictionary, Icons.menu_book_outlined, 'Tra từ'),
      (I4uReaderContextAction.note, Icons.edit_note_outlined, 'Ghi chú'),
      (I4uReaderContextAction.remember, Icons.psychology_outlined, 'Nhớ'),
      (I4uReaderContextAction.explain, Icons.lightbulb_outline, 'Giải thích'),
      (I4uReaderContextAction.playAudio, Icons.volume_up_outlined, 'Nghe'),
      (I4uReaderContextAction.bookmark, Icons.bookmark_border, 'Đánh dấu'),
    ];
    final content = Material(
      color: const Color(0xFF1A1A2E),
      elevation: 12,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final action in actions)
              Semantics(
                button: true,
                label: action.$3,
                enabled: state.canRunAction,
                child: ActionChip(
                  avatar: Icon(action.$2, size: 18),
                  label: Text(action.$3),
                  onPressed: state.canRunAction ? () => onAction(action.$1) : null,
                ),
              ),
            IconButton(
              tooltip: 'Đóng công cụ văn bản',
              onPressed: onClose,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
    if (state.mode == I4uReaderContextPanelMode.mobileSheet) {
      return SafeArea(top: false, child: Align(alignment: Alignment.bottomCenter, child: content));
    }
    return Align(alignment: Alignment.centerRight, child: SizedBox(width: 320, child: content));
  }
}
