import 'package:in4up/core/language/localized_material.dart';
import 'package:in4up_ai/in4up_ai.dart';
import 'package:provider/provider.dart';

import '../features/dictionary/services/dictionary_service.dart';
import '../features/shadowing/services/cmu_dictionary_service.dart';
import '../services/ipa_resolver.dart';
import '../services/syntax_highlighter_service.dart';

class VocabQuickSaveData {
  final String meaning;
  final String phonetic;
  final String example;

  const VocabQuickSaveData({
    required this.meaning,
    required this.phonetic,
    required this.example,
  });
}

/// Compact detail form for saving one item from Read mode.
///
/// The current reading sentence is prefilled as an example. "Smart fill"
/// supplements only blank fields from local lookup/IPA sources and, when a
/// local model is available, AI analysis; it never replaces typed content.
class VocabQuickSaveSheet extends StatefulWidget {
  final String word;
  final String meaning;
  final String phonetic;
  final String example;
  final String sourceContext;

  const VocabQuickSaveSheet({
    super.key,
    required this.word,
    this.meaning = '',
    this.phonetic = '',
    this.example = '',
    this.sourceContext = '',
  });

  static Future<VocabQuickSaveData?> show(
    BuildContext context, {
    required String word,
    String meaning = '',
    String phonetic = '',
    String example = '',
    String sourceContext = '',
  }) {
    return showModalBottomSheet<VocabQuickSaveData>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => VocabQuickSaveSheet(
        word: word,
        meaning: meaning,
        phonetic: phonetic,
        example: example,
        sourceContext: sourceContext,
      ),
    );
  }

  @override
  State<VocabQuickSaveSheet> createState() => _VocabQuickSaveSheetState();
}

class _VocabQuickSaveSheetState extends State<VocabQuickSaveSheet> {
  late final TextEditingController _meaningCtrl;
  late final TextEditingController _phoneticCtrl;
  late final TextEditingController _exampleCtrl;
  bool _isSuggesting = false;

  @override
  void initState() {
    super.initState();
    _meaningCtrl = TextEditingController(text: widget.meaning);
    _phoneticCtrl = TextEditingController(text: widget.phonetic);
    final example = widget.example.trim().isNotEmpty
        ? widget.example
        : widget.sourceContext;
    _exampleCtrl = TextEditingController(text: example);
  }

  @override
  void dispose() {
    _meaningCtrl.dispose();
    _phoneticCtrl.dispose();
    _exampleCtrl.dispose();
    super.dispose();
  }

