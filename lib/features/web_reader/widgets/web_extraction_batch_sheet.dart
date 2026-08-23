import 'package:in4up/core/language/localized_material.dart';
import 'package:provider/provider.dart';
import 'package:in4up_ai/in4up_ai.dart';

import '../../../providers/text_provider.dart';
import '../../../providers/vocabulary_provider.dart';
import '../../../services/syntax_highlighter_service.dart';
import '../../../services/text_library_service.dart';
import '../../../services/vocab_batch/vocab_batch_models.dart';
import '../../../widgets/vocab_entry_meta.dart';
import '../web_reader_controller.dart';

class WebExtractionBatchSheet extends StatefulWidget {
  final WebReaderController controller;
  final String sourceLabel;
  final String sourceText;
  final bool fromSelection;
  final WebExtractionDraft? initialDraft;

  const WebExtractionBatchSheet({
    super.key,
    required this.controller,
    required this.sourceLabel,
    required this.sourceText,
    required this.fromSelection,
    this.initialDraft,
  });

  static Future<void> show(
    BuildContext context, {
    required WebReaderController controller,
    required String sourceLabel,
    required String sourceText,
    required bool fromSelection,
    WebExtractionDraft? initialDraft,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF111827),
      builder: (_) => WebExtractionBatchSheet(
        controller: controller,
        sourceLabel: sourceLabel,
        sourceText: sourceText,
        fromSelection: fromSelection,
        initialDraft: initialDraft,
      ),
    );
  }

  @override
  State<WebExtractionBatchSheet> createState() => _WebExtractionBatchSheetState();
}

