// lib/features/mascot/widgets/mascot_chat_sheet.dart
//
// MASCOT-004 — Sheet hội thoại của linh vật Sara (PLAN-050 §8).
//
// Lối vào NHANH của cùng bộ não `AiServiceFacade` — hội thoại thấy được ở đây
// và màn AI Chat đầy đủ (nút "Mở AI Chat" đẩy AiChatScreen cũ, KHÔNG thay thế).
// P1: chat chữ + hành động tự thực thi; mic/giọng nói là P2 (MASCOT-005) —
// KHÔNG đặt nút mic giả.
//
// File UI: chỉ import `localized_material.dart` (shim Text — rule #5 AGENTS.md).
// 13 chuỗi chrome mới đã đăng ký đủ en/hi/zh/zh_TW/si trong cùng đợt
// (priority_ui_overrides + generated_legacy_ui_fallbacks + legacy json).

// File UI: chỉ import `localized_material.dart` (re-export material hide Text
// + shim dịch chrome — rule #5 AGENTS.md; import thêm material.dart ⇒ Text
// ambiguous, lỗi compile đã gặp ở P0).

import 'package:in4up_ai/in4up_ai.dart';
import 'package:provider/provider.dart';

import '../../../core/language/localized_material.dart';
import '../../../services/storage_service.dart';
import '../mascot_intent_registry.dart';
import '../mascot_controller.dart';
import '../shell_action_hub.dart';
import 'mascot_bubble.dart';

const Color _kSheetBg = Color(0xFF0B1B2B);
const Color _kCardBg = Color(0xFF12283C);
const Color _kIvory = Color(0xFFF8F4EA);
const Color _kJade = Color(0xFF53D6BD);
const Color _kGold = Color(0xFFF4C95D);

/// Mở sheet hội thoại Sara. Callbacks do main_shell cung cấp (mở palette,
/// đẩy màn AI Chat đầy đủ, ẩn bong bóng).
Future<void> showMascotChatSheet(
  BuildContext context, {
  required VoidCallback onOpenPalette,
  required VoidCallback onOpenFullChat,
  required VoidCallback onHideBubble,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return _MascotChatSheet(
        onOpenPalette: onOpenPalette,
        onOpenFullChat: onOpenFullChat,
        onHideBubble: onHideBubble,
      );
    },
  );
}

class _MascotChatSheet extends StatefulWidget {
  final VoidCallback onOpenPalette;
  final VoidCallback onOpenFullChat;
  final VoidCallback onHideBubble;

  const _MascotChatSheet({
    required this.onOpenPalette,
    required this.onOpenFullChat,
    required this.onHideBubble,
  });

  @override
  State<_MascotChatSheet> createState() => _MascotChatSheetState();
}

