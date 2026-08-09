// lib/widgets/karaoke_lyrics_line.dart
//
// Dòng lyrics kiểu karaoke: dòng đang phát sáng, dòng khác mờ; trong dòng
// đang phát, từng từ sáng dần theo timestamp (word-level highlight).
// Hỗ trợ tuỳ chỉnh: cỡ chữ, màu, căn lề, hiện bản dịch (KaraokeStyle).
// Fix audit: thêm hỗ trợ hiện bản dịch nếu có (từ TextProvider hoặc LRC translation).

import 'package:flutter/material.dart';
import 'package:in2up/providers/karaoke_settings_provider.dart';
import 'package:in2up_stt/stt_lrc_converter.dart';

class KaraokeLyricsLine extends StatelessWidget {
  final LrcLine line;
  final bool isActive;
  final List<LrcWord> words;
  final int activeWordIndex;
  final KaraokeStyle style;
  final String? translation; // optional bản dịch

  const KaraokeLyricsLine({
    super.key,
    required this.line,
    required this.isActive,
    this.words = const [],
    this.activeWordIndex = -1,
    this.style = const KaraokeStyle(),
    this.translation,
  });

  @override
  Widget build(BuildContext context) {
    final align = style.textAlign;
    final showTrans = style.showTranslation &&
        translation != null &&
        translation!.trim().isNotEmpty;

    Widget mainLine;
    if (!isActive) {
      mainLine = Text(
        line.text,
        textAlign: align,
        style: TextStyle(
          color: style.inactiveColor,
          fontSize: style.inactiveFontSize,
          height: 1.4,
        ),
      );
    } else if (words.isEmpty || line.text.isEmpty) {
      mainLine = Text(
        line.text,
        textAlign: align,
        style: TextStyle(
          color: style.activeColor,
          fontSize: style.fontSize,
          fontWeight: FontWeight.w700,
          height: 1.4,
        ),
      );
    } else {
      final spans = <TextSpan>[];
      for (var i = 0; i < words.length; i++) {
        final w = words[i];
        final isSpoken = activeWordIndex >= i;
        spans.add(TextSpan(
          text: w.word,
          style: TextStyle(
            color: isSpoken ? style.activeColor : style.inactiveColor,
            fontWeight: isSpoken ? FontWeight.w800 : FontWeight.w500,
            backgroundColor: i == activeWordIndex
                ? style.highlightBackground.withValues(alpha: 0.45)
                : Colors.transparent,
          ),
        ));
        if (i < words.length - 1) {
          spans.add(const TextSpan(text: ' '));
        }
      }
      mainLine = RichText(
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

    if (!showTrans) return mainLine;

    return Column(
      crossAxisAlignment: align == TextAlign.center
          ? CrossAxisAlignment.center
          : align == TextAlign.right
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
      children: [
        mainLine,
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            translation!,
            textAlign: align,
            style: TextStyle(
              color: (isActive ? Colors.white70 : Colors.grey[500]),
              fontSize: (style.fontSize - 3).clamp(10.0, 18.0),
              fontStyle: FontStyle.italic,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
