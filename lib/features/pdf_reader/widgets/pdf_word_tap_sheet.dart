import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/word_analysis.dart';
import '../pdf_reader_controller.dart';
import '../models/pdf_word_info.dart';

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

class _WordSheet extends StatelessWidget {
  final PdfWordInfo wordInfo;
  final PdfReaderController controller;

  const _WordSheet({required this.wordInfo, required this.controller});

  @override
  Widget build(BuildContext context) {
    final analyzed = wordInfo.analyzed;
    final word = wordInfo.text.replaceAll(RegExp(r'[^\w\s]'), '').trim();

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
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
                      word,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (analyzed?.phonetic != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        analyzed!.phonetic!,
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                        ),
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
                      ],
                    ),
                  ],
                ),
              ),

              // Speak button
              _CircleBtn(
                icon: Icons.volume_up_rounded,
                color: const Color(0xFF2196F3),
                onTap: () => controller.speakText(word),
              ),
            ],
          ),

          // Meaning
          if (analyzed?.meaning != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Text('💡 ', style: TextStyle(fontSize: 16)),
                  Expanded(
                    child: Text(
                      analyzed!.meaning!,
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
                    controller.saveWordToMemory(wordInfo);
                    HapticFeedback.mediumImpact();
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('✅ Đã lưu "$word" vào Vườn Nhớ'),
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

              // Tra từ điển online
              _IconActionBtn(
                icon: Icons.open_in_new,
                tooltip: 'Tra từ điển',
                onTap: () {
                  final url =
                      'https://www.oxfordlearnersdictionaries.com/definition/english/$word';
                  launchUrl(Uri.parse(url),
                      mode: LaunchMode.externalApplication);
                },
              ),

              const SizedBox(width: 8),

              // Copy
              _IconActionBtn(
                icon: Icons.copy,
                tooltip: 'Copy',
                onTap: () {
                  Clipboard.setData(ClipboardData(text: word));
                  Navigator.pop(context);
                },
              ),
            ],
          ),

          // Difficulty markers
          const SizedBox(height: 12),
          const Text(
            'Đánh dấu độ khó:',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            children: DifficultyLevel.values.map((d) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: GestureDetector(
                    onTap: () {
                      // Lưu difficulty cho từ này
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: d.color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: d.color.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(d.icon, color: d.color, size: 16),
                          const SizedBox(height: 2),
                          Text(
                            d.label,
                            style: TextStyle(color: d.color, fontSize: 9),
                          ),
                        ],
                      ),
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
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
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
          color: color.withOpacity(0.15),
          border: Border.all(color: color.withOpacity(0.3)),
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
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
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
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white60, size: 18),
        ),
      ),
    );
  }
}

// Extensions cần thêm vào DifficultyLevel (nếu chưa có)
extension DifficultyLevelUI on DifficultyLevel {
  Color get color {
    switch (this) {
      case DifficultyLevel.easy:
        return const Color(0xFF4CAF50);
      case DifficultyLevel.medium:
        return const Color(0xFFFF9800);
      case DifficultyLevel.hard:
        return const Color(0xFFEF5350);
      case DifficultyLevel.veryHard:
        return const Color(0xFF9C27B0);
    }
  }

  IconData get icon {
    switch (this) {
      case DifficultyLevel.easy:
        return Icons.sentiment_satisfied;
      case DifficultyLevel.medium:
        return Icons.sentiment_neutral;
      case DifficultyLevel.hard:
        return Icons.sentiment_dissatisfied;
      case DifficultyLevel.veryHard:
        return Icons.sentiment_very_dissatisfied;
    }
  }

  String get label {
    switch (this) {
      case DifficultyLevel.easy:
        return 'Dễ';
      case DifficultyLevel.medium:
        return 'Vừa';
      case DifficultyLevel.hard:
        return 'Khó';
      case DifficultyLevel.veryHard:
        return 'Rất khó';
    }
  }
}
