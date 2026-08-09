// lib/widgets/karaoke_lyrics_line.dart
//
// Dòng lyrics kiểu karaoke: dòng đang phát sáng, dòng khác mờ; trong dòng
// đang phát, từng từ sáng dần theo timestamp (word-level highlight).
// Hỗ trợ tuỳ chỉnh: cỡ chữ, màu, căn lề, hiện bản dịch (KaraokeStyle).

import 'package:flutter/material.dart';
import 'package:in2up/providers/karaoke_settings_provider.dart';
import 'package:in2up_stt/stt_lrc_converter.dart';

class KaraokeLyricsLine extends StatelessWidget {
  final LrcLine line;
  final bool isActive;
  final List<LrcWord> words;
  final int activeWordIndex;
  final KaraokeStyle style;

  const KaraokeLyricsLine({
    super.key,
    required this.line,
    required this.isActive,
    this.words = const [],
    this.activeWordIndex = -1,
    this.style = const KaraokeStyle(),
  });

  @override
  Widget build(BuildContext context) {
    final align = style.textAlign;

    if (!isActive) {
      // Dòng không phát: mờ, nhỏ, không highlight từ
      return Text(
        line.text,
        textAlign: align,
        style: TextStyle(
          color: style.inactiveColor,
          fontSize: style.inactiveFontSize,
          height: 1.4,
        ),
      );
    }

    // Dòng đang phát: to, đậm, sáng
    if (words.isEmpty || line.text.isEmpty) {
      return Text(
        line.text,
        textAlign: align,
        style: TextStyle(
          color: style.activeColor,
          fontSize: style.fontSize,
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
          color: isSpoken ? style.activeColor : style.inactiveColor,
          fontWeight: isSpoken ? FontWeight.w800 : FontWeight.w500,
          // Từ đang phát có màu nổi
          backgroundColor: i == activeWordIndex
              ? style.highlightBackground.withValues(alpha: 0.45)
              : Colors.transparent,
        ),
      ));
      if (i < words.length - 1) {
        spans.add(const TextSpan(text: ' '));
      }
    }

    return RichText(
      textAlign: align,
      text: TextSpan(
        style: TextStyle(
          fontSize: style.fontSize,
          height: 1.4,
        ),
        children: spans,
      ),
    );
  }
}
