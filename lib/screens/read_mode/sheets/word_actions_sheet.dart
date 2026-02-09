// lib/screens/read_mode/sheets/word_actions_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
// KHÔNG DÙNG: import 'package:url_launcher/url_launcher.dart';

import '../../../models/word_analysis.dart';
import '../../../providers/text_provider.dart';

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
                    color: const Color(0xFF2196F3).withValues(alpha: 0.2),
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
              ),
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
