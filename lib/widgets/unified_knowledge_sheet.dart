import 'package:flutter/material.dart';
import 'package:in2up_core/vocab_level_difficulty.dart';
import 'package:provider/provider.dart';

import '../models/word_entry.dart';
import '../providers/vocabulary_provider.dart';

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
                    _buildNotesSection(provider, word),
                    const SizedBox(height: 12),
                    _buildContextsSection(word),
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

  Widget _buildContextsSection(WordEntry word) {
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
          const _SectionTitle(icon: Icons.hub_outlined, title: 'Bản đồ ngữ cảnh đã gặp'),
          const SizedBox(height: 10),
          if (contexts.isEmpty)
            Text(
              'Chưa có ngữ cảnh nào được ghi lại.',
              style: TextStyle(color: Colors.grey[500]),
            )
          else
            ...contexts.take(6).map(
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
                  ],
                ),
              ),
            ),
        ],
      ),
    );
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
