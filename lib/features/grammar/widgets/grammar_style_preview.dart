import 'package:in4up/core/language/localized_material.dart';

import '../models/grammar_category.dart';
import '../models/grammar_highlight_settings.dart';
import '../models/grammar_palette.dart';
import '../services/grammar_style_mapper.dart';

class GrammarStylePreview extends StatelessWidget {
  final GrammarHighlightSettings settings;
  final GrammarPalette palette;

  const GrammarStylePreview({
    super.key,
    required this.settings,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    const preview = [
      (GrammarCategory.pronoun, 'She'),
      (GrammarCategory.auxiliary, 'has'),
      (GrammarCategory.verb, 'built'),
      (GrammarCategory.determiner, 'a'),
      (GrammarCategory.adjective, 'beautiful'),
      (GrammarCategory.noun, 'habit'),
      (GrammarCategory.preposition, 'for'),
      (GrammarCategory.verb, 'reading'),
      (GrammarCategory.adverb, 'daily'),
      (GrammarCategory.punctuation, '.'),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: preview.map((entry) {
          final resolved = GrammarStyleMapper.resolve(
            category: entry.$1,
            palette: palette,
            settings: settings,
            defaultTextColor: Colors.white,
          );
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: resolved.background,
              borderRadius: BorderRadius.circular(6),
              border: resolved.outline == null
                  ? null
                  : Border.all(color: resolved.outline!),
            ),
            child: Text(
              entry.$2,
              style: TextStyle(
                color: resolved.foreground,
                fontWeight: resolved.fontWeight,
                decoration:
                    resolved.underline != null ? TextDecoration.underline : null,
                decorationColor: resolved.underline,
                decorationThickness: resolved.underline != null ? 2 : null,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
