// lib/widgets/karaoke_lyrics_line.dart
//
// Dòng lyrics kiểu karaoke: dòng đang phát sáng, dòng khác mờ; trong dòng
// đang phát, từng từ sáng dần theo timestamp (word-level highlight).

import 'package:flutter/material.dart';
import 'package:in2up_stt/stt_lrc_converter.dart';

class KaraokeLyricsLine extends StatelessWidget {
  final LrcLine line;
  final bool isActive;
  final List<LrcWord> words;
  final int activeWordIndex;

  const KaraokeLyricsLine({
    super.key,
    required this.line,
    required this.isActive,
    this.words = const [],
    this.activeWordIndex = -1,
  });

  @override
  Widget build(BuildContext context) {
    if (!isActive) {
      // Dòng không phát: mờ, nhỏ, không highlight từ
      return Text(
        line.text,
        style: TextStyle(
          color: Colors.grey[500],
          fontSize: 14,
          height: 1.4,
        ),
      );
    }

    // Dòng đang phát: to, đậm, sáng
    if (words.isEmpty || line.text.isEmpty) {
      return Text(
        line.text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          height: 1.4,
        ),
      );
    }

    // Word-level karaoke: highlight các từ đã phát
    final spans = <TextSpan>[];
    for (var i = 0; i < words.length; i++) {
      final w = words[i];
      final isSpoken = activeWordIndex >= i;
      spans.add(TextSpan(
        text: w.word,
        style: TextStyle(
          color: isSpoken ? Colors.white : Colors.grey[300],
          fontWeight: isSpoken ? FontWeight.w800 : FontWeight.w500,
          // Từ đang phát có màu nổi
          backgroundColor: i == activeWordIndex
              ? const Color(0xFF6C63FF).withValues(alpha: 0.45)
              : Colors.transparent,
        ),
      ));
      if (i < words.length - 1) {
        spans.add(const TextSpan(text: ' '));
      }
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 16,
          height: 1.4,
        ),
        children: spans,
      ),
    );
  }
}
