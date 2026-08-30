import 'package:in4up/core/language/localized_material.dart';
import 'package:provider/provider.dart';

import '../models/vocab_context.dart';
import '../models/vocabulary_type.dart';
import '../providers/vocabulary_bridge.dart';
import '../providers/vocabulary_provider.dart';
import '../services/vocab_batch/vocab_batch_extractor.dart';
import '../services/vocab_batch/vocab_batch_models.dart';
import 'vocab_entry_meta.dart';

/// ═══════════════════════════════════════════════════════════════
/// SELECTION SAVE SHEET — lưu đoạn chọn vào WordList
/// (READ-630-01 + READ-630-04)
///
/// Dùng chung cho tab Đọc: PDF (bôi chọn nhiều dòng ở mode không
/// màu) + Web (đoạn chọn).
///
///  * Chế độ 1 — "Lưu nguyên cụm/câu": cả đoạn chọn thành 1 entry
///    (từ/cụm/câu tự phân loại), kèm chọn/tạo CHỦ ĐỀ + NGÔN NGỮ.
///  * Chế độ 2 — "Lưu thông minh (hàng loạt)": trích nhiều
///    từ/cụm/câu từ đoạn (extractor dùng chung), tick chọn từng
///    mục, làm giàu local (nghĩa + IPA), 1 lần áp topic + language
///    cho TẤT CẢ → nhập cùng lúc.
///
/// Entry đã tồn tại: chỉ BỔ SUNG ngữ cảnh + tag topic/language —
/// không ghi đè nghĩa/IPA có sẵn, không mất dữ liệu.
/// ═══════════════════════════════════════════════════════════════
class SelectionSaveSheet {
  static Future<void> show(
    BuildContext context, {
    required String text,
    required String sourceLabel,
    String? sourceDetail,
    VocabContext Function(String sampleText)? contextBuilder,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF111827),
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SelectionSaveSheetView(
        text: text,
        sourceLabel: sourceLabel,
        sourceDetail: sourceDetail,
        contextBuilder: contextBuilder,
      ),
    );
  }
}

class SelectionSaveSheetView extends StatefulWidget {
  final String text;
  final String sourceLabel;
  final String? sourceDetail;
  final VocabContext Function(String sampleText)? contextBuilder;

  const SelectionSaveSheetView({
    super.key,
    required this.text,
    required this.sourceLabel,
    this.sourceDetail,
    this.contextBuilder,
  });

  @override
  State<SelectionSaveSheetView> createState() => _SelectionSaveSheetViewState();
}

class _SelectionSaveSheetViewState extends State<SelectionSaveSheetView> {
  bool _batchMode = false;
  List<WebExtractionCandidate> _candidates = const [];
  String? _selectedTopic;
  String _selectedLanguage = 'en';
  final TextEditingController _newTopicCtrl = TextEditingController();

  @override
  void dispose() {
    _newTopicCtrl.dispose();
    super.dispose();
  }

  void _enterBatchMode() {
    final candidates = VocabBatchExtractor.extract(
      widget.text,
      minLength: 3,
      maxItems: 60,
      includePhrases: true,
      allowSingleMentionPhrases: true,
      pageTitle: widget.sourceLabel,
    );
    // Làm giàu local ngay (offline, nhanh)
    for (final c in candidates) {
      VocabBatchExtractor.enrichCandidateLocally(
        c,
        pageTitle: widget.sourceLabel,
      );
    }
    setState(() {
      _batchMode = true;
      _candidates = candidates;
    });
  }

  void _saveWholeSelection() {
    final text = widget.text.trim();
    if (text.isEmpty) return;
    final wordCount = text.split(RegExp(r'\s+')).length;
    final type = wordCount == 1
        ? VocabularyType.word
        : (wordCount > 6
            ? VocabularyType.sentence
            : VocabularyType.phrase);

    final isNew = !VocabularyBridge.hasWord(text.toLowerCase());
    VocabularyBridge.addContextual(
      text: text,
      meaning: '',
      example: text,
      forceType: type,
      topic: _selectedTopic,
      language: _selectedLanguage,
      context: widget.contextBuilder?.call(text),
    );
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '${isNew ? '✅ Đã lưu' : '✅ Đã bổ sung ngữ cảnh + tag'} '
          '"${text.length > 40 ? '${text.substring(0, 40)}…' : text}" '
          '${_selectedTopic != null ? '· #$_selectedTopic ' : ''}'
          '· ${labelForLanguage(_selectedLanguage)}',
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1E5F3A),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _importSelected() {
    // Áp topic + language đã chọn cho toàn bộ mục đã tick
    for (final c in _candidates) {
      if (!c.selected) continue;
      if (_selectedTopic != null) c.topic = _selectedTopic;
      c.language = _selectedLanguage;
    }
    final result = VocabBatchImporter.import(
      _candidates,
      contextBuilder: (sample, c) =>
          widget.contextBuilder?.call(sample) ??
          VocabContext.fromWeb(
            url: widget.sourceLabel,
            pageTitle: widget.sourceLabel,
            surroundingText: sample,
          ),
    );
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '📚 WordList: thêm mới ${result.addedCount}, '
          'bổ sung ngữ cảnh ${result.updatedCount}, '
          'bỏ qua ${result.skippedCount}'
          '${_selectedTopic != null ? ' · #$_selectedTopic' : ''}',
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1E5F3A),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  int get _selectedCount =>
      _candidates.where((c) => c.selected).length;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<VocabularyProvider>();
    final topicOptions = provider.allTopics.toList()..sort();
    final languageOptions =
        (provider.allLanguages.toList()..sort()).toSet()
          ..addAll(['en', 'vi', 'pali', 'my']);
    final sortedLangs = languageOptions.toList()..sort();

