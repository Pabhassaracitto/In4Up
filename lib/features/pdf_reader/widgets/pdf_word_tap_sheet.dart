import 'package:in4up/core/language/localized_material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:in4up_core/vocab_level_difficulty.dart';

import '../../../models/vocab_context.dart';
import '../../../models/word_entry.dart';
import '../../../providers/vocabulary_provider.dart';
import '../../dictionary/services/dict_text_cleaner.dart';
import '../../dictionary/widgets/dict_definition_view.dart';
import '../../dictionary/widgets/dict_entry_detail_sheet.dart';
import '../../vocab_image/vocab_image_quick_add.dart';
import '../../word_lookup/services/word_insight_service.dart';
import '../../../widgets/ipa_source_chip.dart';
import '../../../widgets/unified_knowledge_sheet.dart';
import '../../../widgets/vocab_entry_meta.dart';
import '../../../widgets/vocab_quick_save_sheet.dart';
import '../models/pdf_word_info.dart';
import '../pdf_reader_controller.dart';

/// Bottom sheet hiện ra khi user tap vào một từ trong PDF
class PdfWordTapSheet {
  static void show(
    BuildContext context,
    PdfWordInfo wordInfo,
    PdfReaderController controller,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _WordSheet(wordInfo: wordInfo, controller: controller),
    );
  }
}

class _WordSheet extends StatefulWidget {
  final PdfWordInfo wordInfo;
  final PdfReaderController controller;

  const _WordSheet({required this.wordInfo, required this.controller});

  @override
  State<_WordSheet> createState() => _WordSheetState();
}

class _WordSheetState extends State<_WordSheet> {
  /// WORD-INSIGHT-001: nghĩa + IPA lấy NGAY khi mở sheet (mạng → từ điển →
  /// offline), không bắt người dùng tự điền rồi mới thấy.
  WordInsight? _insight;
  DictMergedEntry? _merged;
  bool _loading = true;

  PdfWordInfo get _wordInfo => widget.wordInfo;
  PdfReaderController get _controller => widget.controller;

  String get _displayWord =>
      _wordInfo.text.replaceAll(RegExp(r'[^\w\s]'), '').trim();

  String get _lookupWord => _displayWord.toLowerCase();

  @override
  void initState() {
    super.initState();
    _loadInsight();
  }

