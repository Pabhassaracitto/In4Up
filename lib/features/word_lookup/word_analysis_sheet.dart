import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:in4up_ai/in4up_ai.dart';
import '../../features/translation/data/offline_dictionary.dart';
import '../shadowing/services/cmu_dictionary_service.dart';

class WordAnalysisSheet extends StatefulWidget {
  final String selectedWord;
  final String? sentenceContext;

  const WordAnalysisSheet({
    super.key,
    required this.selectedWord,
    this.sentenceContext,
  });

  @override
  State<WordAnalysisSheet> createState() => _WordAnalysisSheetState();
}

class _WordAnalysisSheetState extends State<WordAnalysisSheet> {
  final _dict = OfflineDictionary();

  @override
  void initState() {
    super.initState();
    // Trigger phân tích ngay khi sheet mở
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerAnalysis();
    });
  }

  void _triggerAnalysis() {
    context.read<AiServiceFacade>().analyzeWord(
          word: widget.selectedWord,
          sentenceContext: widget.sentenceContext,
          localDictLookup: _dict.lookup,
          // CMUDictionaryService.getIPA() trả List<String>?
          // Facade tự join thành "/.../" format
          ipaPhoneLookup: (word) {
            // Đảm bảo CMU đã init
            if (!CMUDictionaryService.isInitialized) return null;
            return CMUDictionaryService.getIPA(word);
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    final facade = context.watch<AiServiceFacade>();
    final analysis = facade.currentAnalysis;
    final isLoading = facade.isLoading;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      builder: (context, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            // Header
            _buildHeader(context, facade),

            // Content
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Tầng 1/2: Luôn hiển thị ngay ──
                  _buildMeaningCard(analysis, isLoading),

                  // ── Tầng 3: Hiển thị khi Gemma xong ──
                  if (analysis?.isPartial == false) ...[
                    if (analysis?.visualPrompt != null)
                      _buildVisualPromptCard(analysis!.visualPrompt!),
                    if (analysis?.paoSuggestions.isNotEmpty == true)
                      _buildPaoCard(analysis!.paoSuggestions),
                    if (analysis?.contextExamples.isNotEmpty == true)
                      _buildExamplesCard(analysis!.contextExamples),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AiServiceFacade facade) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.selectedWord,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),

          // Nút báo lỗi AI
          if (facade.currentAnalysis?.isPartial == false)
            IconButton(
              icon: const Icon(Icons.flag_outlined, size: 18),
              tooltip: 'Báo kết quả sai',
              onPressed: () => _reportError(context, facade),
            ),

          // Model status indicator
          if (!facade.hasModel)
            TextButton.icon(
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Cài AI'),
              onPressed: () => _showModelSetupDialog(context, facade),
            ),
        ],
      ),
    );
  }

  Widget _buildMeaningCard(AiAnalysis? analysis, bool isLoading) {
    if (analysis?.wordDetail?.meaning == null && isLoading) {
      // Skeleton loading
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 16,
                width: 120,
                child: LinearProgressIndicator(),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (analysis?.wordDetail?.wordTypeLabel != null)
                  Chip(
                    label: Text(analysis!.wordDetail!.wordTypeLabel!),
                    backgroundColor: Colors.blue.shade100,
                  ),
                const SizedBox(width: 8),
                if (analysis?.wordDetail?.cefrLevel != null)
                  Chip(
                    label: Text(analysis!.wordDetail!.cefrLevel!),
                    backgroundColor: Colors.green.shade100,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              analysis?.wordDetail?.meaning ?? 'Đang tìm kiếm...',
              style: const TextStyle(fontSize: 18),
            ),

            // Source indicator
            if (analysis?.source == AiAnalysisSource.localDict)
              const Text(
                '📖 Từ điển cơ bản',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildIpaCard(String ipa) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.volume_up),
        title: Text(
          ipa,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 18,
            letterSpacing: 2,
          ),
        ),
        subtitle: const Text('Phiên âm IPA'),
      ),
    );
  }

  Widget _buildAnalyzingBadge() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text(
            'AI đang phân tích sâu...',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildVisualPromptCard(String visualPrompt) {
    return Card(
      color: Colors.amber.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🎨 Hình ảnh gợi nhớ',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(visualPrompt),
          ],
        ),
      ),
    );
  }

  Widget _buildPaoCard(List<String> paoSuggestions) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🧠 Câu chuyện PAO (chọn 1)',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...paoSuggestions.asMap().entries.map((entry) => ListTile(
                  leading: CircleAvatar(child: Text('${entry.key + 1}')),
                  title: Text(entry.value),
                  onTap: () {
                    // User chọn PAO story → lưu vào vocab
                  },
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildExamplesCard(List<String> examples) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📝 Ví dụ trong ngữ cảnh',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...examples.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text('• $e'),
                )),
          ],
        ),
      ),
    );
  }

  void _reportError(BuildContext context, AiServiceFacade facade) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Báo lỗi AI'),
        content: const Text('Kết quả AI không chính xác?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              // Lấy error log từ facade
              facade.reportError(reason: 'User reported incorrect');
              // TODO: Lưu log vào in4up_storage
              // context.read<StorageService>().saveErrorLog(log);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã ghi nhận. Cảm ơn bạn!')),
              );
            },
            child: const Text('Báo lỗi'),
          ),
        ],
      ),
    );
  }

  void _showModelSetupDialog(BuildContext context, AiServiceFacade facade) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cài đặt AI Model'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Chọn cách lấy AI model:'),
            const SizedBox(height: 8),
            const Text('• assets/models/: Tự động nếu đã bundle'),
            const Text('• Import file: Chọn file .gguf từ thiết bị'),
            const SizedBox(height: 8),
            const Text(
              'Khuyến nghị: gemma-2b-it-q4_k_m.gguf (~1.5GB)',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Để sau'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await facade.importModelFromUser();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success ? '✅ Model đã sẵn sàng!' : '❌ Import thất bại',
                    ),
                  ),
                );
              }
            },
            child: const Text('Chọn file .gguf'),
          ),
        ],
      ),
    );
  }
}
