import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:in2up_core/vocab_level_difficulty.dart';

import '../../../models/segment.dart';
import '../../../models/vocab_context.dart';
import '../../../models/vocabulary_type.dart';
import '../../../providers/vocabulary_provider.dart';
import '../../../services/vocab_classifier.dart';
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
                color: Colors.white.withValues(alpha: 0.05),
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
                        color: d.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: d.color.withValues(alpha: 0.3),
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

          // ── Lưu vào Wordlist ─────────────────────────────
          PdfWordSaveSection(
            word: word,
            surroundingText: '', // AnalyzedWord model lacks surroundingText
            pdfFileName: controller.pdfPath.split(Platform.pathSeparator).last,
            pageIndex: wordInfo.pageIndex,
          ),
        ],
      ),
    );
  }
}

/// Widget lưu từ vào Wordlist từ PDF
/// Tích hợp vào PdfWordTapSheet hiện có
class PdfWordSaveSection extends StatefulWidget {
  final String word;
  final String surroundingText;
  final String pdfFileName;
  final int pageIndex;

  const PdfWordSaveSection({
    super.key,
    required this.word,
    required this.surroundingText,
    required this.pdfFileName,
    required this.pageIndex,
  });

  @override
  State<PdfWordSaveSection> createState() => _PdfWordSaveSectionState();
}

class _PdfWordSaveSectionState extends State<PdfWordSaveSection> {
  bool _saved = false;
  bool _showForm = false;
  final _meaningCtrl = TextEditingController();
  late VocabularyType _detectedType;

  @override
  void initState() {
    super.initState();
    _detectedType = VocabClassifier.classify(widget.word);
  }

  @override
  void dispose() {
    _meaningCtrl.dispose();
    super.dispose();
  }

  VocabContext get _context => VocabContext.fromPdf(
        fileName: widget.pdfFileName,
        page: widget.pageIndex + 1,
        surroundingText: widget.surroundingText,
      );

  @override
  Widget build(BuildContext context) {
    final provider = context.read<VocabularyProvider>();
    final alreadyExists = provider.hasWord(widget.word);

    if (alreadyExists && !_saved) {
      // Từ đã tồn tại → thêm context mới (Context-Accumulation)
      return _buildExistsState(provider);
    }

    if (_saved) {
      return _buildSavedState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: Color(0xFF1E2A3A), height: 20),

        // ── Cấp 1: Lưu nhanh (1 click) ──
        Row(
          children: [
            Expanded(
              child: _QuickSaveButton(
                label: 'Lưu nhanh',
                icon: Icons.bolt,
                color: const Color(0xFF4CAF50),
                onTap: () => _saveQuick(provider),
              ),
            ),
            const SizedBox(width: 8),
            // ── Cấp 2: Lưu có xác nhận ──
            Expanded(
              child: _QuickSaveButton(
                label: 'Lưu + nghĩa',
                icon: Icons.edit_note,
                color: const Color(0xFF2196F3),
                onTap: () => setState(() => _showForm = !_showForm),
              ),
            ),
          ],
        ),

        // ── Cấp 2: Inline form ──
        if (_showForm) ...[
          const SizedBox(height: 10),
          _buildInlineForm(provider),
        ],
      ],
    );
  }

  // ── Cấp 1: Save nhanh nhất ──
  void _saveQuick(VocabularyProvider provider) {
    provider.addWithAutoClassify(
      text: widget.word,
      meaning: '', // Sẽ bổ sung sau (Progressive Effort)
      context: _context,
    );
    setState(() => _saved = true);
    HapticFeedback.lightImpact();
  }

  // ── Cấp 2: Form xác nhận ──
  Widget _buildInlineForm(VocabularyProvider provider) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Color(0xFF2196F3).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Từ + loại
          Row(
            children: [
              Text(widget.word,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _detectedType.bgColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(_detectedType.label(context),
                    style: TextStyle(
                        color: _detectedType.color,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Nghĩa input
          TextField(
            controller: _meaningCtrl,
            autofocus: true,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Nhập nghĩa...',
              hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: Color(0xFF2196F3), width: 1.5)),
            ),
            onSubmitted: (_) => _saveWithMeaning(provider),
          ),
          const SizedBox(height: 8),

          // Save button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _saveWithMeaning(provider),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('✓ Lưu',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  void _saveWithMeaning(VocabularyProvider provider) {
    provider.addWithAutoClassify(
      text: widget.word,
      meaning: _meaningCtrl.text.trim(),
      context: _context,
    );
    setState(() {
      _saved = true;
      _showForm = false;
    });
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
              // Thêm context mới (Context-Accumulation)
              final existing = provider.findByWord(widget.word);
              if (existing != null) {
                provider.addContextToWord(existing.id, _context);
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
  Widget _buildSavedState() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Color(0xFF4CAF50).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 16),
          SizedBox(width: 8),
          Text('✅ Đã lưu vào Wordlist',
              style: TextStyle(color: Color(0xFF4CAF50), fontSize: 12)),
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
      message: tooltip,
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
