// lib/features/understand_ai/understand_ai_coach_sheet.dart
//
// I4U — Prompt Agent 2: sheet "Trợ lý hiểu bài" (action trong header workspace
// tab Hiểu, KHÔNG phải mode thứ ba).
//
// Nguyên tắc:
//   1. Sheet là SNAPSHOT: nhận UnderstandAiContext + lines sẵn có, không đọc
//      provider khi mở — đóng sheet/chat không thể làm mất audio position,
//      current line, mode Đồng bộ/Shadowing hay state UnderstandProvider.
//   2. Trước khi gửi, context hiện rõ trong card "Ngữ cảnh sẽ gửi cho AI".
//   3. Không ghi âm, không upload audio — toàn bộ flow chỉ làm việc với text.
//   4. Quick action → mở lại AiChatScreen hiện có với nháp câu hỏi; người
//      dùng thấy và sửa được trước khi bấm gửi.

import 'package:flutter/material.dart';
import 'package:in4up/core/language/localized_material.dart';

import '../../screens/ai_chat/ai_chat_screen.dart';
import 'understand_ai_context.dart';
import 'understand_ai_prompts.dart';

/// Callback khi người dùng bấm một quick action (optional — thay cho hành vi
/// mặc định là mở AiChatScreen với nháp câu hỏi).
typedef UnderstandAiAskCallback = void Function(
  UnderstandAiQuickAction action,
  UnderstandAiContext aiContext,
);

/// Mở sheet "Trợ lý hiểu bài".
///
/// [onAsk]/[onOpenChat] là callback optional (dùng cho test / caller đặc
/// biệt). Mặc định: đóng sheet rồi push [AiChatScreen] kèm context + nháp.
Future<void> showUnderstandAiCoachSheet({
  required BuildContext context,
  required UnderstandAiContext aiContext,
  List<String> lines = const [],
  UnderstandAiAskCallback? onAsk,
  VoidCallback? onOpenChat,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF1A1A2E),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => UnderstandAiCoachSheet(
      aiContext: aiContext,
      lines: lines,
      onAsk: onAsk,
      onOpenChat: onOpenChat,
    ),
  );
}

class UnderstandAiCoachSheet extends StatefulWidget {
  final UnderstandAiContext aiContext;

  /// Toàn bộ dòng lyric của bài (text thuần) — để người dùng dịch chuyển
  /// câu đang hỏi bằng ◀ ▶ mà không đụng vào player.
  final List<String> lines;

  /// Optional: thay hành vi mặc định (push AiChatScreen) khi bấm quick action.
  final UnderstandAiAskCallback? onAsk;

  /// Optional: thay hành vi mặc định khi bấm "Mở AI Chat".
  final VoidCallback? onOpenChat;

  const UnderstandAiCoachSheet({
    super.key,
    required this.aiContext,
    required this.lines,
    this.onAsk,
    this.onOpenChat,
  });

  @override
  State<UnderstandAiCoachSheet> createState() => _UnderstandAiCoachSheetState();
}

class _UnderstandAiCoachSheetState extends State<UnderstandAiCoachSheet> {
  late int _focusIndex;

  @override
  void initState() {
    super.initState();
    // Mặc định hỏi về dòng đang phát; audio chưa chạy thì về dòng đầu.
    _focusIndex =
        widget.aiContext.focusLineIndex ?? (widget.lines.isEmpty ? -1 : 0);
  }

  UnderstandAiContext _currentContext() {
    return UnderstandAiContext.fromLineTexts(
      lines: widget.lines,
      currentLineIndex: widget.aiContext.currentLineIndex ?? -1,
      focusLineIndex: _focusIndex,
      sourceTitle: widget.aiContext.sourceTitle,
      learningMode: widget.aiContext.learningMode,
      targetLanguage: widget.aiContext.targetLanguage,
      learnerLevel: widget.aiContext.learnerLevel,
    );
  }

  void _moveFocus(int delta) {
    final next = _focusIndex + delta;
    if (next < 0 || next >= widget.lines.length) return;
    setState(() => _focusIndex = next);
  }

  // Đóng sheet rồi mở chat. Navigator được giữ TRƯỚC khi pop để không phải
  // giữ context của sheet sau khi nó bị dispose.
  void _handleAsk(UnderstandAiQuickAction action) {
    final aiContext = _currentContext();
    final prompt = buildUnderstandQuickPrompt(action, aiContext);
    final callback = widget.onAsk;
    final navigator = Navigator.of(context);
    navigator.pop();
    if (callback != null) {
      callback(action, aiContext);
      return;
    }
    navigator.push(
      MaterialPageRoute(
        builder: (_) => AiChatScreen(context: aiContext, initialDraft: prompt),
      ),
    );
  }

