import 'package:flutter/material.dart';

import '../models/grammar_category.dart';
import '../models/grammar_highlight_settings.dart';
import '../models/grammar_palette.dart';
import 'package:in4up/core/language/tr_extension.dart';

class GrammarLegendBar extends StatelessWidget {
  final GrammarHighlightSettings settings;
  final GrammarPalette palette;
  final ValueChanged<GrammarCategory>? onToggleCategory;
  final bool toolbarStyle;
  final bool compact;
  final bool horizontalScroll;
  final bool showHandle;

  const GrammarLegendBar({
    super.key,
    required this.settings,
    required this.palette,
    this.onToggleCategory,
    this.toolbarStyle = false,
    this.compact = false,
    this.horizontalScroll = false,
    this.showHandle = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!settings.showLegend) return const SizedBox.shrink();

    final categories = settings.visibleCategories.toList()
      ..sort((a, b) => a.referenceStyleIndex.compareTo(b.referenceStyleIndex));

    final emptyText = TrText('Chưa có nhóm từ loại nào đang bật.', style: TextStyle(
        color: Colors.grey[400],
        fontSize: compact ? 11 : 11.5,
        height: 1.4,
      ),
    );

    final chipWidgets = categories.map(_buildChip).toList();
    final content = categories.isEmpty
        ? emptyText
        : horizontalScroll
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: chipWidgets),
              )
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: chipWidgets,
              );

    return Container(
      padding: EdgeInsets.fromLTRB(
        compact ? 10 : 12,
        showHandle ? 8 : (compact ? 8 : 10),
        compact ? 10 : 12,
        compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: toolbarStyle
            ? const Color(0xFF111827).withValues(alpha: 0.92)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(toolbarStyle ? 16 : 12),
        border: Border.all(
          color: toolbarStyle
              ? Colors.white.withValues(alpha: 0.09)
              : Colors.white.withValues(alpha: 0.06),
        ),
        boxShadow: toolbarStyle
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHandle) ...[
            Center(
              child: Container(
                width: compact ? 26 : 32,
                height: 4,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ],
          content,
        ],
      ),
    );
  }

  Widget _buildChip(GrammarCategory category) {
    final style = palette.styleFor(category);
    final showLabel = !compact;
    final child = Container(
      margin: EdgeInsets.only(right: horizontalScroll ? 8 : 0),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 10,
        vertical: compact ? 5 : 6,
      ),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: toolbarStyle ? 0.18 : 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: style.color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 7 : 8,
            height: compact ? 7 : 8,
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
              fontSize: compact ? 10.5 : 11,
            ),
          ),
          if (showLabel) ...[
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
        ],
      ),
    );

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onToggleCategory == null ? null : () => onToggleCategory!(category),
      child: child,
    );
  }
}