    return FractionallySizedBox(
      heightFactor: 0.9,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
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
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Lưu vào WordList',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _batchMode
                      ? () => setState(() {
                            _batchMode = false;
                            _candidates = const [];
                          })
                      : _enterBatchMode,
                  icon: Icon(
                    _batchMode
                        ? Icons.text_snippet_outlined
                        : Icons.auto_fix_high,
                    size: 17,
                  ),
                  label: Text(
                    _batchMode
                        ? 'Về lưu nguyên cụm'
                        : 'Lưu thông minh (hàng loạt)',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            Text(
              '${widget.sourceLabel}${widget.sourceDetail != null ? ' · ${widget.sourceDetail!}' : ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                widget.text,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // ── Chủ đề (chọn có sẵn / tạo mới) ─────────────
            const Text(
              'Chủ đề',
              style: TextStyle(
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
                for (final t in topicOptions)
                  ChoiceChip(
                    label: Text(
                      t,
                      style: TextStyle(
                        color: _selectedTopic == t
                            ? Colors.white
                            : Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                    selected: _selectedTopic == t,
                    selectedColor: const Color(0xFFFF9800),
                    backgroundColor: Colors.white.withValues(alpha: 0.04),
                    side: BorderSide(
                      color: _selectedTopic == t
                          ? const Color(0xFFFF9800)
                          : Colors.white.withValues(alpha: 0.1),
                    ),
                    onSelected: (value) => setState(() {
                      _selectedTopic = value ? t : (_selectedTopic == t ? null : _selectedTopic);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newTopicCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Tạo chủ đề mới… (Enter để chọn)',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 12,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.04),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(9),
                        borderSide:
                            BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(9),
                        borderSide: const BorderSide(color: Color(0xFFFF9800)),
                      ),
                    ),
                    onSubmitted: (value) {
                      final v = value.trim();
                      if (v.isEmpty) return;
                      setState(() => _selectedTopic = v);
                      _newTopicCtrl.clear();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ── Ngôn ngữ ───────────────────────────────────
            const Text(
              'Ngôn ngữ',
              style: TextStyle(
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
                        color: _selectedLanguage == lang
                            ? Colors.white
                            : Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                    selected: _selectedLanguage == lang,
                    selectedColor: const Color(0xFF42A5F5),
                    backgroundColor: Colors.white.withValues(alpha: 0.04),
                    side: BorderSide(
                      color: _selectedLanguage == lang
                          ? const Color(0xFF42A5F5)
                          : Colors.white.withValues(alpha: 0.1),
                    ),
                    onSelected: (value) {
                      if (value) setState(() => _selectedLanguage = lang);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Nội dung theo chế độ ────────────────────────
            Expanded(
              child: _batchMode
                  ? _buildBatchList()
                  : const SizedBox.shrink(),
            ),

            // ── Nút hành động ───────────────────────────────
            if (_batchMode)
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => setState(() {
                      for (final c in _candidates) {
                        c.selected = !c.existed;
                      }
                    }),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text(
                      'Chỉ chọn mục MỚI',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Đã chọn: $_selectedCount',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: const Text('Đóng'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _batchMode
                        ? (_selectedCount == 0 ? null : _importSelected)
                        : _saveWholeSelection,
                    icon: Icon(_batchMode
                        ? Icons.library_add_check
                        : Icons.bookmark_add),
                    label: Text(_batchMode
                        ? 'Nhập $_selectedCount mục cùng lúc'
                        : 'Lưu nguyên cụm/câu'),
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

  Widget _buildBatchList() {
    if (_candidates.isEmpty) {
      return const Center(
        child: Text(
          'Không tìm thấy từ/cụm nào đủ giá trị trong đoạn này.',
          style: TextStyle(color: Colors.white38, fontSize: 13),
        ),
      );
    }
    return ListView.separated(
      itemCount: _candidates.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: Colors.white.withValues(alpha: 0.06),
      ),
      itemBuilder: (context, index) {
        final c = _candidates[index];
        return CheckboxListTile(
          dense: true,
          value: c.selected,
          activeColor: const Color(0xFF42A5F5),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 2,
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  c.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
              ),
              if (c.isPhrase)
                _MiniBadge(
                  label: 'cụm ${c.wordCount}w',
                  color: const Color(0xFF64B5F6),
                ),
              _MiniBadge(
                label: c.existed ? 'đã có' : 'mới',
                color: c.existed ? Colors.orangeAccent : Colors.greenAccent,
              ),
              _MiniBadge(label: 'x${c.frequency}', color: Colors.blueAccent),
            ],
          ),
          subtitle: c.meaning.trim().isNotEmpty
              ? Text(
                  c.meaning.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.green[200],
                    fontSize: 11.5,
                    height: 1.3,
                  ),
                )
              : null,
          onChanged: (value) => setState(() => c.selected = value ?? false),
        );
      },
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
      margin: const EdgeInsets.only(left: 5),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w700),
      ),
    );
  }
}
