// lib/widgets/karaoke_lyrics_line.dart
//
// Dòng lyrics kiểu karaoke: dòng đang phát sáng, dòng khác mờ; trong dòng
// đang phát, từng từ sáng dần theo timestamp (word-level highlight).
// Hỗ trợ tuỳ chỉnh: cỡ chữ, màu, căn lề, hiện bản dịch (KaraokeStyle).
// Fix audit: thêm hỗ trợ hiện bản dịch nếu có (từ TextProvider hoặc LRC translation).

import 'dart:math' as math;

import 'package:flutter/material.dart' as material;
import 'package:in4up/core/language/localized_material.dart';
import 'package:in4up/providers/karaoke_settings_provider.dart';
import 'package:in4up_stt/stt_lrc_converter.dart';

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

    // These are source/user strings, never UI chrome to translate.
    Widget plainLine() => material.Text(
      line.text,
      textAlign: align,
      style: TextStyle(
        color: isActive ? style.activeColor : style.inactiveColor,
        fontSize: isActive
            ? style.fontSize
            : math.min(style.inactiveFontSize, style.fontSize * .85),
        fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
        height: 1.4,
      ),
    );

    Widget mainLine;
    if (!isActive || words.isEmpty || line.text.isEmpty) {
      mainLine = plainLine();
    } else {
      // Match each timed token back into the original text rather than joining
      // tokens with invented spaces (which corrupts punctuation/CJK text).
      final spans = <TextSpan>[];
      var cursor = 0;
      var matchesOriginal = true;
      final unspoken = Color.lerp(style.inactiveColor, style.activeColor, .6)!;
      for (var i = 0; i < words.length; i++) {
        final word = words[i].word.trim();
        if (word.isEmpty) continue;
        final offset = line.text.indexOf(word, cursor);
        if (offset < 0) {
          matchesOriginal = false;
          break;
        }
        if (offset > cursor) {
          spans.add(TextSpan(text: line.text.substring(cursor, offset)));
        }
        final isSpoken = activeWordIndex >= i;
        spans.add(TextSpan(
          text: line.text.substring(offset, offset + word.length),
          style: TextStyle(
            color: isSpoken ? style.activeColor : unspoken,
            fontWeight: isSpoken ? FontWeight.w800 : FontWeight.w500,
            backgroundColor: i == activeWordIndex
                ? style.highlightBackground.withValues(alpha: 0.45)
                : Colors.transparent,
          ),
        ));
        cursor = offset + word.length;
      }
      if (!matchesOriginal || cursor == 0) {
        // Some STT engines tokenize differently from their transcript. Keep
        // the exact transcript visible rather than showing wrong words.
        mainLine = plainLine();
      } else {
        if (cursor < line.text.length) {
          spans.add(TextSpan(text: line.text.substring(cursor)));
        }
        mainLine = RichText(
          textAlign: align,
          text: TextSpan(
            style: TextStyle(
              color: style.activeColor,
              fontSize: style.fontSize,
              height: 1.4,
            ),
            children: spans,
          ),
        );
      }
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
          child: material.Text(
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
