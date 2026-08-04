// lib/screens/read_mode/sheets/word_actions_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:in2up_core/vocab_level_difficulty.dart';

import '../../../models/vocab_context.dart';
import '../../../models/word_analysis.dart';
import '../../../providers/text_provider.dart';
import '../../../providers/vocabulary_provider.dart';
// XÓA: import 'package:in2up_core/vocab_level_difficulty.dart';
// XÓA: import '../../../models/segment.dart';

class WordActionsSheet {
  WordActionsSheet._();

  static void show(
    BuildContext context,
    AnalyzedWord word,
    int lineIndex,
    int wordIndex,
  ) {
    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (sheetContext) => _WordActionsContent(
        word: word,
        lineIndex: lineIndex,
        wordIndex: wordIndex,
      ),
    );
  }
}

class _WordActionsContent extends StatelessWidget {
  final AnalyzedWord word;
  final int lineIndex;
  final int wordIndex;

  const _WordActionsContent({
    required this.word,
    required this.lineIndex,
    required this.wordIndex,
  });

  @override
  Widget build(BuildContext context) {
    final tp = context.read<TextProvider>();

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ===== DRAG HANDLE =====
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ===== WORD HEADER =====
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: word.wordType.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: word.wordType.color.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  word.word,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: word.wordType.color,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _Badge(
                          label: word.wordType.labelVi,
                          color: word.wordType.color,
                        ),
                        _Badge(
                          label: word.cefrLevel.shortLabel,
                          color: word.cefrLevel.color,
                        ),
                        if (word.userDifficulty != null)
                          _Badge(
                            label: word.userDifficulty!.label,
                            color: word.userDifficulty!.color,
                          ),
                      ],
                    ),
                    if (word.meaning != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        word.meaning!,
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                          height: 1.3,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // Speak button
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  tp.speak(word.word);
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(0xFF2196F3).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.volume_up,
                    color: Color(0xFF2196F3),
                    size: 24,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ===== PHONETIC / EXAMPLE =====
          if (word.phonetic != null || word.example != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (word.phonetic != null) ...[
                    Row(
                      children: [
                        Icon(Icons.record_voice_over,
                            size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 6),
                        Text(
                          word.phonetic!,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (word.phonetic != null && word.example != null)
                    const SizedBox(height: 8),
                  if (word.example != null) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.format_quote,
                            size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            word.example!,
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

          // ===== DIFFICULTY MARKING =====
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Đánh dấu độ khó:',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: DifficultyLevel.values.map((level) {
              final isSelected = word.userDifficulty == level;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  tp.markWordDifficulty(lineIndex, wordIndex, level);
                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.check_circle,
                              color: level.color, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            '"${word.word}" → ${level.label} (${level.repeatCount}x)',
                          ),
                        ],
                      ),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: const Color(0xFF2A2A3E),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? level.color
                        : level.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: level.color.withValues(
                        alpha: isSelected ? 1.0 : 0.4,
                      ),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        level.label,
                        style: TextStyle(
                          color: isSelected ? Colors.white : level.color,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '${level.repeatCount}x lặp',
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white70
                              : level.color.withValues(alpha: 0.7),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          // ===== QUICK ACTIONS =====
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: word.word));
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('📋 Đã sao chép!'),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Sao chép'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[300],
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SaveToWordlistButton(
                  word: word,
                  lineIndex: lineIndex,
                  onSaved: () => Navigator.pop(context),
                ),
              ),
              /*Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    tp.saveWord(word);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.bookmark_added,
                                  color: Color(0xFF4CAF50), size: 18),
                              const SizedBox(width: 8),
                              Text('"${word.word}" đã lưu'),
                            ],
                          ),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: const Color(0xFF2A2A3E),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.playlist_add, size: 18),
                  label: const Text('Lưu từ'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4CAF50),
                    side: const BorderSide(
                      color: Color(0xFF4CAF50),
                      width: 0.8,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),*/
            ],
          ),

          const SizedBox(height: 12),

          // ===== WORD STATS =====
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                  label: 'Xuất hiện',
                  value: '${word.frequency ?? 1}x',
                  icon: Icons.repeat,
                ),
                Container(
                  width: 1,
                  height: 24,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                _StatItem(
                  label: 'Dòng',
                  value: '${lineIndex + 1}',
                  icon: Icons.format_list_numbered,
                ),
                Container(
                  width: 1,
                  height: 24,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                _StatItem(
                  label: 'Ký tự',
                  value: '${word.word.length}',
                  icon: Icons.text_fields,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===== REUSABLE BADGE WIDGET =====
class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 0.5,
        ),
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

// ===== STAT ITEM WIDGET =====
class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: Colors.grey[500]),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: Colors.grey[600], fontSize: 10),
        ),
      ],
    );
  }
}
// ═══════════════════════════════════════════════════════════════
// SAVE TO WORDLIST BUTTON — tích hợp VocabularyProvider
// ═══════════════════════════════════════════════════════════════

