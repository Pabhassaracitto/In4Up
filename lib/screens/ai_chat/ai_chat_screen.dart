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
    if (text.trim().isEmpty) return;
    _controller.clear();
    // KHÔNG bỏ tin khi AI đang trả lời (AI-CHAT-01 DoD #3): facade xếp hàng và
    // isolate native xử lý tuần tự — bản cũ `return` sớm nên tin thứ hai bị
    // nuốt mất, còn nút gửi bị khoá nên người dùng tưởng chat "đơ".
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

  /// Import model + snackbar kết quả rõ ràng (tên file, dung lượng, lỗi thật).
  Future<void> _importModel(BuildContext context, AiServiceFacade facade) async {
    final success = await facade.importModelFromUser();
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (success) {
      final name = facade.modelFileName ?? '';
      final sizeMb = facade.modelSizeBytes != null
          ? (facade.modelSizeBytes! / (1024 * 1024)).toStringAsFixed(0)
          : null;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            context.uiText('AI local đã sẵn sàng') +
                (name.isNotEmpty ? ' — $name' : '') +
                (sizeMb != null ? ' ($sizeMb MB)' : ''),
          ),
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            facade.importError ?? context.uiText('Chưa import được model .gguf.'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B1A),
      appBar: AppBar(
        title: Text(context.uiText('I4U AI Chat')),
        backgroundColor: const Color(0xFF11162A),
        actions: [
          Consumer<AiServiceFacade>(
            builder: (context, facade, _) => IconButton(
              tooltip: context.uiText(
                facade.hasModel
                    ? 'AI model đã sẵn sàng'
                    : 'Import AI model',
              ),
              icon: facade.isImportActive
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      // Có FILE model (dù engine đang nạp/lỗi) ⇒ không hiện
                      // icon "tải về" như thể chưa có gì.
                      facade.hasModel || facade.hasModelFile
                          ? Icons.memory
                          : Icons.download_for_offline_outlined,
                    ),
              onPressed: facade.isImportActive
                  ? null
                  : () => _importModel(context, facade),
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
          // Trạng thái model LUÔN HIỆN — hết cảnh "nạp chưa mà không biết".
          Consumer<AiServiceFacade>(
            builder: (context, facade, _) =>
                _ModelStatusBanner(facade: facade),
          ),
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
                      // Vẫn bấm được khi AI đang trả lời: tin sẽ vào hàng đợi
                      // của facade (chỉ spinner đổi để biết đang xử lý).
                      onPressed: () => _send(facade),
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

/// Banner trạng thái model — các trạng thái rõ ràng:
///   - chưa có model: vàng, bấm được để import
///   - đang copy file: progress 0–100%
///   - đang tải (URL): progress 0–100%
///   - engine lỗi / bị OOM thu hồi: đỏ + "Thử lại" (khởi động lại engine)
///   - đang nạp native: spinner (1–2 phút với file lớn)
///   - sẵn sàng: xanh + tên file + dung lượng
///
/// AI-CHAT-01 (audit B3): "Chưa nạp model AI — import file .gguf" chỉ được
/// hiện khi THẬT SỰ không có file model. Đang generate (state=processing),
/// đang nạp lại sau timeout hay engine vừa bị thu hồi đều KHÔNG được rơi vào
/// nhánh vàng đó — đó chính là cảnh "banner xanh nhảy vàng ngay sau khi gửi".
class _ModelStatusBanner extends StatelessWidget {
  final AiServiceFacade facade;
  const _ModelStatusBanner({required this.facade});

  @override
  Widget build(BuildContext context) {
    final ui = context.uiText;

    // 1) Đang copy file đã chọn
    if (facade.importStage == AiImportStage.copying) {
      final pct = (facade.importProgress * 100).toStringAsFixed(0);
      return _banner(
        color: const Color(0xFF1A2440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Text('${ui('Đang copy model…')} $pct%',
                  style: const TextStyle(fontSize: 12)),
            ),
            LinearProgressIndicator(
              value: facade.importProgress,
              minHeight: 4,
            ),
          ],
        ),
      );
    }

    // 2) Đang tải từ URL
    if (facade.importStage == AiImportStage.downloading) {
      final pct = (facade.importProgress * 100).toStringAsFixed(0);
      return _banner(
        color: const Color(0xFF1A2440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Text('${ui('Đang tải model…')} $pct%',
                  style: const TextStyle(fontSize: 12)),
            ),
            LinearProgressIndicator(
              value: facade.importProgress,
              minHeight: 4,
            ),
          ],
        ),
      );
    }

    // 3) Engine lỗi / bị OOM thu hồi / khởi động lại thất bại — đỏ + "Thử lại".
    // Đứng TRƯỚC nhánh "đang nạp" vì có file model nhưng engine không dùng
    // được thì "đang nạp" sẽ che mất lỗi thật. Trong lúc đang khởi động lại
    // thì KHÔNG hiện lỗi (đang nạp lại — xem nhánh 5).
    if (facade.engineError != null && !facade.isEngineRestarting) {
      return _banner(
        color: const Color(0xFF3A1A22),
        onTap: () => _retryEngine(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            children: [
              const Icon(Icons.error_outline,
                  size: 18, color: Color(0xFFFF8A9E)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${ui('Lỗi')}: ${facade.engineError ?? ''}',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFFFFC2CE)),
                ),
              ),
              TextButton(
                onPressed: () => _retryEngine(context),
                child: Text(ui('Thử lại')),
              ),
            ],
          ),
        ),
      );
    }

    // 4) Native đang nạp model
    if (facade.importStage == AiImportStage.loading || facade.isModelLoading) {
      return _banner(
        color: const Color(0xFF1A2440),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  ui(
                      'Đang nạp model vào bộ nhớ — có thể mất 1–2 phút cho file lớn'),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 5) Lỗi import / tải model
    if (facade.importStage == AiImportStage.failed) {
      return _banner(
        color: const Color(0xFF3A1A22),
        onTap: () => _retryImport(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            children: [
              const Icon(Icons.error_outline,
                  size: 18, color: Color(0xFFFF8A9E)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${ui('Lỗi')}: ${facade.importError ?? ''}',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFFFFC2CE)),
                ),
              ),
              TextButton(
                onPressed: () => _retryImport(context),
                child: Text(ui('Thử lại')),
              ),
            ],
          ),
        ),
      );
    }

    // 6) Model sẵn sàng
    if (facade.hasModel) {
      final name = facade.modelFileName ?? '';
      final sizeMb = facade.modelSizeBytes != null
          ? (facade.modelSizeBytes! / (1024 * 1024)).toStringAsFixed(0)
          : null;
      return _banner(
        color: const Color(0xFF10301F),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              const Icon(Icons.check_circle,
                  size: 18, color: Color(0xFF4ADE80)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ui('Model AI đã nạp') +
                      (name.isNotEmpty ? ' — $name' : '') +
                      (sizeMb != null ? ' ($sizeMb MB)' : ''),
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFFA7F3C4)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 7) Có file model nhưng engine chưa sẵn sàng (đang nạp lại / vừa bị thu
    // hồi nhưng chưa phát hiện lỗi). Tuyệt đối KHÔNG rơi xuống nhánh vàng
    // "Chưa nạp model AI" — model đã import rồi.
    if (facade.hasModelFile) {
      return _banner(
        color: const Color(0xFF1A2440),
        onTap: () => _retryEngine(context),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  ui(
                      'Đang nạp model vào bộ nhớ — có thể mất 1–2 phút cho file lớn'),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              TextButton(
                onPressed: () => _retryEngine(context),
                child: Text(ui('Thử lại')),
              ),
            ],
          ),
        ),
      );
    }

    // 8) Chưa có model — bấm để import
    return _banner(
      color: const Color(0xFF33270F),
      onTap: () => _retryImport(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(
          children: [
            const Icon(Icons.cloud_off,
                size: 18, color: Color(0xFFFFC971)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                ui('Chưa nạp model AI — import file .gguf (Gemma ~1.5GB)'),
                style:
                    const TextStyle(fontSize: 12, color: Color(0xFFFFE7B3)),
              ),
            ),
            TextButton(
              onPressed: () => _retryImport(context),
              child: Text(ui('Import')),
            ),
          ],
        ),
      ),
    );
  }

  /// "Thử lại" cho lỗi ENGINE (AI process bị OOM thu hồi / native treo):
  /// khởi động lại engine với model đã có — KHÔNG mở file picker bắt người
  /// dùng chọn lại file 1.5GB (AI-CHAT-01 DoD: "báo lỗi retry được").
  Future<void> _retryEngine(BuildContext context) async {
    final facade = context.read<AiServiceFacade>();
    await facade.restartEngine(reason: facade.engineError);
  }

  /// "Thử lại" cho lỗi IMPORT/TẢI model — giữ nguyên luồng cũ (MODELS-002).
  Future<void> _retryImport(BuildContext context) async {
    await context.read<AiServiceFacade>().importModelFromUser();
  }

  Widget _banner({
    required Color color,
    required Widget child,
    VoidCallback? onTap,
  }) {
    final base = Container(
      width: double.infinity,
      color: color,
      child: child,
    );
    if (onTap == null) return base;
    return GestureDetector(onTap: onTap, child: base);
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