  Future<void> _suggestMissingFields() async {
    if (_isSuggesting) return;
    setState(() => _isSuggesting = true);

    var meaning = _meaningCtrl.text.trim();
    var phonetic = _phoneticCtrl.text.trim();
    var example = _exampleCtrl.text.trim();

    try {
      final local = SyntaxHighlighterService.instance.analyzeWord(widget.word);
      if (meaning.isEmpty) meaning = (local.meaning ?? '').trim();
      if (phonetic.isEmpty) phonetic = (local.phonetic ?? '').trim();
      if (example.isEmpty) {
        example = widget.sourceContext.trim().isNotEmpty
            ? widget.sourceContext.trim()
            : (local.example ?? '').trim();
      }
      if (meaning.isEmpty) {
        try {
          final entries = await DictionaryService.instance.lookup(widget.word);
          for (final entry in entries) {
            final definition = entry.plainDefinition.trim();
            if (definition.isEmpty) continue;
            meaning = definition.length > 240
                ? '${definition.substring(0, 237).trimRight()}…'
                : definition;
            break;
          }
        } catch (_) {
          // A dictionary that is not installed should not block quick save.
        }
      }

      // MDX lookup is a light first attempt. The normal save path can still run
      // the configured MDX → CMU → G2P waterfall in the background.
      if (phonetic.isEmpty) {
        try {
          final resolution = await IpaResolver.resolve(
            widget.word,
            mode: IpaSaveMode.dict,
          );
          phonetic = resolution?.ipa ?? '';
        } catch (_) {
          // A dictionary that is not installed should not block quick save.
        }
      }

      try {
        final facade = context.read<AiServiceFacade>();
        if (facade.hasModel) {
          await facade.analyzeWord(
            word: widget.word,
            sentenceContext: widget.sourceContext,
            localDictLookup: (word) =>
                SyntaxHighlighterService.instance.analyzeWord(word).meaning,
            ipaPhoneLookup: (word) => CMUDictionaryService.getIPA(word),
          );
          final analysis = facade.currentAnalysis;
          final detail = analysis?.wordDetail;
          if (meaning.isEmpty) meaning = (detail?.meaning ?? '').trim();
          if (phonetic.isEmpty) phonetic = (detail?.phonetic ?? '').trim();
          if (example.isEmpty) {
            final examples = analysis?.contextExamples ?? const <String>[];
            example = _bestExample(examples, widget.word) ??
                (detail?.memoryHook ?? '').trim();
          }
        }
      } catch (_) {
        // AI is optional; local dictionary and source context remain available.
      }
    } catch (_) {
      // Smart fill is best-effort; the user's current values remain untouched.
    } finally {
      if (mounted) {
        setState(() {
          if (_meaningCtrl.text.trim().isEmpty && meaning.isNotEmpty) {
            _meaningCtrl.text = meaning;
          }
          if (_phoneticCtrl.text.trim().isEmpty && phonetic.isNotEmpty) {
            _phoneticCtrl.text = phonetic;
          }
          if (_exampleCtrl.text.trim().isEmpty && example.isNotEmpty) {
            _exampleCtrl.text = example;
          }
          _isSuggesting = false;
        });
      }
    }
  }

  String? _bestExample(List<String> examples, String word) {
    final normalizedWord = word.toLowerCase();
    for (final item in examples) {
      final example = item.trim();
      if (example.isNotEmpty && example.toLowerCase().contains(normalizedWord)) {
        return example;
      }
    }
    for (final item in examples) {
      if (item.trim().isNotEmpty) return item.trim();
    }
    return null;
  }

  void _save() {
    Navigator.pop(
      context,
      VocabQuickSaveData(
        meaning: _meaningCtrl.text.trim(),
        phonetic: _phoneticCtrl.text.trim(),
        example: _exampleCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.88,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          16,
          18,
          MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.library_add, color: Color(0xFF81C784)),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    context.uiText('Lưu kèm thông tin'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white54),
                  tooltip: context.uiText('Đóng'),
                ),
              ],
            ),
            Text(
              widget.word,
              style: const TextStyle(
                color: Color(0xFF90CAF9),
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.uiText(
                'Câu đang đọc được dùng làm ví dụ; bạn có thể sửa hoặc thay bằng câu khác.',
              ),
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isSuggesting ? null : _suggestMissingFields,
              icon: _isSuggesting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome, size: 18),
              label: Text(context.uiText(_isSuggesting
                  ? 'Đang tìm gợi ý...'
                  : 'Bổ sung thông minh (từ điển / AI)')),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                children: [
                  _field(
                    controller: _meaningCtrl,
                    label: 'Nghĩa / định nghĩa',
                    hint: 'Bạn có thể tự nhập nghĩa',
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  _field(
                    controller: _phoneticCtrl,
                    label: 'Phiên âm / IPA',
                    hint: '/.../',
                  ),
                  const SizedBox(height: 12),
                  _field(
                    controller: _exampleCtrl,
                    label: 'Câu ví dụ / cụm chứa từ',
                    hint: 'Một câu tự nhiên có chứa từ hoặc cụm này',
                    maxLines: 5,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(context.uiText('Hủy')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.check),
                    label: Text(context.uiText('Lưu vào WordList')),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: context.uiText(label),
        hintText: context.uiText(hint),
        labelStyle: const TextStyle(color: Colors.white70),
        hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: Color(0xFF81C784)),
        ),
      ),
    );
  }
}