  Future<void> _loadInsight() async {
    final word = _lookupWord;
    if (word.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final service = WordInsightService();

    // Bước 1: nguồn cục bộ (MDX → offline) — hiện ngay, không chờ mạng.
    final local = await service.resolveLocal(word);
    if (!mounted) return;
    setState(() {
      _insight = local;
      _merged = local.hasDictionary ? local.mergedDictionary : _merged;
      if (local.hasAny) _loading = false;
    });

    // Bước 2: nâng cấp bằng nguồn mạng (ưu tiên mạng theo yêu cầu).
    final online = await service.resolve(word);
    if (!mounted) return;
    setState(() {
      _insight = online;
      _merged = online.hasDictionary ? online.mergedDictionary : _merged;
      _loading = false;
    });

    // Từ ĐÃ lưu nhưng còn trống nghĩa/IPA → bổ sung bằng smart-fill của
    // VocabularyProvider (CHỈ điền chỗ trống, không ghi đè dữ liệu người dùng).
    final provider = context.read<VocabularyProvider>();
    if (provider.findByWord(word) == null) return;
    final best = (online.hasMeaning || online.hasIpa) ? online : local;
    if (!best.hasMeaning && !best.hasIpa) return;
    provider.addWithAutoClassify(
      text: word,
      meaning: best.meaning ?? '',
      phonetic: best.ipa,
      phoneticSource: best.ipaSource,
    );
  }

  void _openFullDictionary(BuildContext context, String? meaning) {
    final insight = _insight;
    DictEntryDetailSheet.show(
      context,
      word: _displayWord,
      entries: insight?.entries ?? const [],
      ipa: insight?.ipa,
      meaning: meaning,
      partOfSpeech: insight?.partOfSpeech,
      originLabel: insight?.origin == null
          ? null
          : _originLabel(context, insight!.origin!),
      onSpeak: () => _controller.speakText(_displayWord),
    );
  }

  @override
  Widget build(BuildContext context) {
    final analyzed = _wordInfo.analyzed;
    final insight = _insight;

    return Consumer<VocabularyProvider>(
      builder: (context, provider, _) {
        final existing = provider.findByWord(_lookupWord);

        final savedMeaning = (existing?.meaning ?? '').trim();
        final insightMeaning = (insight?.meaning ?? '').trim();
        final analyzedMeaning = (analyzed?.meaning ?? '').trim();
        final meaning = savedMeaning.isNotEmpty
            ? savedMeaning
            : insightMeaning.isNotEmpty
                ? insightMeaning
                : analyzedMeaning;

        final savedPhonetic = (existing?.phonetic ?? '').trim();
        final insightPhonetic = (insight?.ipa ?? '').trim();
        final analyzedPhonetic = (analyzed?.phonetic ?? '').trim();
        final phonetic = savedPhonetic.isNotEmpty
            ? savedPhonetic
            : insightPhonetic.isNotEmpty
                ? insightPhonetic
                : analyzedPhonetic;

        final phoneticSource = savedPhonetic.isNotEmpty
            ? existing?.phoneticSource
            : insightPhonetic.isNotEmpty
                ? insight?.ipaSource
                : null;

        final origin = insight?.origin;
        final showLookupSpinner = _loading && meaning.isEmpty;
        final merged = _merged;
        final exampleText = (analyzed?.example ?? '').trim();
        final surroundingText =
            (_wordInfo.contextSnippet ?? '').trim().isNotEmpty
                ? _wordInfo.contextSnippet!.trim()
                : exampleText.isNotEmpty
                    ? exampleText
                    : _displayWord;

        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(context).padding.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Word header ──────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _displayWord,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (phonetic.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    phonetic,
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 14,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                                if ((phoneticSource ?? '').isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  IpaSourceChip(source: phoneticSource!),
                                ],
                              ],
                            ),
                          ] else if (_loading) ...[
                            const SizedBox(height: 4),
                            _LookupPlaceholder(
                              label: context.uiText('Đang tra phiên âm…'),
                            ),
                          ],
                          const SizedBox(height: 8),
                          // Tags: CEFR + WordType
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (analyzed != null) ...[
                                _Tag(
                                  label: analyzed.cefrLevel.shortLabel,
                                  color: analyzed.cefrLevel.color,
                                ),
                                _Tag(
                                  label: analyzed.wordType.labelVi,
                                  color: analyzed.wordType.color,
                                ),
                              ],
                              if (origin != null)
                                _OriginChip(
                                  label: _originLabel(context, origin),
                                  origin: origin,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Speak button
                    _CircleBtn(
                      icon: Icons.volume_up_rounded,
                      color: const Color(0xFF2196F3),
                      onTap: () => _controller.speakText(_displayWord),
                    ),
                  ],
                ),

                // Meaning
                if (meaning.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('💡 ', style: TextStyle(fontSize: 16)),
                        Expanded(
                          child: Text(
                            meaning,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (showLookupSpinner) ...[
                  const SizedBox(height: 12),
                  _LookupPlaceholder(
                    label: context.uiText('Đang tra nghĩa & phiên âm…'),
                  ),
                ] else if (!_loading) ...[
                  const SizedBox(height: 12),
                  Text(
                    context.uiText('Chưa tra được nghĩa cho từ này'),
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],

                // ── Từ điển (cô đọng, có nút mở trang đầy đủ) ─────
                if (merged != null && !merged.isEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF64B5F6).withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF64B5F6).withValues(alpha: 0.18),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.menu_book,
                              size: 14,
                              color: Color(0xFF64B5F6),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              context.uiText('Từ điển'),
                              style: const TextStyle(
                                color: Color(0xFF64B5F6),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        DictDefinitionView(
                          groups: merged.groups,
                          maxSenses: 3,
                          compact: true,
                          accentColor: const Color(0xFF64B5F6),
                          sourceLabel: merged.sourceLabel,
                          onOpenFull: () =>
                              _openFullDictionary(context, meaning),
                        ),
                      ],
                    ),
                  ),
                ],

                if (existing != null) ...[
                  const SizedBox(height: 12),
                  _SavedRecallCard(
                    entry: existing,
                    // `controller.fileName` = basename đa nền tảng: phải KHỚP
                    // với `VocabContext.fileName` đã lưu, nếu không thẻ "từ đã
                    // lưu của file này" không tìm ra nhau trên Windows.
                    pdfFileName: _controller.fileName,
                    pageIndex: _wordInfo.pageIndex,
                    onAddContext: () {
                      provider.addContextToWord(
                        existing.id,
                        _controller.buildWordContext(
                          _wordInfo,
                          surroundingText: surroundingText,
                          anchorText: _displayWord,
                        ),
                      );
                      _controller.refreshVocabularySignals();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.uiText(
                              'Đã thêm ngữ cảnh PDF mới cho từ này')),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    onEditNotes: () => _showEditSavedNotesDialog(
                      context,
                      provider,
                      _controller,
                      existing,
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // ── Actions ──────────────────────────────────────
                Row(
                  children: [
                    // Save to Memory
                    Expanded(
                      child: _ActionBtn(
                        icon: Icons.psychology,
                        label: 'Lưu vào Vườn Nhớ',
                        color: const Color(0xFF6C63FF),
                        onTap: () {
                          _controller.saveWordToMemory(
                            _wordInfo,
                            meaning: meaning.isEmpty ? null : meaning,
                            phonetic: phonetic.isEmpty ? null : phonetic,
                            phoneticSource:
                                phonetic.isEmpty ? null : phoneticSource,
                          );
                          HapticFeedback.mediumImpact();
                          final message = context.uiText(
                            '✅ Đã lưu "$_displayWord" vào Vườn Nhớ',
                          );
                          final messenger = ScaffoldMessenger.of(context);
                          Navigator.pop(context);
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(message),
                              backgroundColor: const Color(0xFF6C63FF),
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Trang từ điển đầy đủ (MDX đã import + nguồn mạng)
                    _IconActionBtn(
                      icon: Icons.menu_book,
                      tooltip: context.uiText('Mở từ điển'),
                      onTap: () => _openFullDictionary(context, meaning),
                    ),

                    const SizedBox(width: 8),

                    // Tra từ điển online
                    _IconActionBtn(
                      icon: Icons.open_in_new,
                      tooltip: context.uiText('Tra từ điển'),
                      onTap: () {
                        final url =
                            'https://www.oxfordlearnersdictionaries.com/definition/english/$_displayWord';
                        launchUrl(Uri.parse(url),
                            mode: LaunchMode.externalApplication);
                      },
                    ),

                    const SizedBox(width: 8),

                    // Copy
                    _IconActionBtn(
                      icon: Icons.copy,
                      tooltip: context.uiText('Sao chép'),
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: _displayWord));
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),

                // Difficulty markers
                const SizedBox(height: 12),
                Text(
                  context.uiText('Đánh dấu độ khó:'),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Row(
                  children: DifficultyLevel.values.map((d) {
                    final isSelected = analyzed?.userDifficulty == d;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: GestureDetector(
                          onTap: () {
                            _controller.markWordDifficulty(_wordInfo, d);
                            HapticFeedback.selectionClick();
                            final message = context.uiText(
                              '"$_displayWord" → ${context.uiText(d.label)}',
                            );
                            final messenger = ScaffoldMessenger.of(context);
                            Navigator.pop(context);
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(message),
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: d.color.withValues(
                                  alpha: isSelected ? 0.24 : 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? d.color
                                    : d.color.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(_difficultyIcon(d),
                                    color: d.color, size: 16),
                                const SizedBox(height: 2),
                                Text(
                                  d.label,
                                  style:
                                      TextStyle(color: d.color, fontSize: 9),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                // ── Lưu vào Wordlist ─────────────────────────────
                PdfWordSaveSection(
                  controller: _controller,
                  wordInfo: _wordInfo,
                  word: _lookupWord,
                  surroundingText: surroundingText,
                  // `controller.fileName` = basename đa nền tảng: phải KHỚP với
                  // `VocabContext.fileName` đã lưu, nếu không thẻ "từ đã lưu của
                  // file này" không tìm ra nhau trên Windows.
                  pdfFileName: _controller.fileName,
                  pageIndex: _wordInfo.pageIndex,
                  resolvedMeaning: meaning.isEmpty ? null : meaning,
                  resolvedPhonetic: phonetic.isEmpty ? null : phonetic,
                  phoneticSource: phonetic.isEmpty ? null : phoneticSource,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Nhãn nguồn dữ liệu — literal nằm trong file presentation để pipeline i18n
/// (rule #5) bắt được, thay vì chuỗi runtime nằm trong service.
String _originLabel(BuildContext context, WordInsightOrigin origin) {
  switch (origin) {
    case WordInsightOrigin.network:
      return context.uiText('Mạng');
    case WordInsightOrigin.dictionary:
      return context.uiText('Từ điển');
    case WordInsightOrigin.offline:
      return context.uiText('Ngoại tuyến');
  }
}

/// Dòng chờ nhỏ khi đang tra mạng/từ điển.
class _LookupPlaceholder extends StatelessWidget {
  final String label;

  const _LookupPlaceholder({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.6,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF64B5F6)),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        ),
      ],
    );
  }
}

/// Chip nguồn dữ liệu (Mạng / Từ điển / Ngoại tuyến).
class _OriginChip extends StatelessWidget {
  final String label;
  final WordInsightOrigin origin;

  const _OriginChip({required this.label, required this.origin});

  Color get _color {
    switch (origin) {
      case WordInsightOrigin.network:
        return const Color(0xFF4CAF50);
      case WordInsightOrigin.dictionary:
        return const Color(0xFF64B5F6);
      case WordInsightOrigin.offline:
        return const Color(0xFFFFB74D);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            origin == WordInsightOrigin.network
                ? Icons.wifi
                : origin == WordInsightOrigin.dictionary
                    ? Icons.menu_book
                    : Icons.offline_bolt_outlined,
            size: 10,
            color: _color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: _color,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showEditSavedNotesDialog(
  BuildContext context,
  VocabularyProvider provider,
  PdfReaderController controller,
  WordEntry entry,
) async {
  final noteCtrl = TextEditingController(text: entry.personalNotes ?? '');
  final shouldSave = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Ghi chú từ đã lưu'),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: noteCtrl,
            maxLines: 6,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: context.uiText('Nhập ghi chú cá nhân cho từ này...'),
              hintStyle: TextStyle(color: Colors.grey[500]),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
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
    },
  );

  if (shouldSave == true) {
    provider.updateNotes(entry.id, noteCtrl.text.trim());
    controller.refreshVocabularySignals();
  }
}

class _SavedRecallCard extends StatelessWidget {
  final WordEntry entry;
  final String pdfFileName;
  final int pageIndex;
  final VoidCallback onAddContext;
  final VoidCallback onEditNotes;

  const _SavedRecallCard({
    required this.entry,
    required this.pdfFileName,
    required this.pageIndex,
    required this.onAddContext,
    required this.onEditNotes,
  });

  @override
  Widget build(BuildContext context) {
    final latestContext = entry.latestContext;
    final note = (entry.personalNotes ?? '').trim();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Color(0xFF4CAF50), size: 16),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Tri thức đã lưu trước đó',
                  style: TextStyle(
                    color: Color(0xFFB9F6CA),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _Tag(label: entry.vocabType.badge, color: entry.vocabType.color),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _RecallChip(
                icon: Icons.repeat,
                label: '${entry.encounterCount} lần gặp',
              ),
              _RecallChip(
                icon: Icons.source_outlined,
                label: '${entry.sourceFiles.length} nguồn',
              ),
              _RecallChip(
                icon: Icons.picture_as_pdf_outlined,
                label: '$pdfFileName · trang ${pageIndex + 1}',
              ),
            ],
          ),
          const SizedBox(height: 10),
          // READ-630-02: thông tin đầy đủ (IPA, loại, chủ đề, ngôn ngữ)
          // + sửa ngay tại đây — không mất word/context
          VocabEntryMetaInfo(
            entry: entry,
            onEdit: () => VocabEntryEditSheet.show(context, entry),
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              note,
              style: const TextStyle(
                color: Colors.white,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (latestContext != null) ...[
            const SizedBox(height: 10),
            Text(
              context.uiText(
                'Ngữ cảnh gần nhất: ${latestContext.composeDisplaySource(
                  latestContext.hasGeneratedPositionLabel &&
                          latestContext.pageOrPosition != null
                      ? context.uiText(latestContext.pageOrPosition!)
                      : latestContext.pageOrPosition,
                )}',
              ),
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              latestContext.surroundingText,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
                fontStyle: FontStyle.italic,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton.icon(
                onPressed: onAddContext,
                icon: const Icon(Icons.add_link, size: 16),
                label: const Text('Thêm ngữ cảnh PDF'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFB9F6CA),
                ),
              ),
              TextButton.icon(
                onPressed: onEditNotes,
                icon: const Icon(Icons.edit_note, size: 16),
                label: Text(note.isEmpty ? 'Thêm ghi chú' : 'Sửa ghi chú'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white70,
                ),
              ),
              TextButton.icon(
                onPressed: () => UnifiedKnowledgeSheet.show(context, word: entry),
                icon: const Icon(Icons.hub_outlined, size: 16),
                label: const Text('Hồ sơ tri thức'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF64B5F6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecallChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _RecallChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white70),
          const SizedBox(width: 5),
          Text(
            context.uiText(label),
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

/// Widget lưu từ vào Wordlist từ PDF
/// Tích hợp vào PdfWordTapSheet hiện có
class PdfWordSaveSection extends StatefulWidget {
  final PdfReaderController controller;
  final PdfWordInfo? wordInfo;
  final String word;
  final String surroundingText;
  final String pdfFileName;
  final int pageIndex;

  /// Nghĩa đã tra được (mạng → từ điển → offline) — ưu tiên hơn nghĩa
  /// lexicon nội bộ, để lưu nhanh KHÔNG ghi thẻ trống nghĩa.
  final String? resolvedMeaning;

  /// IPA đã tra được.
  final String? resolvedPhonetic;

  /// Provenance của IPA (`online` | `mdx` | `cmu` | `g2p`).
  final String? phoneticSource;

  const PdfWordSaveSection({
    super.key,
    required this.controller,
    this.wordInfo,
    required this.word,
    required this.surroundingText,
    required this.pdfFileName,
    required this.pageIndex,
    this.resolvedMeaning,
    this.resolvedPhonetic,
    this.phoneticSource,
  });

  @override
  State<PdfWordSaveSection> createState() => _PdfWordSaveSectionState();
}

class _PdfWordSaveSectionState extends State<PdfWordSaveSection> {
  bool _saved = false;

  VocabContext get _context {
    final precise = widget.wordInfo;
    if (precise != null) {
      return widget.controller.buildWordContext(
        precise,
        surroundingText: widget.surroundingText,
        anchorText: widget.word,
      );
    }

    return VocabContext.fromPdf(
      fileName: widget.pdfFileName,
      page: widget.pageIndex + 1,
      pageIndexHint: widget.pageIndex,
      surroundingText: widget.surroundingText,
      pdfPath: widget.controller.pdfPath,
      anchorText: widget.word,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<VocabularyProvider>();
    final existing = provider.findByWord(widget.word);

    if (existing != null && !_saved) {
      // Từ đã tồn tại → thêm context mới (Context-Accumulation).
      return _buildExistsState(provider);
    }

    if (_saved) return _buildSavedState();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: Color(0xFF1E2A3A), height: 20),
        Row(
          children: [
            Expanded(
              child: _QuickSaveButton(
                label: context.uiText('Lưu nhanh'),
                icon: Icons.bolt,
                color: const Color(0xFF4CAF50),
                onTap: () => _saveQuick(provider),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _QuickSaveButton(
                label: context.uiText('Lưu chi tiết'),
                icon: Icons.edit_note,
                color: const Color(0xFF2196F3),
                onTap: () => _saveWithDetails(provider),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Nghĩa tốt nhất hiện có: đã tra (mạng/từ điển) → lexicon nội bộ → rỗng.
  String get _meaning {
    final resolved = (widget.resolvedMeaning ?? '').trim();
    if (resolved.isNotEmpty) return resolved;
    return (widget.wordInfo?.analyzed?.meaning ?? '').trim();
  }

  /// IPA tốt nhất hiện có + provenance tương ứng.
  String? get _phonetic {
    final resolved = (widget.resolvedPhonetic ?? '').trim();
    if (resolved.isNotEmpty) return resolved;
    final analyzed = (widget.wordInfo?.analyzed?.phonetic ?? '').trim();
    return analyzed.isEmpty ? null : analyzed;
  }

  String? get _phoneticSource {
    if ((widget.resolvedPhonetic ?? '').trim().isNotEmpty) {
      return widget.phoneticSource;
    }
    return null;
  }

  void _saveQuick(VocabularyProvider provider) {
    final analysis = widget.wordInfo?.analyzed;
    final entry = provider.addWithAutoClassify(
      text: widget.word,
      meaning: _meaning,
      phonetic: _phonetic,
      phoneticSource: _phoneticSource,
      context: _context,
    );
    final example = widget.surroundingText.trim().isNotEmpty
        ? widget.surroundingText.trim()
        : analysis?.example?.trim() ?? '';
    if (example.isNotEmpty && (entry.example ?? '').trim().isEmpty) {
      provider.updateWord(entry.id, example: example);
    }
    widget.controller.refreshVocabularySignals();
    setState(() => _saved = true);
    HapticFeedback.lightImpact();
  }

  Future<void> _saveWithDetails(VocabularyProvider provider) async {
    final analysis = widget.wordInfo?.analyzed;
    final sourceContext = widget.surroundingText.trim().isNotEmpty
        ? widget.surroundingText.trim()
        : analysis?.example?.trim() ?? '';
    final details = await VocabQuickSaveSheet.show(
      context,
      word: widget.word,
      meaning: _meaning,
      phonetic: _phonetic ?? '',
      example: sourceContext,
      sourceContext: sourceContext,
    );
    if (details == null || !mounted) return;

    final entry = provider.addWithAutoClassify(
      text: widget.word,
      meaning: details.meaning,
      phonetic: details.phonetic.trim().isEmpty ? null : details.phonetic.trim(),
      phoneticSource: details.phonetic.trim().isEmpty ? null : _phoneticSource,
      context: _context,
    );
    if (details.example.trim().isNotEmpty &&
        (entry.example ?? '').trim().isEmpty) {
      provider.updateWord(entry.id, example: details.example.trim());
    }
    widget.controller.refreshVocabularySignals();
    setState(() => _saved = true);
    HapticFeedback.mediumImpact();
  }

  // ── Từ đã tồn tại → thêm context ──
  Widget _buildExistsState(VocabularyProvider provider) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Color(0xFFFFB300).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0xFFFFB300).withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFFFFB300), size: 16),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Đã có trong Wordlist',
                style: TextStyle(color: Color(0xFFFFB300), fontSize: 12)),
          ),
          GestureDetector(
            onTap: () {
              final existing = provider.findByWord(widget.word);
              if (existing != null) {
                provider.addContextToWord(existing.id, _context);
                widget.controller.refreshVocabularySignals();
              }
              setState(() => _saved = true);
              HapticFeedback.selectionClick();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Color(0xFFFFB300).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('+ Thêm ngữ cảnh',
                  style: TextStyle(
                      color: Color(0xFFFFB300),
                      fontSize: 10,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Đã lưu xong ──
  //
  // IMG-WEB-001: lưu nhanh xong là có thể gán hình NGAY tại đây (tìm ảnh trên
  // mạng qua API key) — chủ dự án yêu cầu chỗ "thêm từ" cũng có hình, không
  // chỉ trong màn sửa từ của Wordlist.
  Widget _buildSavedState() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Color(0xFF4CAF50).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 16),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('✅ Đã lưu vào Wordlist',
                style: TextStyle(color: Color(0xFF4CAF50), fontSize: 12)),
          ),
          VocabImageQuickAddButton(word: widget.word, compact: true),
        ],
      ),
    );
  }
}

class _QuickSaveButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickSaveButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ── Helper widgets ────────────────────────────────────────

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _CircleBtn(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.15),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _IconActionBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _IconActionBtn(
      {required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: context.uiText(tooltip),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white60, size: 18),
        ),
      ),
    );
  }
}

IconData _difficultyIcon(DifficultyLevel level) {
  switch (level) {
    case DifficultyLevel.easy:
      return Icons.sentiment_satisfied_alt;
    case DifficultyLevel.medium:
      return Icons.timelapse;
    case DifficultyLevel.hard:
      return Icons.local_fire_department;
    case DifficultyLevel.veryHard:
      return Icons.warning_amber_rounded;
  }
}
