import 'package:flutter/material.dart';
import 'package:in2up_core/vocab_level_difficulty.dart';
import 'package:provider/provider.dart';

import '../features/pdf_reader/pdf_reader_screen.dart';
import '../features/web_reader/web_reader_screen.dart';
import '../models/vocab_context.dart';
import '../models/word_entry.dart';
import '../providers/text_provider.dart';
import '../providers/vocabulary_provider.dart';
import '../services/text_library_service.dart';

class UnifiedKnowledgeSheet extends StatefulWidget {
  final WordEntry word;

  const UnifiedKnowledgeSheet({super.key, required this.word});

  static Future<void> show(BuildContext context, {required WordEntry word}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => UnifiedKnowledgeSheet(word: word),
    );
  }

  @override
  State<UnifiedKnowledgeSheet> createState() => _UnifiedKnowledgeSheetState();
}

class _UnifiedKnowledgeSheetState extends State<UnifiedKnowledgeSheet> {
  late final TextEditingController _notesCtrl;
  bool _editingNotes = false;

  @override
  void initState() {
    super.initState();
    _notesCtrl = TextEditingController(text: widget.word.personalNotes ?? '');
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VocabularyProvider>();
    final word = provider.allWords.firstWhere(
      (w) => w.id == widget.word.id,
      orElse: () => widget.word,
    );

    return FractionallySizedBox(
      heightFactor: 0.9,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
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
            _buildHeader(word),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMeaningCard(word),
                    const SizedBox(height: 12),
                    _buildDifficultySection(provider, word),
                    const SizedBox(height: 12),
                    _buildStatsSection(word),
                    const SizedBox(height: 12),
                    _buildQuickReviewSection(provider, word),
                    const SizedBox(height: 12),
                    _buildSourceMapSection(word),
                    const SizedBox(height: 12),
                    _buildNotesSection(provider, word),
                    const SizedBox(height: 12),
                    _buildTimelineSection(word),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(WordEntry word) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: word.vocabType.color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: word.vocabType.color.withValues(alpha: 0.25)),
          ),
          child: Text(
            word.vocabType.badge,
            style: TextStyle(
              color: word.vocabType.color,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                word.word,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if ((word.phonetic ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  word.phonetic!.trim(),
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontStyle: FontStyle.italic,
                    fontSize: 14,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip(word.vocabType.label(context), word.vocabType.color),
                  if (word.userDifficulty != null)
                    _chip(word.userDifficulty!.label, word.userDifficulty!.color),
                  if (word.hasAnyDue)
                    const _StatusChip(
                      label: 'Đến kỳ ôn',
                      color: Colors.redAccent,
                      icon: Icons.notifications_active_outlined,
                    ),
                  if ((word.personalNotes ?? '').trim().isNotEmpty)
                    const _StatusChip(
                      label: 'Có ghi chú',
                      color: Colors.amber,
                      icon: Icons.sticky_note_2_outlined,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMeaningCard(WordEntry word) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(icon: Icons.lightbulb_outline, title: 'Tri thức hiện tại'),
          const SizedBox(height: 10),
          Text(
            word.meaning.trim().isEmpty ? 'Chưa có nghĩa chi tiết' : word.meaning,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          if ((word.example ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Ví dụ: ${word.example!.trim()}',
              style: TextStyle(
                color: Colors.grey[300],
                height: 1.45,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDifficultySection(VocabularyProvider provider, WordEntry word) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(icon: Icons.flag_outlined, title: 'Độ khó dùng chung toàn hệ'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: DifficultyLevel.values.map((level) {
              final selected = word.userDifficulty == level;
              return GestureDetector(
                onTap: () => provider.updateDifficulty(word.id, level),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? level.color.withValues(alpha: 0.22)
                        : level.color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? level.color : level.color.withValues(alpha: 0.25),
                      width: selected ? 1.4 : 1,
                    ),
                  ),
                  child: Text(
                    level.label,
                    style: TextStyle(
                      color: selected ? level.color : level.color.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(WordEntry word) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(icon: Icons.insights_outlined, title: 'Tín hiệu ghi nhớ'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metric('Lần gặp', '${word.encounterCount}'),
              _metric('Nguồn', '${word.sourceFiles.length}'),
              _metric('Đúng', '${(word.accuracy * 100).round()}%'),
              _metric('Ôn', '${word.totalReviews}'),
              _metric('Mastery', '${(word.mastery * 100).round()}%'),
            ],
          ),
          if (word.nextReview != null) ...[
            const SizedBox(height: 10),
            Text(
              word.hasAnyDue
                  ? 'Cần ôn lại ngay'
                  : 'Ôn tiếp sau ${word.daysUntilDue} ngày',
              style: TextStyle(
                color: word.hasAnyDue ? Colors.redAccent : Colors.grey[300],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickReviewSection(VocabularyProvider provider, WordEntry word) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            icon: Icons.bolt_outlined,
            title: 'Ôn nhanh 3 chiều',
          ),
          const SizedBox(height: 10),
          _quickSkillRow(
            provider,
            word,
            Skill.understand,
            'Hiểu',
            const Color(0xFF42A5F5),
            word.understand,
          ),
          const SizedBox(height: 8),
          _quickSkillRow(
            provider,
            word,
            Skill.listen,
            'Nghe',
            const Color(0xFF66BB6A),
            word.listen,
          ),
          const SizedBox(height: 8),
          _quickSkillRow(
            provider,
            word,
            Skill.read,
            'Đọc',
            const Color(0xFFEF5350),
            word.read,
          ),
          if (word.hasAnyDue) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _sm2Button(provider, word, 1, 'Again 1d', Colors.redAccent),
                _sm2Button(provider, word, 3, 'Hard', Colors.orangeAccent),
                _sm2Button(provider, word, 4, 'Good', Colors.green),
                _sm2Button(provider, word, 5, 'Easy', Colors.blueAccent),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _quickSkillRow(
    VocabularyProvider provider,
    WordEntry word,
    Skill skill,
    String label,
    Color color,
    double value,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 6,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${(value * 100).round()}%',
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: '$label chưa chắc',
            onPressed: () => provider.quickAnswerWord(word.id, skill, false),
            icon: const Icon(Icons.close_rounded, color: Colors.redAccent),
          ),
          IconButton(
            tooltip: '$label ổn',
            onPressed: () => provider.quickAnswerWord(word.id, skill, true),
            icon: const Icon(Icons.check_rounded, color: Colors.greenAccent),
          ),
        ],
      ),
    );
  }

  Widget _sm2Button(
    VocabularyProvider provider,
    WordEntry word,
    int quality,
    String label,
    Color color,
  ) {
    return OutlinedButton(
      onPressed: () => provider.reviewWord(word.id, quality),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(label),
    );
  }

  Widget _buildSourceMapSection(WordEntry word) {
    final grouped = <String, int>{};
    for (final context in word.contexts) {
      grouped[context.sourceType] = (grouped[context.sourceType] ?? 0) + 1;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            icon: Icons.route_outlined,
            title: 'Bản đồ nguồn đã gặp',
          ),
          const SizedBox(height: 10),
          if (grouped.isEmpty)
            Text(
              'Chưa có dữ liệu nguồn.',
              style: TextStyle(color: Colors.grey[500]),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: grouped.entries.map((entry) {
                return _StatusChip(
                  label: '${_sourceTypeLabel(entry.key)} · ${entry.value}',
                  color: _sourceTypeColor(entry.key),
                  icon: _sourceTypeIcon(entry.key),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildNotesSection(VocabularyProvider provider, WordEntry word) {
    final notes = (word.personalNotes ?? '').trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: _SectionTitle(
                  icon: Icons.sticky_note_2_outlined,
                  title: 'Ghi chú hợp nhất',
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _editingNotes = !_editingNotes;
                    _notesCtrl.text = word.personalNotes ?? '';
                  });
                },
                icon: Icon(_editingNotes ? Icons.check : Icons.edit_note, size: 18),
                label: Text(_editingNotes ? 'Xong' : 'Sửa'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_editingNotes) ...[
            TextField(
              controller: _notesCtrl,
              maxLines: 6,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Nhập ghi chú tổng hợp cho từ này...',
                hintStyle: TextStyle(color: Colors.grey[500]),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () {
                  provider.updateNotes(word.id, _notesCtrl.text.trim());
                  setState(() => _editingNotes = false);
                },
                icon: const Icon(Icons.save_outlined, size: 18),
                label: const Text('Lưu ghi chú'),
              ),
            ),
          ] else
            Text(
              notes.isEmpty ? 'Chưa có ghi chú cá nhân' : notes,
              style: TextStyle(
                color: notes.isEmpty ? Colors.grey[500] : Colors.white,
                height: 1.45,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimelineSection(WordEntry word) {
    final contexts = List.of(word.contexts)
      ..sort((a, b) => b.encounteredAt.compareTo(a.encounteredAt));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            icon: Icons.timeline_outlined,
            title: 'Timeline gặp lại & mở nguồn',
          ),
          const SizedBox(height: 10),
          if (contexts.isEmpty)
            Text(
              'Chưa có ngữ cảnh nào được ghi lại.',
              style: TextStyle(color: Colors.grey[500]),
            )
          else
            ...contexts.take(12).map(
              (context) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(context.sourceIcon, style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.displaySource,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                        Text(
                          _formatEncounterAt(context.encounteredAt),
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.surroundingText,
                      style: TextStyle(
                        color: Colors.grey[300],
                        height: 1.45,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: context.canReopenSource
                            ? () => _openContextSource(context)
                            : null,
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: Text(context.reopenActionLabel),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openContextSource(VocabContext contextEntry) async {
    if (!contextEntry.canReopenSource || !mounted) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ref = contextEntry.sourceRef!;
    final type = contextEntry.sourceRefType!;

    if (type == 'pdfPath') {
      final pageHint = contextEntry.numericPositionHint;
      navigator.pop();
      navigator.push(
        MaterialPageRoute(
          builder: (_) => PdfReaderScreen(
            pdfPath: ref,
            initialPageIndex: pageHint == null ? null : pageHint - 1,
          ),
        ),
      );
      return;
    }

    if (type == 'webUrl') {
      navigator.pop();
      navigator.push(
        MaterialPageRoute(builder: (_) => WebReaderScreen(initialUrl: ref)),
      );
      return;
    }

    if (type == 'localText') {
      final tp = context.read<TextProvider>();
      await tp.loadTextFile(ref, title: contextEntry.sourceName);
      final lineHint = contextEntry.numericPositionHint;
      if (lineHint != null && tp.lines.isNotEmpty) {
        final target = (lineHint - 1).clamp(0, tp.lines.length - 1).toInt();
        tp.setCurrentLine(target);
      }
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('✅ Đã nạp nguồn vào Đọc / Text Studio'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (type == 'cloudText') {
      final service = TextLibraryService();
      final entry = await service.getById(ref);
      if (!mounted) return;
      if (entry == null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Không tìm thấy nguồn cloud để mở lại'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      final tp = context.read<TextProvider>();
      tp.loadFromString(
        entry.content,
        title: entry.title,
        sourceType: TextSourceType.cloud,
        cloudId: entry.id,
        category: entry.category,
      );
      final lineHint = contextEntry.numericPositionHint;
      if (lineHint != null && tp.lines.isNotEmpty) {
        final target = (lineHint - 1).clamp(0, tp.lines.length - 1).toInt();
        tp.setCurrentLine(target);
      }
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('☁️ Đã nạp nguồn cloud vào Đọc / Text Studio'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _formatEncounterAt(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inHours < 1) return '${diff.inMinutes}p';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays} ngày';
    return '${time.day.toString().padLeft(2, '0')}/${time.month.toString().padLeft(2, '0')}';
  }

  String _sourceTypeLabel(String sourceType) {
    switch (sourceType) {
      case 'pdf':
        return 'PDF';
      case 'web':
        return 'Web';
      case 'story':
        return 'Text';
      case 'clipboard':
        return 'Clipboard';
      case 'youtube':
        return 'YouTube';
      default:
        return sourceType;
    }
  }

  Color _sourceTypeColor(String sourceType) {
    switch (sourceType) {
      case 'pdf':
        return const Color(0xFFEF5350);
      case 'web':
        return const Color(0xFF42A5F5);
      case 'story':
        return const Color(0xFF66BB6A);
      case 'clipboard':
        return const Color(0xFF26C6DA);
      case 'youtube':
        return const Color(0xFFFF0000);
      default:
        return Colors.grey;
    }
  }

  IconData _sourceTypeIcon(String sourceType) {
    switch (sourceType) {
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'web':
        return Icons.language;
      case 'story':
        return Icons.menu_book_outlined;
      case 'clipboard':
        return Icons.content_paste_go_outlined;
      case 'youtube':
        return Icons.smart_display_outlined;
      default:
        return Icons.link_outlined;
    }
  }

  Widget _metric(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return _StatusChip(label: label, color: color, icon: null);
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[400]),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _StatusChip({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