class _SaveToWordlistButton extends StatefulWidget {
  final AnalyzedWord word;
  final int lineIndex;
  final VoidCallback onSaved;

  const _SaveToWordlistButton({
    required this.word,
    required this.lineIndex,
    required this.onSaved,
  });

  @override
  State<_SaveToWordlistButton> createState() => _SaveToWordlistButtonState();
}

class _SaveToWordlistButtonState extends State<_SaveToWordlistButton> {
  bool _showMeaningInput = false;
  final _meaningCtrl = TextEditingController();

  @override
  void dispose() {
    _meaningCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vocabProvider = context.read<VocabularyProvider>();
    final alreadyExists = vocabProvider.hasWord(widget.word.word);

    if (alreadyExists) {
      return _buildExistsButton(vocabProvider);
    }

    if (_showMeaningInput) {
      return _buildMeaningInput(vocabProvider);
    }

    return _buildSaveButton(vocabProvider);
  }

  // ── Chưa có → hiện 2 nút ──────────────────────────────────

  Widget _buildSaveButton(VocabularyProvider vocabProvider) {
    return Row(
      children: [
        // Lưu nhanh (1 click)
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _saveQuick(vocabProvider),
            icon: const Icon(Icons.bolt, size: 16),
            label: const Text('Lưu nhanh'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF4CAF50),
              side: const BorderSide(color: Color(0xFF4CAF50), width: 0.8),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Lưu + nhập nghĩa
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => setState(() => _showMeaningInput = true),
            icon: const Icon(Icons.edit_note, size: 16),
            label: const Text('+ Nghĩa'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF2196F3),
              side: const BorderSide(color: Color(0xFF2196F3), width: 0.8),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  // ── Form nhập nghĩa (Cấp 2) ───────────────────────────────

  Widget _buildMeaningInput(VocabularyProvider vocabProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _meaningCtrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Nhập nghĩa tiếng Việt...',
                  hintStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: Color(0xFF2196F3), width: 1.5),
                  ),
                ),
                onSubmitted: (_) => _saveWithMeaning(vocabProvider),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _saveWithMeaning(vocabProvider),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 18),
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => setState(() => _showMeaningInput = false),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.close, color: Colors.grey, size: 18),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Đã tồn tại → thêm context ─────────────────────────────

  Widget _buildExistsButton(VocabularyProvider vocabProvider) {
    return OutlinedButton.icon(
      onPressed: () => _addContextOnly(vocabProvider),
      icon: const Icon(Icons.add_location_alt, size: 16),
      label: const Text('+ Thêm ngữ cảnh'),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFFFB300),
        side: const BorderSide(color: Color(0xFFFFB300), width: 0.8),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Actions ────────────────────────────────────────────────

  void _saveQuick(VocabularyProvider vocabProvider) {
    final tp = context.read<TextProvider>();
    final ctx = _buildContext(tp);

    vocabProvider.addWithAutoClassify(
      text: widget.word.word,
      meaning: widget.word.meaning ?? '',
      phonetic: widget.word.phonetic,
      context: ctx,
    );

    // Vẫn lưu vào old system (backward compat)
    tp.saveWord(widget.word);

    widget.onSaved();
    _showSavedSnack(context, widget.word.word);
  }

  void _saveWithMeaning(VocabularyProvider vocabProvider) {
    final tp = context.read<TextProvider>();
    final ctx = _buildContext(tp);
    final meaning = _meaningCtrl.text.trim();

    vocabProvider.addWithAutoClassify(
      text: widget.word.word,
      meaning: meaning.isNotEmpty ? meaning : (widget.word.meaning ?? ''),
      phonetic: widget.word.phonetic,
      context: ctx,
    );

    tp.saveWord(widget.word);
    widget.onSaved();
    _showSavedSnack(context, widget.word.word);
  }

  void _addContextOnly(VocabularyProvider vocabProvider) {
    final tp = context.read<TextProvider>();
    final ctx = _buildContext(tp);
    final existing = vocabProvider.findByWord(widget.word.word);
    if (existing != null) {
      vocabProvider.addContextToWord(existing.id, ctx);
    }
    widget.onSaved();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📌 Đã thêm ngữ cảnh mới cho "${widget.word.word}"'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF2A2A3E),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ── Build context từ TextProvider ─────────────────────────

  VocabContext _buildContext(TextProvider tp) {
    final title = tp.currentDocument?.title ?? 'Text Studio';
    final lineContent = widget.lineIndex < tp.lines.length
        ? tp.lines[widget.lineIndex].content
        : widget.word.word;

    return VocabContext.fromStory(
      storyTitle: title,
      lineIndex: widget.lineIndex,
      surroundingText: lineContent,
    );
  }

  static void _showSavedSnack(BuildContext context, String word) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.bookmark_added,
                color: Color(0xFF4CAF50), size: 18),
            const SizedBox(width: 8),
            Text('"$word" đã lưu vào Wordlist'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2A2A3E),
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
