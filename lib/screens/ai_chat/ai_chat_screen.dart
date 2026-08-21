import 'package:in4up/core/language/app_ui_translations.dart';
import 'package:in4up/core/language/localized_material.dart';
import 'package:in4up_ai/in4up_ai.dart';
import 'package:provider/provider.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send(AiServiceFacade facade) async {
    final text = _controller.text;
    if (text.trim().isEmpty || facade.isChatLoading) return;
    _controller.clear();
    await facade.sendMessage(text);
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B1A),
      appBar: AppBar(
        title: Text(context.uiText('I2U AI Chat')),
        backgroundColor: const Color(0xFF11162A),
        actions: [
          Consumer<AiServiceFacade>(
            builder: (context, facade, _) => IconButton(
              tooltip: context.uiText(
                facade.hasModel
                    ? 'AI model đã sẵn sàng'
                    : 'Import AI model',
              ),
              icon: Icon(
                facade.hasModel
                    ? Icons.memory
                    : Icons.download_for_offline_outlined,
              ),
              onPressed: () async {
                final success = await facade.importModelFromUser();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'AI local đã sẵn sàng.'
                          : 'Chưa import được model .gguf.',
                    ),
                  ),
                );
              },
            ),
          ),
          IconButton(
            tooltip: context.uiText('Xóa cuộc trò chuyện'),
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () => context.read<AiServiceFacade>().clearChat(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<AiServiceFacade>(
              builder: (context, facade, _) {
                final messages = facade.chatMessages;
                if (messages.isEmpty) {
                  return const _EmptyChat();
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                  itemCount: messages.length,
                  itemBuilder: (_, index) =>
                      _MessageBubble(message: messages[index]),
                );
              },
            ),
          ),
          Consumer<AiServiceFacade>(
            builder: (context, facade, _) => SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 5,
                        textInputAction: TextInputAction.newline,
                        onSubmitted: (_) => _send(facade),
                        decoration: InputDecoration(
                          hintText: context.uiText(
                            'Hỏi I2U về từ vựng, ngữ pháp...',
                          ),
                          filled: true,
                          fillColor: const Color(0xFF171D34),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      tooltip: context.uiText('Gửi'),
                      onPressed:
                          facade.isChatLoading ? null : () => _send(facade),
                      icon: facade.isChatLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome,
                  size: 48, color: Color(0xFFB388FF)),
              const SizedBox(height: 16),
              Text(
                context.uiText('Trợ lý học tập I2U'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.uiText(
                  'Đặt câu hỏi về tiếng Anh hoặc nội dung bạn đang học.',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    final display = AppUITranslations.containsSource(message.text)
        ? context.uiText(message.text)
        : message.text;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        decoration: BoxDecoration(
          color: isUser
              ? const Color(0xFF5E4BD8)
              : message.isError
                  ? const Color(0xFF572B35)
                  : const Color(0xFF171D34),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(display),
      ),
    );
  }
}
