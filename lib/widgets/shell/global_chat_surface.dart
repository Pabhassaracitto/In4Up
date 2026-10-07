import 'package:flutter/material.dart';

class I4uGlobalChatSurface extends StatefulWidget {
  const I4uGlobalChatSurface({
    super.key,
    this.contextLabel,
    required this.onSend,
    this.onResetContext,
  });

  final String? contextLabel;
  final Future<String> Function(String message) onSend;
  final VoidCallback? onResetContext;

  @override
  State<I4uGlobalChatSurface> createState() => _I4uGlobalChatSurfaceState();
}

class _I4uGlobalChatSurfaceState extends State<I4uGlobalChatSurface> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <({bool user, String text})>[];
  bool _sending = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    _input.clear();
    setState(() {
      _messages.add((user: true, text: text));
      _sending = true;
    });
    try {
      final reply = await widget.onSend(text);
      if (!mounted) return;
      setState(() => _messages.add((user: false, text: reply)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _messages.add((user: false, text: 'Không thể gửi lúc này. Hãy thử lại.')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('Global Chat'),
              subtitle: Text(widget.contextLabel ?? 'Không có source context'),
              trailing: widget.contextLabel == null || widget.onResetContext == null
                  ? null
                  : IconButton(
                      tooltip: 'Đổi context',
                      icon: const Icon(Icons.refresh),
                      onPressed: widget.onResetContext,
                    ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _messages.isEmpty
                  ? const Center(child: Text('Đặt câu hỏi để bắt đầu.'))
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (_, index) {
                        final message = _messages[index];
                        return Align(
                          alignment: message.user ? Alignment.centerRight : Alignment.centerLeft,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(message.text),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(hintText: 'Viết câu hỏi…'),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Gửi',
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
