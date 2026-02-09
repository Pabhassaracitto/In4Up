// lib/screens/read_mode/widgets/colored_text_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../models/color_mode.dart';
import '../../../models/word_analysis.dart';
import '../../../providers/text_provider.dart';
import '../sheets/word_actions_sheet.dart';

class ColoredTextWidget extends StatelessWidget {
  final List<AnalyzedWord> words;
  final double fontSize;
  final ColorMode colorMode;
  final int lineIndex;

  const ColoredTextWidget({
    super.key,
    required this.words,
    required this.fontSize,
    required this.colorMode,
    required this.lineIndex,
  });

  @override
  Widget build(BuildContext context) {
    if (words.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 3,
      runSpacing: 4,
      children: words.asMap().entries.map((entry) {
        final wordIndex = entry.key;
        final word = entry.value;

        return _ColoredWord(
          word: word,
          wordIndex: wordIndex,
          lineIndex: lineIndex,
          fontSize: fontSize,
          colorMode: colorMode,
        );
      }).toList(),
    );
  }
}

class _ColoredWord extends StatelessWidget {
  final AnalyzedWord word;
  final int wordIndex;
  final int lineIndex;
  final double fontSize;
  final ColorMode colorMode;

  const _ColoredWord({
    required this.word,
    required this.wordIndex,
    required this.lineIndex,
    required this.fontSize,
    required this.colorMode,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = word.getBackgroundColor(colorMode);
    final textColor = word.getColor(colorMode);
    final hasDifficulty = word.userDifficulty != null;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        // Tap = phát âm
        context.read<TextProvider>().speak(word.word);
      },
      onDoubleTap: () {
        // Double tap = xem nghĩa nhanh
        _showQuickMeaning(context);
      },
      onLongPress: () {
        // Long press = full word actions
        WordActionsSheet.show(context, word, lineIndex, wordIndex);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(4),
          border: hasDifficulty
              ? Border.all(
                  color: word.userDifficulty!.color.withValues(alpha: 0.5),
                  width: 1.5,
                )
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              word.word,
              style: TextStyle(
                fontSize: fontSize,
                color: textColor,
                fontWeight: hasDifficulty ? FontWeight.bold : FontWeight.normal,
                height: 1.6,
              ),
            ),
            // Mini difficulty indicator
            if (hasDifficulty)
              Container(
                width: 16,
                height: 2,
                margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(
                  color: word.userDifficulty!.color,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showQuickMeaning(BuildContext context) {
    if (word.meaning == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: word.wordType.color.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                word.word,
                style: TextStyle(
                  color: word.wordType.color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    word.meaning!,
                    style: const TextStyle(color: Colors.white),
                  ),
                  Text(
                    '${word.wordType.labelVi} · ${word.cefrLevel.shortLabel}',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2A2A3E),
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      ),
    );
  }
}
