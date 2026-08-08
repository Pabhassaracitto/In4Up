// lib/screens/read_mode/widgets/colored_text_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:in2up_core/vocab_level_difficulty.dart';

import '../../../features/grammar/models/grammar_category.dart';
import '../../../features/grammar/models/grammar_highlight_settings.dart';
import '../../../features/grammar/models/grammar_palette.dart';
import '../../../features/grammar/services/grammar_style_mapper.dart';
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

class _MiniMark extends StatelessWidget {
  final Color color;
  final double width;

  const _MiniMark({required this.color, this.width = 16});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 2,
      margin: const EdgeInsets.only(top: 1),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(1),
      ),
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
    final grammarSettings =
        context.select<TextProvider, GrammarHighlightSettings>(
      (tp) => tp.grammarSettings,
    );
    final activePalette = context.select<TextProvider, GrammarPalette>(
      (tp) => tp.activeGrammarPalette,
    );
    final hasDifficulty = word.userDifficulty != null;
    final hasRecall = word.isSaved || word.hasSavedNotes || word.hasDueReview;

    final grammarCategory = grammarCategoryFromLegacyWordType(word.wordType);
    final useGrammarStyle =
        colorMode == ColorMode.wordType && grammarSettings.enabled;
    final grammarResolved = useGrammarStyle
        ? GrammarStyleMapper.resolve(
            category: grammarCategory,
            palette: activePalette,
            settings: grammarSettings,
            defaultTextColor: Colors.white,
          )
        : null;

    final bgColor = grammarResolved?.background ?? word.getBackgroundColor(colorMode);
    final textColor = grammarResolved?.foreground ?? word.getColor(colorMode);
    final borderColor = hasDifficulty
        ? word.userDifficulty!.color.withValues(alpha: 0.5)
        : word.hasDueReview
            ? Colors.redAccent.withValues(alpha: 0.45)
            : word.hasSavedNotes
                ? Colors.amber.withValues(alpha: 0.38)
                : word.isSaved
                    ? const Color(0xFF4CAF50).withValues(alpha: 0.28)
                    : grammarResolved?.outline ?? Colors.transparent;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        context.read<TextProvider>().speak(word.word);
      },
      onDoubleTap: () {
        _showQuickMeaning(context);
      },
      onLongPress: () {
        WordActionsSheet.show(context, word, lineIndex, wordIndex);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(4),
          border: hasDifficulty || hasRecall || grammarResolved?.outline != null
              ? Border.all(
                  color: borderColor,
                  width: hasDifficulty ? 1.5 : 1,
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
                fontWeight: grammarResolved?.fontWeight ??
                    (hasDifficulty || word.isSaved
                        ? FontWeight.bold
                        : FontWeight.normal),
                decoration: grammarResolved?.underline != null
                    ? TextDecoration.underline
                    : null,
                decorationColor: grammarResolved?.underline,
                decorationThickness: grammarResolved?.underline != null ? 2 : null,
                height: 1.6,
              ),
            ),
            if (hasDifficulty || hasRecall)
              Wrap(
                spacing: 3,
                runSpacing: 2,
                children: [
                  if (hasDifficulty)
                    _MiniMark(color: word.userDifficulty!.color),
                  if (word.isSaved)
                    const _MiniMark(color: Color(0xFF4CAF50), width: 6),
                  if (word.hasSavedNotes)
                    const _MiniMark(color: Colors.amber, width: 6),
                  if (word.hasDueReview)
                    const _MiniMark(color: Colors.redAccent, width: 6),
                ],
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
                    '${grammarCategoryFromLegacyWordType(word.wordType).labelVi} · ${word.cefrLevel.shortLabel}',
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
