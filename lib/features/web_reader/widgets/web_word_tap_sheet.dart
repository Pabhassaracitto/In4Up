import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/word_analysis.dart';
import '../web_reader_controller.dart';

/// Bottom sheet hiện khi tap vào từ trong Web Reader
class WebWordTapSheet extends StatelessWidget {
  final String word;
  final AnalyzedWord? analyzed;
  final WebReaderController controller;

  const WebWordTapSheet({
    super.key,
    required this.word,
    this.analyzed,
    required this.controller,
  });

  static void show(
    BuildContext context,
    String word,
    AnalyzedWord? analyzed,
    WebReaderController controller,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => WebWordTapSheet(
        word: word,
        analyzed: analyzed,
        controller: controller,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cleanWord =
        word.toLowerCase().replaceAll(RegExp(r"[^\w']"), '');

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

          // ── Word + Phonetic ───────────────────────────────
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
                    // CEFR + WordType tags
                    if (analyzed != null)
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _Tag(
                            label: analyzed!.cefrLevel.shortLabel,
                            color: _cefrColor(analyzed!.cefrLevel),
                          ),
                          if (analyzed!.wordType != WordType.unknown)
                            _Tag(
                              label: analyzed!.wordType.labelVi,
                              color: analyzed!.wordType.color,
                            ),
                        ],
                      ),
                  ],
                ),
              ),

              // Speak button
              GestureDetector(
                onTap: () => controller.speakWord(cleanWord),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF2196F3).withValues(alpha: 0.15),
                    border: Border.all(
                        color: const Color(0xFF2196F3).withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.volume_up_rounded,
                      color: Color(0xFF2196F3), size: 20),
                ),
              ),
            ],
          ),

          // ── Meaning ──────────────────────────────────────
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

          // ── CEFR level description ────────────────────────
          if (analyzed != null &&
              analyzed!.cefrLevel != CEFRLevel.unknown) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _cefrColor(analyzed!.cefrLevel),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${analyzed!.cefrLevel.shortLabel} — ${_cefrDescVi(analyzed!.cefrLevel)}',
                  style: TextStyle(
                      color: _cefrColor(analyzed!.cefrLevel).withValues(alpha: 0.9),
                      fontSize: 12),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),

          // ── Actions ──────────────────────────────────────
          Row(
            children: [
              // Save to Memory
              Expanded(
                flex: 3,
                child: GestureDetector(
                  onTap: () {
                    controller.saveWordToMemory(cleanWord,
                        analyzed: analyzed);
                    HapticFeedback.mediumImpact();
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('✅ Đã lưu "$cleanWord" vào Vườn Nhớ'),
                        backgroundColor: const Color(0xFF6C63FF),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color:
                              const Color(0xFF6C63FF).withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.psychology,
                            color: Color(0xFF6C63FF), size: 16),
                        SizedBox(width: 6),
                        Text('Lưu vào Vườn Nhớ',
                            style: TextStyle(
                                color: Color(0xFF6C63FF),
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Oxford dictionary
              _IconBtn(
                icon: Icons.open_in_new,
                tooltip: 'Oxford',
                onTap: () {
                  launchUrl(
                    Uri.parse(
                        'https://www.oxfordlearnersdictionaries.com/definition/english/$cleanWord'),
                    mode: LaunchMode.externalApplication,
                  );
                },
              ),

              const SizedBox(width: 6),

              // Copy
              _IconBtn(
                icon: Icons.copy,
                tooltip: 'Copy',
                onTap: () {
                  Clipboard.setData(ClipboardData(text: word));
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

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
            color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _IconBtn(
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
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white60, size: 18),
        ),
      ),
    );
  }
}

// Helper functions dùng explicit extension override
// tránh ambiguous_extension_member_access với CEFRLevelExtra

Color _cefrColor(CEFRLevel level) {
  switch (level) {
    case CEFRLevel.a1:
      return const Color(0xFF78909C);
    case CEFRLevel.a2:
      return const Color(0xFF42A5F5);
    case CEFRLevel.b1:
      return const Color(0xFF66BB6A);
    case CEFRLevel.b2:
      return const Color(0xFFFFCA28);
    case CEFRLevel.c1:
      return const Color(0xFFFF7043);
    case CEFRLevel.c2:
      return const Color(0xFFEF5350);
    case CEFRLevel.unknown:
      return Colors.grey;
  }
}

String _cefrDescVi(CEFRLevel level) {
  switch (level) {
    case CEFRLevel.a1:
      return 'Sơ cấp';
    case CEFRLevel.a2:
      return 'Căn bản';
    case CEFRLevel.b1:
      return 'Trung cấp';
    case CEFRLevel.b2:
      return 'Khá';
    case CEFRLevel.c1:
      return 'Nâng cao';
    case CEFRLevel.c2:
      return 'Thành thạo';
    case CEFRLevel.unknown:
      return 'Không rõ';
  }
}