  void _handleOpenChat() {
    final aiContext = _currentContext();
    final callback = widget.onOpenChat;
    final navigator = Navigator.of(context);
    navigator.pop();
    if (callback != null) {
      callback();
      return;
    }
    navigator.push(
      MaterialPageRoute(builder: (_) => AiChatScreen(context: aiContext)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final aiContext = _currentContext();
    // Quick action cần lyric thì chỉ bật khi context có text; gợi ý luôn bật.
    bool enabledFor(UnderstandAiQuickAction action) =>
        !action.requiresLyrics || aiContext.hasText;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.psychology_outlined,
                    color: Color(0xFFB388FF),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.uiText('Trợ lý hiểu bài'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: context.uiText('Đóng'),
                    icon: const Icon(Icons.close, size: 20),
                    color: Colors.white54,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              _ContextPreviewCard(
                aiContext: aiContext,
                lines: widget.lines,
                focusIndex: _focusIndex,
                onMoveFocus: _moveFocus,
              ),
              const SizedBox(height: 14),
              _QuickActionTile(
                icon: Icons.lightbulb_outline,
                label: context.uiText('Giải thích câu này'),
                color: const Color(0xFFB388FF),
                enabled: enabledFor(UnderstandAiQuickAction.explainSentence),
                onTap: () => _handleAsk(
                  UnderstandAiQuickAction.explainSentence,
                ),
              ),
              const SizedBox(height: 8),
              _QuickActionTile(
                icon: Icons.summarize_outlined,
                label: context.uiText('Tóm tắt đoạn vừa nghe'),
                color: const Color(0xFF7DD3FC),
                enabled: enabledFor(UnderstandAiQuickAction.summarizeRecent),
                onTap: () => _handleAsk(
                  UnderstandAiQuickAction.summarizeRecent,
                ),
              ),
              const SizedBox(height: 8),
              _QuickActionTile(
                icon: Icons.quiz_outlined,
                label: context.uiText('Kiểm tra hiểu bài'),
                color: const Color(0xFF4ADE80),
                enabled: enabledFor(UnderstandAiQuickAction.checkComprehension),
                onTap: () => _handleAsk(
                  UnderstandAiQuickAction.checkComprehension,
                ),
              ),
              const SizedBox(height: 8),
              _QuickActionTile(
                icon: Icons.tips_and_updates_outlined,
                label: context.uiText('Cho tôi một gợi ý'),
                color: const Color(0xFFFFB300),
                enabled: enabledFor(UnderstandAiQuickAction.giveHint),
                onTap: () => _handleAsk(UnderstandAiQuickAction.giveHint),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: _handleOpenChat,
                  icon: const Icon(Icons.chat_bubble_outline, size: 16),
                  label: Text(context.uiText('Mở AI Chat')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card hiển thị NGUYÊN VĂN những gì sẽ gửi cho AI — người dùng thấy trước
/// khi bấm bất kỳ quick action nào.
class _ContextPreviewCard extends StatelessWidget {
  final UnderstandAiContext aiContext;
  final List<String> lines;
  final int focusIndex;
  final void Function(int delta) onMoveFocus;

  const _ContextPreviewCard({
    required this.aiContext,
    required this.lines,
    required this.focusIndex,
    required this.onMoveFocus,
  });

  @override
  Widget build(BuildContext context) {
    final modeLabel = aiContext.learningMode == UnderstandLearningMode.shadowing
        ? 'Shadowing'
        : context.uiText('Đồng bộ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF11162A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFB388FF).withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.article_outlined,
                size: 14,
                color: Color(0xFF7DD3FC),
              ),
              const SizedBox(width: 6),
              Text(
                context.uiText('Ngữ cảnh sẽ gửi cho AI'),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _ContextChip(
                icon: aiContext.learningMode ==
                        UnderstandLearningMode.shadowing
                    ? Icons.record_voice_over
                    : Icons.sync,
                label: modeLabel,
              ),
              if (aiContext.focusLineIndex != null)
                _ContextChip(
                  icon: Icons.format_list_numbered,
                  label: context.uiText(
                    'Dòng ${aiContext.focusLineIndex! + 1}',
                  ),
                ),
            ],
          ),
          if (aiContext.sourceTitle != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.audiotrack_outlined,
                  size: 12,
                  color: Colors.white38,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    aiContext.sourceTitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          if (lines.isEmpty)
            Text(
              context.uiText('Chưa có câu nào đang phát'),
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            )
          else
            Row(
              children: [
                _StepperButton(
                  tooltip: context.uiText('Câu trước'),
                  icon: Icons.chevron_left,
                  onPressed: focusIndex > 0 ? () => onMoveFocus(-1) : null,
                ),
                Expanded(
                  child: Text(
                    aiContext.selectedText ?? '',
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
                _StepperButton(
                  tooltip: context.uiText('Câu kế tiếp'),
                  icon: Icons.chevron_right,
                  onPressed: focusIndex < lines.length - 1
                      ? () => onMoveFocus(1)
                      : null,
                ),
              ],
            ),
          if (aiContext.surroundingText != null) ...[
            const SizedBox(height: 6),
            Text(
              aiContext.surroundingText!,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.lock_outline,
                size: 12,
                color: Color(0xFF4ADE80),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  context.uiText(
                    'Chỉ gửi đoạn văn bản này — không gửi audio, không tự ghi âm.',
                  ),
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Nút ◀ ▶ nhỏ gọn cho việc chọn câu hỏi trong card ngữ cảnh.
class _StepperButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  const _StepperButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon),
      iconSize: 18,
      color: Colors.white54,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      onPressed: onPressed,
    );
  }
}

class _ContextChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ContextChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white54),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.38,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.22)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
