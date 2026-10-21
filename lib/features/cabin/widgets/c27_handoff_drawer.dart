import 'package:in4up/core/language/localized_material.dart';

import '../controllers/c27_cabin_live_controller.dart';
import '../controllers/c27_cabin_live_scope.dart';
import '../models/c27_cabin_live_state.dart';
import '../models/cabin_caption.dart';

/// C-27 Handoff Drawer (doc 42 §10.3, doc 43 §6) — bottom sheet chọn ngữ cảnh
/// phiên Cabin để chuyển sang Hiểu/Nhớ. Schema đúng 10 trường do
/// `C27CabinLiveController.openHandoff` đảm nhận; drawer chỉ hiển thị preview
/// và 2 nút đích. Sau khi gửi: về shell (shell tự chuyển tab theo đích).
Future<void> showC27HandoffDrawer(
  BuildContext context, {
  required BuildContext hostContext,
}) async {
  final scope = C27CabinLiveScope.instance;
  final controller = scope.controller;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF101B2B),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => _C27HandoffDrawerSheet(
      controller: controller,
      onSend: (C27SourceType target) {
        controller.openHandoff(target: target, speakerTag: 'Cabin');
        final handoff = controller.activeHandoff;
        if (handoff != null) {
          scope.setHandoff(target, handoff);
        }
        Navigator.of(sheetContext).pop(); // đóng drawer
        Navigator.of(hostContext).pop(); // về shell — shell tự chuyển tab
      },
    ),
  );
}

class _C27HandoffDrawerSheet extends StatefulWidget {
  const _C27HandoffDrawerSheet({
    required this.controller,
    required this.onSend,
  });

  final C27CabinLiveController controller;
  final void Function(C27SourceType target) onSend;

  @override
  State<_C27HandoffDrawerSheet> createState() => _C27HandoffDrawerSheetState();
}

class _C27HandoffDrawerSheetState extends State<_C27HandoffDrawerSheet> {
  String? _selectedCaptionId;

  List<CabinCaption> get _candidates {
    final list = widget.controller.captions
        .where((c) => stageOfCabinCaption(c) == C27CaptionStage.translated)
        .toList();
    // Mới nhất lên đầu, tối đa 8.
    return list.reversed.take(8).toList();
  }

  CabinCaption? get _selected {
    final id = _selectedCaptionId;
    if (id == null) return null;
    for (final c in _candidates) {
      if (c.id == id) return c;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final candidates = _candidates;
    final selected = _selected ?? (candidates.isEmpty ? null : candidates.first);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.forward_to_inbox_rounded,
                    color: Color(0xFF00E676), size: 20),
                const SizedBox(width: 8),
                Text(
                  context.uiText('Chuyển ngữ cảnh Cabin'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              context.uiText('Chọn câu cần chuyển sang Hiểu hoặc Nhớ'),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 12),
            if (candidates.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  context.uiText('Chưa có câu đã dịch — nghe thêm ít nhất một câu.'),
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final c in candidates)
                    ChoiceChip(
                      label: Text(
                        c.sourceText.length > 24
                            ? '${c.sourceText.substring(0, 24)}…'
                            : c.sourceText,
                        style: const TextStyle(fontSize: 11),
                      ),
                      selected: selected?.id == c.id,
                      onSelected: (_) =>
                          setState(() => _selectedCaptionId = c.id),
                      selectedColor: const Color(0xFF00E676),
                      backgroundColor: const Color(0xFF1A1A2E),
                      labelStyle: TextStyle(
                        color: selected?.id == c.id ? Colors.black : Colors.white70,
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selected?.sourceText ?? '',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  if (selected != null && selected.translatedText.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      selected.translatedText,
                      style: const TextStyle(
                          color: Color(0xFF00E676), fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    '${widget.controller.sessionTitle.isEmpty ? 'Cabin Live' : widget.controller.sessionTitle} · ${widget.controller.returnPath}',
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: candidates.isEmpty
                        ? null
                        : () => widget.onSend(C27SourceType.understand),
                    icon: const Icon(Icons.psychology_rounded, size: 18),
                    label: Text(context.uiText('Gửi sang Hiểu')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: candidates.isEmpty
                        ? null
                        : () => widget.onSend(C27SourceType.remember),
                    icon: const Icon(Icons.style_rounded, size: 18),
                    label: Text(context.uiText('Gửi sang Nhớ')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.uiText('Đóng')),
            ),
          ],
        ),
      ),
    );
  }
}
