import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:in2up_ai/in2up_ai.dart';

import '../../../services/syntax_highlighter_service.dart';
import '../models/web_extraction_candidate.dart';
import '../web_reader_controller.dart';

class WebExtractionBatchSheet extends StatefulWidget {
  final WebReaderController controller;
  final String sourceLabel;
  final String sourceText;
  final bool fromSelection;

  const WebExtractionBatchSheet({
    super.key,
    required this.controller,
    required this.sourceLabel,
    required this.sourceText,
    required this.fromSelection,
  });

  static Future<void> show(
    BuildContext context, {
    required WebReaderController controller,
    required String sourceLabel,
    required String sourceText,
    required bool fromSelection,
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
      ),
    );
  }

  @override
  State<WebExtractionBatchSheet> createState() => _WebExtractionBatchSheetState();
}

class _WebExtractionBatchSheetState extends State<WebExtractionBatchSheet> {
  List<WebExtractionCandidate> _candidates = const [];
  bool _onlyNew = false;
  bool _onlyPhrases = false;
  bool _isEnriching = false;
  double _enrichProgress = 0;
  int _minLength = 4;
  WebExtractionSort _sort = WebExtractionSort.priority;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _rebuildCandidates();
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
      if (q.isEmpty) return true;
      return candidate.normalized.contains(q) ||
          candidate.sampleContext.toLowerCase().contains(q);
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
          facade.hasModel
              ? '✨ Đã làm giàu ${targets.length} mục bằng AI/local'
              : '✨ Đã làm giàu ${targets.length} mục bằng local/heuristic',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _importSelected() async {
    final result = widget.controller.importBatchToWordList(_candidates);
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.processedCount == 0
              ? 'Chưa có mục nào được nhập vào WordList'
              : '📚 WordList: thêm mới ${result.addedCount}, bổ sung ngữ cảnh ${result.updatedCount}',
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
                hintText: 'Tìm trong danh sách ứng viên...',
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
                                  const SizedBox(width: 8),
                                  Text(
                                    candidate.rankScore.toStringAsFixed(0),
                                    style: TextStyle(
                                      color: Colors.blue[200],
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
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
                                if (candidate.enriched) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    candidate.enrichSource == 'ai+local'
                                        ? '✨ AI/local'
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
                    onPressed: _selectedCount == 0 ? null : _importSelected,
                    icon: const Icon(Icons.library_add_check),
                    label: Text('Nhập $_selectedCount mục vào WordList'),
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
        label,
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
        label,
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
          'Min length $value',
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
          _label(sort),
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
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400], height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