class _MascotChatSheetState extends State<_MascotChatSheet> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _listScroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _listScroll.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    context.read<MascotController>().send(text).then((_) {
      if (!mounted) return;
      _scrollToBottom();
      _maybeAnnounceAction();
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_listScroll.hasClients) return;
      _listScroll.animateTo(
        _listScroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  /// Chip "Đã mở" khi Sara vừa tự thực thi một hành động.
  void _maybeAnnounceAction() {
    final controller = context.read<MascotController>();
    final executed = controller.lastExecutedAction;
    if (executed != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          '${context.uiText('Đã mở')}: ${executed.label}',
          style: const TextStyle(color: _kIvory),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _kCardBg,
      ));
      return;
    }
    final error = controller.lastExecutionError;
    if (error != null && error.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          context.uiText('Không chạy được hành động'),
          style: const TextStyle(color: _kIvory),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _kCardBg,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.82,
        decoration: const BoxDecoration(
          color: _kSheetBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          border: Border(top: BorderSide(color: Color(0x4053D6BD))),
        ),
        child: Column(
          children: [
            _buildHeader(),
            Divider(
                height: 1,
                thickness: 1,
                color: Colors.white.withValues(alpha: 0.07)),
            _buildQuickChips(),
            Expanded(child: _buildMessages()),
            _buildInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final surface = context
        .read<MascotController>()
        .sessionContext
        ?.surface;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF163148), Color(0xFF06121E)],
              ),
              border: Border.all(color: _kGold.withValues(alpha: 0.75)),
            ),
            child: const Icon(Icons.eco_outlined, color: _kGold, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Sara',
                      style: const TextStyle(
                        color: _kIvory,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (surface != null && surface.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          surface,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  context.uiText('Quản gia · Gia sư · Hướng dẫn'),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: context.uiText('Mở nhanh'),
            onPressed: () {
              Navigator.of(context).pop();
              widget.onOpenPalette();
            },
            icon: Icon(Icons.manage_search_rounded,
                color: Colors.white.withValues(alpha: 0.7)),
          ),
          Consumer<AiServiceFacade>(
            builder: (context, facade, _) {
              if (facade.chatMessages.isEmpty) {
                return const SizedBox.shrink();
              }
              return IconButton(
                tooltip: context.uiText('Xoá hội thoại'),
                onPressed: () async {
                  await context.read<MascotController>().clear();
                },
                icon: Icon(Icons.delete_outline_rounded,
                    color: Colors.white.withValues(alpha: 0.7)),
              );
            },
          ),
          IconButton(
            tooltip: context.uiText('Ẩn linh vật'),
            onPressed: () {
              Navigator.of(context).pop();
              widget.onHideBubble();
            },
            icon: Icon(Icons.visibility_off_outlined,
                color: Colors.white.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Row(
        children: [
          _chip(
            icon: Icons.auto_stories_rounded,
            label: context.uiText('Ôn từ đến hạn'),
            onTap: () {
              Navigator.of(context).pop();
              final def = MascotIntentRegistry.byId('review');
              if (def != null) {
                ShellActionHub.instance.execute(def).then((_) {
                  StorageService().recordQuickActionUsage(def.id);
                });
              }
            },
          ),
          const SizedBox(width: 8),
          _chip(
            icon: Icons.chat_bubble_outline_rounded,
            label: context.uiText('Mở AI Chat'),
            onTap: () {
              Navigator.of(context).pop();
              widget.onOpenFullChat();
            },
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: _kJade),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: _kIvory.withValues(alpha: 0.9),
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessages() {
    return Consumer2<MascotController, AiServiceFacade>(
      builder: (context, mascot, facade, _) {
        final messages = facade.chatMessages;
        if (messages.isEmpty) {
          return _buildEmpty();
        }
        return ListView.builder(
          controller: _listScroll,
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            return _MessageBubble(message: message);
          },
        );
      },
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF163148), Color(0xFF06121E)],
                ),
                border: Border.all(color: _kGold.withValues(alpha: 0.75)),
              ),
              child: const Icon(Icons.eco_outlined, color: _kGold, size: 32),
            ),
            const SizedBox(height: 14),
            Text(
              context.uiText('Hỏi Sara'),
              style: const TextStyle(
                color: _kIvory,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.uiText(
                  'Sara dùng chung bộ não AI Chat — hội thoại dài nên mở màn AI Chat.'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput() {
    return Consumer<AiServiceFacade>(
      builder: (context, facade, _) {
        final busy = facade.isChatLoading;
        return Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          decoration: BoxDecoration(
            color: _kCardBg.withValues(alpha: 0.6),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  maxLines: 1,
                  style: const TextStyle(color: _kIvory, fontSize: 15),
                  cursorColor: _kJade,
                  decoration: InputDecoration(
                    hintText: busy
                        ? context.uiText('Đang trả lời…')
                        : context.uiText('Nhập câu hỏi…'),
                    hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35)),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (busy)
                IconButton(
                  tooltip: context.uiText('Dừng'),
                  onPressed: () => context.read<MascotController>().stop(),
                  icon: const Icon(Icons.stop_circle_outlined,
                      color: Color(0xFFEF5350), size: 26),
                )
              else
                IconButton(
                  tooltip: context.uiText('Gửi'),
                  onPressed: _send,
                  icon: const Icon(Icons.arrow_upward_rounded,
                      color: _kJade, size: 26),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: message.isError
              ? const Color(0xFF3A1A1A)
              : isUser
                  ? const Color(0xFF1B3A54)
                  : _kCardBg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isUser ? 14 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 14),
          ),
          border: isUser
              ? null
              : Border.all(color: _kJade.withValues(alpha: 0.18)),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: message.isError
                ? const Color(0xFFEF9A9A)
                : _kIvory.withValues(alpha: 0.95),
            fontSize: 14,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}