class _WebExtractionBatchSheetState extends State<WebExtractionBatchSheet> {
  List<WebExtractionCandidate> _candidates = const [];
  String? _draftId;
  bool _onlyNew = false;
  bool _onlyPhrases = false;
  bool _onlyReady = false;
  bool _importReadyOnly = false;
  bool _isEnriching = false;
  double _enrichProgress = 0;
  int _minLength = 4;
  WebExtractionSort _sort = WebExtractionSort.priority;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialDraft != null) {
      _draftId = widget.initialDraft!.id;
      _candidates = widget.initialDraft!.candidates
          .map((e) => WebExtractionCandidate.fromJson(e.toJson()))
          .toList();
    } else {
      _rebuildCandidates();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _rebuildCandidates() {
    final rebuilt = widget.controller.extractBatchCandidates(
      widget.sourceText,
      minLength: _minLength,
      includePhrases: true,
      allowSingleMentionPhrases: widget.fromSelection,
    );
    if (_onlyNew) {
      for (final candidate in rebuilt) {
        candidate.selected = !candidate.existed;
      }
    }
    setState(() => _candidates = rebuilt);
  }

  List<WebExtractionCandidate> get _visibleCandidates {
    final q = _searchQuery.trim().toLowerCase();
    final visible = _candidates.where((candidate) {
      if (_onlyNew && candidate.existed) return false;
      if (_onlyPhrases && !candidate.isPhrase) return false;
      if (_onlyReady && !candidate.isImportReady) return false;
      if (q.isEmpty) return true;
      return candidate.normalized.contains(q) ||
          candidate.sampleContext.toLowerCase().contains(q) ||
          candidate.meaning.toLowerCase().contains(q) ||
          (candidate.topic ?? '').toLowerCase().contains(q);
    }).toList();

    visible.sort((a, b) {
      switch (_sort) {
        case WebExtractionSort.frequency:
          final frequencyCompare = b.frequency.compareTo(a.frequency);
          if (frequencyCompare != 0) return frequencyCompare;
          return _compareByPriority(a, b);
        case WebExtractionSort.length:
          final lengthCompare =
              b.normalized.length.compareTo(a.normalized.length);
          if (lengthCompare != 0) return lengthCompare;
          return _compareByPriority(a, b);
        case WebExtractionSort.alphabetic:
          final textCompare = a.normalized.compareTo(b.normalized);
          if (textCompare != 0) return textCompare;
          return _compareByPriority(a, b);
        case WebExtractionSort.priority:
          return _compareByPriority(a, b);
      }
    });

    return visible;
  }

  int _compareByPriority(
    WebExtractionCandidate a,
    WebExtractionCandidate b,
  ) {
    final scoreCompare = b.rankScore.compareTo(a.rankScore);
    if (scoreCompare != 0) return scoreCompare;
    if (a.isPriority != b.isPriority) return a.isPriority ? -1 : 1;
    if (a.isPhrase != b.isPhrase) return a.isPhrase ? -1 : 1;
    if (a.existed != b.existed) return a.existed ? 1 : -1;
    final frequencyCompare = b.frequency.compareTo(a.frequency);
    if (frequencyCompare != 0) return frequencyCompare;
    return a.normalized.compareTo(b.normalized);
  }

  int get _selectedCount =>
      _candidates.where((candidate) => candidate.selected).length;
  int get _newCount => _candidates.where((candidate) => !candidate.existed).length;
  int get _existingCount =>
      _candidates.where((candidate) => candidate.existed).length;
  int get _phraseCount =>
      _candidates.where((candidate) => candidate.isPhrase).length;
  int get _priorityCount =>
      _candidates.where((candidate) => candidate.isPriority).length;
  int get _enrichedCount =>
      _candidates.where((candidate) => candidate.enriched).length;
  int get _readyCount =>
      _candidates.where((candidate) => candidate.isImportReady).length;
  int get _selectedReadyCount => _candidates
      .where((candidate) => candidate.selected && candidate.isImportReady)
      .length;

  void _setAllVisible(bool selected) {
    for (final candidate in _visibleCandidates) {
      candidate.selected = selected;
    }
    setState(() {});
  }

  Future<void> _enrichSelected() async {
    final targets = _candidates.where((candidate) => candidate.selected).toList();
    if (targets.isEmpty) return;

    final facade = context.read<AiServiceFacade>();
    setState(() {
      _isEnriching = true;
      _enrichProgress = 0;
    });

    int processed = 0;
    for (final candidate in targets) {
      widget.controller.enrichCandidateLocally(candidate);

      if (!candidate.isPhrase) {
        final localAnalysis = SyntaxHighlighterService.instance.analyzeWord(
          candidate.normalized,
        );
        try {
          await facade.analyzeWord(
            word: candidate.normalized,
            sentenceContext: candidate.sampleContext,
            localDictLookup: (_) => localAnalysis.meaning,
            ipaPhoneLookup: (_) => null,
          );
          final detail = facade.currentAnalysis?.wordDetail;
          final topic = (facade.currentAnalysis?.topics.isNotEmpty ?? false)
              ? facade.currentAnalysis!.topics.first
              : null;
          widget.controller.applyAiAssistToCandidate(
            candidate,
            meaning: detail?.meaning,
            phonetic: detail?.phonetic,
            topic: topic,
            example: candidate.sampleContext,
            usedAi: facade.hasModel,
          );
        } catch (_) {
          widget.controller.applyAiAssistToCandidate(
            candidate,
            example: candidate.sampleContext,
            usedAi: false,
          );
        }
      } else {
        widget.controller.applyAiAssistToCandidate(
          candidate,
          example: candidate.sampleContext,
          usedAi: false,
        );
      }

      processed++;
      if (mounted) {
        setState(() {
          _enrichProgress = processed / targets.length;
        });
      }
    }

    if (!mounted) return;
    setState(() {
      _isEnriching = false;
      _enrichProgress = 1;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.uiText(facade.hasModel
              ? '✨ Đã làm giàu ${targets.length} mục bằng AI/local'
              : '✨ Đã làm giàu ${targets.length} mục bằng local/heuristic'),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _bulkApplyToSelected() async {
    final targets = _candidates.where((candidate) => candidate.selected).toList();
    if (targets.isEmpty) return;

    final topicCtrl = TextEditingController();
    final exampleCtrl = TextEditingController();
    bool useSampleContextIfEmpty = true;
    String? bulkLanguage; // null = giữ nguyên language từng mục

    final provider = context.read<VocabularyProvider>();
    final languageOptions = (provider.allLanguages.toList()
          ..sort())
        .toSet()
      ..addAll(['en', 'vi', 'pali', 'my']);
    final sortedLangs = languageOptions.toList()..sort();

    final shouldApply = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF151B26),
              title: const Text('Bulk apply cho mục đã chọn'),
              titleTextStyle: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              content: SizedBox(
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _editorField(
                      controller: topicCtrl,
                      label: 'Topic áp cho tất cả',
                      hint: 'Ví dụ: dharma, english_learning, news',
                    ),
                    const SizedBox(height: 12),
                    // READ-630-04: ngôn ngữ áp cho tất cả (tap lại = bỏ)
                    Text(
                      'Ngôn ngữ áp cho tất cả',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final lang in sortedLangs)
                          ChoiceChip(
                            label: Text(
                              labelForLanguage(lang),
                              style: TextStyle(
                                color: bulkLanguage == lang
                                    ? Colors.white
                                    : Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                            selected: bulkLanguage == lang,
                            selectedColor: const Color(0xFF42A5F5),
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.04),
                            side: BorderSide(
                              color: bulkLanguage == lang
                                  ? const Color(0xFF42A5F5)
                                  : Colors.white.withValues(alpha: 0.1),
                            ),
                            onSelected: (value) => setLocalState(() {
                              bulkLanguage = value ? lang : null;
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _editorField(
                      controller: exampleCtrl,
                      label: 'Example chung (tuỳ chọn)',
                      hint: 'Nếu nhập, sẽ áp cho tất cả mục đã chọn',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      value: useSampleContextIfEmpty,
                      onChanged: (value) => setLocalState(
                        () => useSampleContextIfEmpty = value ?? true,
                      ),
                      activeColor: const Color(0xFF64B5F6),
                      title: const Text(
                        'Dùng sample context làm example nếu còn trống',
                        style: TextStyle(color: Colors.white),
                      ),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Huỷ'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Áp dụng'),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldApply != true) return;

    final topic = topicCtrl.text.trim();
    final example = exampleCtrl.text.trim();
    for (final candidate in targets) {
      if (topic.isNotEmpty) {
        candidate.topic = topic;
      }
      if (example.isNotEmpty) {
        candidate.example = example;
      } else if (useSampleContextIfEmpty &&
          (candidate.example ?? '').trim().isEmpty) {
        candidate.example = candidate.sampleContext;
      }
      if (bulkLanguage != null) {
        candidate.language = bulkLanguage!;
      }
      candidate.enriched = true;
      candidate.enrichSource = 'manual';
    }

    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.uiText('🛠️ Đã áp dụng bulk fields cho ${targets.length} mục')),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _editCandidate(WebExtractionCandidate candidate) async {
    final meaningCtrl = TextEditingController(text: candidate.meaning);
    final phoneticCtrl = TextEditingController(text: candidate.phonetic ?? '');
    final topicCtrl = TextEditingController(text: candidate.topic ?? '');
    final exampleCtrl = TextEditingController(
      text: (candidate.example ?? '').trim().isEmpty
          ? candidate.sampleContext
          : candidate.example,
    );

    final provider = context.read<VocabularyProvider>();
    final languageOptions = (provider.allLanguages.toList()..sort()).toSet()
      ..addAll(['en', 'vi', 'pali', 'my']);
    final sortedLangs = languageOptions.toList()..sort();
    String selectedLang = candidate.language;

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setLocalState) {
            return AlertDialog(
          backgroundColor: const Color(0xFF151B26),
          title: Text(context.uiText('Sửa mục: ${candidate.text}')),
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _editorField(
                    controller: meaningCtrl,
                    label: 'Meaning',
                    hint: 'Nghĩa / giải thích ngắn',
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  _editorField(
                    controller: phoneticCtrl,
                    label: 'IPA / Phonetic',
                    hint: '/.../',
                  ),
                  const SizedBox(height: 12),
                  _editorField(
                    controller: topicCtrl,
                    label: 'Topic',
                    hint: 'dharma / english_learning / news...',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Ngôn ngữ',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final lang in sortedLangs)
                        ChoiceChip(
                          label: Text(
                            labelForLanguage(lang),
                            style: TextStyle(
                              color: selectedLang == lang
                                  ? Colors.white
                                  : Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                          selected: selectedLang == lang,
                          selectedColor: const Color(0xFF42A5F5),
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.04),
                          side: BorderSide(
                            color: selectedLang == lang
                                ? const Color(0xFF42A5F5)
                                : Colors.white.withValues(alpha: 0.1),
                          ),
                          onSelected: (value) {
                            if (value) {
                              setLocalState(() => selectedLang = lang);
                            }
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _editorField(
                    controller: exampleCtrl,
                    label: 'Example',
                    hint: 'Câu ví dụ',
                    maxLines: 4,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Lưu'),
            ),
          ],
        );
          });
      },
    );

    if (shouldSave != true || !mounted) return;

    setState(() {
      candidate.meaning = meaningCtrl.text.trim();
      candidate.language = selectedLang;
      candidate.phonetic = phoneticCtrl.text.trim().isEmpty
          ? null
          : phoneticCtrl.text.trim();
      candidate.topic =
          topicCtrl.text.trim().isEmpty ? null : topicCtrl.text.trim();
      candidate.example =
          exampleCtrl.text.trim().isEmpty ? null : exampleCtrl.text.trim();
      candidate.enriched = true;
      candidate.enrichSource = 'manual';
    });
  }

  InputDecoration _inputDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: context.uiText(label),
      hintText: hint == null ? null : context.uiText(hint),
      labelStyle: TextStyle(color: Colors.grey[300]),
      hintStyle: TextStyle(color: Colors.grey[600]),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.04),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF64B5F6)),
      ),
    );
  }

  Widget _editorField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration(label, hint: hint),
    );
  }

  String _candidateStatusText(WebExtractionCandidate candidate) {
    if (candidate.isImportReady) {
      return 'Sẵn sàng nhập: đã có nghĩa + topic + example';
    }
    final missing = <String>[];
    if (!candidate.hasMeaning) missing.add('meaning');
    if (!candidate.hasTopic) missing.add('topic');
    if (!candidate.hasExample) missing.add('example');
    return 'Thiếu: ${missing.join(', ')}';
  }

  Future<void> _saveDraft() async {
    final draft = await widget.controller.saveBatchDraft(
      draftId: _draftId,
      sourceLabel: widget.sourceLabel,
      sourceText: widget.sourceText,
      fromSelection: widget.fromSelection,
      candidates: _candidates,
    );
    if (!mounted) return;
    _draftId = draft.id;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('💾 Đã lưu batch nháp'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _buildExportPayload({required bool onlySelected}) {
    final rows = <WebExtractionCandidate>[];
    for (final candidate in _candidates) {
      if (onlySelected && !candidate.selected) continue;
      rows.add(candidate);
    }

    final buffer = StringBuffer();
    buffer.writeln('word\tmeaning\tipa\ttopic\texample');
    for (final candidate in rows) {
      final example = ((candidate.example ?? '').trim().isEmpty
              ? candidate.sampleContext
              : candidate.example ?? '')
          .replaceAll('\n', ' ')
          .replaceAll('\t', ' ')
          .trim();
      buffer.writeln(
        '${candidate.text.replaceAll('\t', ' ')}\t'
        '${candidate.meaning.replaceAll('\t', ' ')}\t'
        '${(candidate.phonetic ?? '').replaceAll('\t', ' ')}\t'
        '${(candidate.topic ?? '').replaceAll('\t', ' ')}\t'
        '$example',
      );
    }
    return buffer.toString().trim();
  }

  void _exportSelectedToTextStudio() {
    final payload = _buildExportPayload(onlySelected: true);
    if (payload.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa có mục nào để export')),
      );
      return;
    }
    context.read<TextProvider>().loadFromString(
          payload,
          title: 'Web batch · ${widget.sourceLabel}',
        );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📝 Đã mở batch trong Text Studio'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _saveSelectedToTextLibrary() async {
    final payload = _buildExportPayload(onlySelected: true);
    if (payload.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa có mục nào để lưu')),
      );
      return;
    }

    final titleCtrl = TextEditingController(text: 'Web batch · ${widget.sourceLabel}');
    final categoryCtrl = TextEditingController(text: 'web_batch');

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF151B26),
          title: const Text('Lưu batch sang Text Library'),
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _editorField(
                  controller: titleCtrl,
                  label: 'Tiêu đề',
                  hint: 'Ví dụ: Web batch bài Dharma 01',
                ),
                const SizedBox(height: 12),
                _editorField(
                  controller: categoryCtrl,
                  label: 'Category',
                  hint: 'web_batch / dharma / news...',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Lưu'),
            ),
          ],
        );
      },
    );

    if (shouldSave != true || !mounted) return;

    final service = TextLibraryService();
    final entry = await service.add(
      title: titleCtrl.text.trim().isEmpty ? 'Web batch' : titleCtrl.text.trim(),
      content: payload,
      category:
          categoryCtrl.text.trim().isEmpty ? 'web_batch' : categoryCtrl.text.trim(),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(entry == null
            ? 'Không thể lưu sang Text Library (có thể chưa đăng nhập)'
            : '☁️ Đã lưu batch sang Text Library'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _importSelected() async {
    final result = widget.controller.importBatchToWordList(
      _candidates,
      onlyReady: _importReadyOnly,
    );
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.uiText(result.processedCount == 0
              ? 'Chưa có mục nào được nhập vào WordList'
              : '📚 WordList: thêm mới ${result.addedCount}, bổ sung ngữ cảnh ${result.updatedCount}, bỏ qua ${result.skippedCount}'),
        ),
        backgroundColor: const Color(0xFF1E5F3A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleCandidates;

    return FractionallySizedBox(
      heightFactor: 0.92,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.fromSelection
                  ? 'Tạo batch WordList từ đoạn chọn'
                  : 'Tạo batch WordList từ bài này',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.sourceLabel,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey[400], height: 1.45),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetaChip(label: '${_candidates.length} ứng viên'),
                _MetaChip(label: 'Mới $_newCount'),
                _MetaChip(label: 'Phrase $_phraseCount'),
                _MetaChip(label: 'Ưu tiên $_priorityCount'),
                _MetaChip(label: 'Đã enrich $_enrichedCount'),
                _MetaChip(label: 'Sẵn sàng $_readyCount'),
                _MetaChip(label: 'Đã có $_existingCount'),
                _MetaChip(label: 'Đã chọn $_selectedCount'),
              ],
            ),
            if (_isEnriching) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: _enrichProgress <= 0 ? null : _enrichProgress,
                minHeight: 6,
                borderRadius: BorderRadius.circular(999),
                backgroundColor: Colors.white10,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Color(0xFF64B5F6)),
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: _searchCtrl,
              onChanged: (value) => setState(() => _searchQuery = value),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: context.uiText('Tìm trong danh sách ứng viên...'),
                hintStyle: TextStyle(color: Colors.grey[500]),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                suffixIcon: _searchQuery.trim().isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                        icon: const Icon(Icons.close, color: Colors.white70),
                      ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.04),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF64B5F6)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text('Chỉ mục mới'),
                  selected: _onlyNew,
                  onSelected: (value) => setState(() => _onlyNew = value),
                ),
                ChoiceChip(
                  label: const Text('Chỉ phrase'),
                  selected: _onlyPhrases,
                  onSelected: (value) => setState(() => _onlyPhrases = value),
                ),
                ChoiceChip(
                  label: const Text('Chỉ sẵn sàng'),
                  selected: _onlyReady,
                  onSelected: (value) => setState(() => _onlyReady = value),
                ),
                _LengthChip(
                  value: _minLength,
                  onChanged: (value) {
                    _minLength = value;
                    _rebuildCandidates();
                  },
                ),
                _SortChip(
                  sort: _sort,
                  onChanged: (value) => setState(() => _sort = value),
                ),
                TextButton.icon(
                  onPressed: () => _setAllVisible(true),
                  icon: const Icon(Icons.done_all, size: 18),
                  label: const Text('Chọn tất cả'),
                ),
                TextButton.icon(
                  onPressed: () => _setAllVisible(false),
                  icon: const Icon(Icons.remove_done, size: 18),
                  label: const Text('Bỏ chọn'),
                ),
                FilledButton.tonalIcon(
                  onPressed:
                      _selectedCount == 0 || _isEnriching ? null : _enrichSelected,
                  icon: _isEnriching
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome, size: 18),
                  label: Text(_isEnriching
                      ? 'Đang làm giàu...'
                      : 'Làm giàu AI/local'),
                ),
                OutlinedButton.icon(
                  onPressed: _selectedCount == 0 ? null : _bulkApplyToSelected,
                  icon: const Icon(Icons.playlist_add_check, size: 18),
                  label: const Text('Bulk apply'),
                ),
                OutlinedButton.icon(
                  onPressed: _saveDraft,
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: Text(_draftId == null ? 'Lưu nháp' : 'Cập nhật nháp'),
                ),
                OutlinedButton.icon(
                  onPressed: _selectedCount == 0 ? null : _exportSelectedToTextStudio,
                  icon: const Icon(Icons.text_snippet_outlined, size: 18),
                  label: const Text('Text Studio'),
                ),
                OutlinedButton.icon(
                  onPressed: _selectedCount == 0 ? null : _saveSelectedToTextLibrary,
                  icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                  label: const Text('Text Library'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: visible.isEmpty
                  ? _EmptyState(
                      title: 'Không có ứng viên phù hợp',
                      description: _candidates.isEmpty
                          ? 'Bài/đoạn này chưa đủ dữ liệu để trích từ học tập với bộ lọc hiện tại.'
                          : 'Thử tắt bộ lọc “Chỉ phrase / Chỉ mục mới”, giảm min length, hoặc đổi sort.',
                    )
                  : ListView.separated(
                      itemCount: visible.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                      itemBuilder: (context, index) {
                        final candidate = visible[index];
                        return CheckboxListTile(
                          value: candidate.selected,
                          activeColor: const Color(0xFF64B5F6),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      candidate.text,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  if (candidate.isImportReady)
                                    const Icon(
                                      Icons.verified_rounded,
                                      size: 16,
                                      color: Colors.greenAccent,
                                    ),
                                  const SizedBox(width: 8),
                                  Text(
                                    candidate.rankScore.toStringAsFixed(0),
                                    style: TextStyle(
                                      color: Colors.blue[200],
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  IconButton(
                                    tooltip: context.uiText('Sửa mục này'),
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => _editCandidate(candidate),
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 18,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  if (candidate.isPriority)
                                    const _MiniBadge(
                                      label: 'Ưu tiên',
                                      color: Colors.amber,
                                    ),
                                  if (candidate.isPhrase)
                                    _MiniBadge(
                                      label: 'Phrase ${candidate.wordCount}w',
                                      color: const Color(0xFF64B5F6),
                                    ),
                                  if (candidate.appearsInTitle)
                                    const _MiniBadge(
                                      label: 'Trong tiêu đề',
                                      color: Colors.purpleAccent,
                                    ),
                                  _MiniBadge(
                                    label: candidate.existed ? 'Đã có' : 'Mới',
                                    color: candidate.existed
                                        ? Colors.orangeAccent
                                        : Colors.greenAccent,
                                  ),
                                  if (candidate.isImportReady)
                                    const _MiniBadge(
                                      label: 'Ready',
                                      color: Colors.greenAccent,
                                    )
                                  else
                                    const _MiniBadge(
                                      label: 'Thiếu dữ liệu',
                                      color: Colors.redAccent,
                                    ),
                                  _MiniBadge(
                                    label: 'x${candidate.frequency}',
                                    color: Colors.blueAccent,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (candidate.meaning.trim().isNotEmpty)
                                  Text(
                                    '💡 ${candidate.meaning.trim()}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.green[200],
                                      height: 1.35,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                if ((candidate.phonetic ?? '').trim().isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    candidate.phonetic!.trim(),
                                    style: TextStyle(
                                      color: Colors.blue[100],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                                if ((candidate.topic ?? '').trim().isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '🏷️ ${candidate.topic!.trim()}',
                                    style: TextStyle(
                                      color: Colors.orange[200],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 6),
                                Text(
                                  candidate.sampleContext,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  context.uiText(
                                    _candidateStatusText(candidate),
                                  ),
                                  style: TextStyle(
                                    color: candidate.isImportReady
                                        ? Colors.green[200]
                                        : Colors.red[200],
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (candidate.enriched) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    candidate.enrichSource == 'ai+local'
                                        ? '✨ AI/local'
                                        : candidate.enrichSource == 'manual'
                                            ? '✨ Manual'
                                            : '✨ Local/heuristic',
                                    style: TextStyle(
                                      color: Colors.purple[200],
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          onChanged: (value) {
                            setState(() => candidate.selected = value ?? false);
                          },
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                FilterChip(
                  label: const Text('Chỉ nhập mục sẵn sàng'),
                  selected: _importReadyOnly,
                  onSelected: (value) => setState(() => _importReadyOnly = value),
                ),
                const Spacer(),
                Text(
                  context.uiText(_importReadyOnly
                      ? 'Ready đã chọn: $_selectedReadyCount'
                      : 'Đã chọn: $_selectedCount'),
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Đóng'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: (_importReadyOnly
                                ? _selectedReadyCount == 0
                                : _selectedCount == 0) ||
                            _isEnriching
                        ? null
                        : _importSelected,
                    icon: const Icon(Icons.library_add_check),
                    label: Text(
                      context.uiText(_importReadyOnly
                          ? 'Nhập $_selectedReadyCount mục sẵn sàng'
                          : 'Nhập $_selectedCount mục vào WordList'),
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
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
}

class _MetaChip extends StatelessWidget {
  final String label;

  const _MetaChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        context.uiText(label),
        style: const TextStyle(
          color: Colors.white70,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        context.uiText(label),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LengthChip extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _LengthChip({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      color: const Color(0xFF151B26),
      onSelected: onChanged,
      itemBuilder: (context) => const [
        PopupMenuItem(value: 3, child: Text('Min length 3')),
        PopupMenuItem(value: 4, child: Text('Min length 4')),
        PopupMenuItem(value: 5, child: Text('Min length 5')),
        PopupMenuItem(value: 6, child: Text('Min length 6')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Text(
          context.uiText('Min length $value'),
          style: const TextStyle(color: Colors.white70),
        ),
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  final WebExtractionSort sort;
  final ValueChanged<WebExtractionSort> onChanged;

  const _SortChip({required this.sort, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<WebExtractionSort>(
      color: const Color(0xFF151B26),
      onSelected: onChanged,
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: WebExtractionSort.priority,
          child: Text('Sort: Quan trọng nhất'),
        ),
        PopupMenuItem(
          value: WebExtractionSort.frequency,
          child: Text('Sort: Tần suất'),
        ),
        PopupMenuItem(
          value: WebExtractionSort.length,
          child: Text('Sort: Độ dài'),
        ),
        PopupMenuItem(
          value: WebExtractionSort.alphabetic,
          child: Text('Sort: Alphabet'),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Text(
          context.uiText(_label(sort)),
          style: const TextStyle(color: Colors.white70),
        ),
      ),
    );
  }

  static String _label(WebExtractionSort sort) {
    switch (sort) {
      case WebExtractionSort.priority:
        return 'Quan trọng nhất';
      case WebExtractionSort.frequency:
        return 'Theo tần suất';
      case WebExtractionSort.length:
        return 'Theo độ dài';
      case WebExtractionSort.alphabetic:
        return 'Theo alphabet';
    }
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String description;

  const _EmptyState({required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_motion_outlined,
                color: Colors.grey[600], size: 34),
            const SizedBox(height: 12),
            Text(
              context.uiText(title),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.uiText(description),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400], height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
