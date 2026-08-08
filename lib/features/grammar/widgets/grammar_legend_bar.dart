import 'package:flutter/material.dart';

import '../models/grammar_category.dart';
import '../models/grammar_highlight_settings.dart';
import '../models/grammar_palette.dart';

class GrammarLegendBar extends StatelessWidget {
  final GrammarHighlightSettings settings;
  final GrammarPalette palette;
  final ValueChanged<GrammarCategory>? onToggleCategory;

  const GrammarLegendBar({
    super.key,
    required this.settings,
    required this.palette,
    this.onToggleCategory,
  });

  @override
  Widget build(BuildContext context) {
    if (!settings.showLegend) return const SizedBox.shrink();

    final categories = settings.visibleCategories.toList()
      ..sort((a, b) => a.referenceStyleIndex.compareTo(b.referenceStyleIndex));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: categories.isEmpty
          ? Text(
              'Chưa có nhóm từ loại nào đang bật.',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 11.5,
                height: 1.4,
              ),
            )
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories.map((category) {
                final style = palette.styleFor(category);
                return InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: onToggleCategory == null
                      ? null
                      : () => onToggleCategory!(category),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: style.color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                      border:
                          Border.all(color: style.color.withValues(alpha: 0.28)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: style.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          category.shortCode,
                          style: TextStyle(
                            color: style.color,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          category.labelVi,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }
}
