import 'package:flutter/material.dart';

import '../models/grammar_category.dart';
import '../models/grammar_highlight_preset.dart';
import '../models/grammar_highlight_settings.dart';
import '../models/grammar_highlight_style.dart';
import '../models/grammar_palette.dart';
import 'grammar_legend_bar.dart';
import 'grammar_style_preview.dart';

class GrammarQuickSettingsSheet extends StatelessWidget {
  final String title;
  final GrammarHighlightSettings settings;
  final GrammarPalette palette;
  final GrammarHighlightPreset activePreset;
  final ValueChanged<bool> onToggleEnabled;
  final ValueChanged<String> onSelectPreset;
  final ValueChanged<String> onSelectPalette;
  final ValueChanged<GrammarHighlightStyle> onSelectStyle;
  final ValueChanged<GrammarCategory> onToggleCategory;
  final ValueChanged<bool> onToggleLegend;
  final VoidCallback onShowAllCategories;

  const GrammarQuickSettingsSheet({
    super.key,
    required this.title,
    required this.settings,
    required this.palette,
    required this.activePreset,
    required this.onToggleEnabled,
    required this.onSelectPreset,
    required this.onSelectPalette,
    required this.onSelectStyle,
    required this.onToggleCategory,
    required this.onToggleLegend,
    required this.onShowAllCategories,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    required GrammarHighlightSettings settings,
    required GrammarPalette palette,
    required GrammarHighlightPreset activePreset,
    required ValueChanged<bool> onToggleEnabled,
    required ValueChanged<String> onSelectPreset,
    required ValueChanged<String> onSelectPalette,
    required ValueChanged<GrammarHighlightStyle> onSelectStyle,
    required ValueChanged<GrammarCategory> onToggleCategory,
    required ValueChanged<bool> onToggleLegend,
    required VoidCallback onShowAllCategories,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.88,
        child: GrammarQuickSettingsSheet(
          title: title,
          settings: settings,
          palette: palette,
          activePreset: activePreset,
          onToggleEnabled: onToggleEnabled,
          onSelectPreset: onSelectPreset,
          onSelectPalette: onSelectPalette,
          onSelectStyle: onSelectStyle,
          onToggleCategory: onToggleCategory,
          onToggleLegend: onToggleLegend,
          onShowAllCategories: onShowAllCategories,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final presets = GrammarHighlightPresets.defaults();
    final palettes = GrammarPalettes.defaults();
    final hiddenCategories = GrammarCategory.values
        .where((category) => !settings.visibleCategories.contains(category))
        .toList()
      ..sort((a, b) => a.referenceStyleIndex.compareTo(b.referenceStyleIndex));

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Switch(
                value: settings.enabled,
                activeColor: const Color(0xFF6C63FF),
                onChanged: onToggleEnabled,
              ),
            ],
          ),
          Text(
            'Tinh chỉnh highlight từ loại: preset, palette, style và filter theo nhóm từ loại.',
            style: TextStyle(color: Colors.grey[400], height: 1.4),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView(
              children: [
                _sectionLabel('Preview'),
                GrammarStylePreview(settings: settings, palette: palette),
                const SizedBox(height: 12),
                _sectionLabel('Legend'),
                GrammarLegendBar(
                  settings: settings,
                  palette: palette,
                  onToggleCategory: onToggleCategory,
                ),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Hiện legend',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  value: settings.showLegend,
                  activeThumbColor: const Color(0xFF6C63FF),
                  onChanged: onToggleLegend,
                ),
                if (hiddenCategories.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Đang ẩn ${hiddenCategories.length} nhóm từ loại. Chúng chưa bị mất — bạn có thể bật lại từng nhóm phía dưới hoặc dùng nút khôi phục nhanh.',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 11.5,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: onShowAllCategories,
                              icon: const Icon(Icons.restart_alt_rounded, size: 16),
                              label: const Text('Bật lại tất cả'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFB8B5FF),
                                side: BorderSide(
                                  color: const Color(0xFF6C63FF)
                                      .withValues(alpha: 0.35),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              ),
                            ),
                            for (final category in hiddenCategories.take(5))
                              ActionChip(
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.04),
                                side: BorderSide(
                                  color: palette
                                      .styleFor(category)
                                      .color
                                      .withValues(alpha: 0.28),
                                ),
                                label: Text(
                                  '+ ${category.labelVi}',
                                  style: TextStyle(
                                    color: palette.styleFor(category).color,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                onPressed: () => onToggleCategory(category),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _sectionLabel('Preset học tập'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: presets
                      .map(
                        (preset) => _ChoiceChipButton(
                          label: preset.name,
                          subtitle: preset.description,
                          selected: activePreset.id == preset.id,
                          onTap: () => onSelectPreset(preset.id),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 14),
                _sectionLabel('Palette màu'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: palettes
                      .map(
                        (item) => _ChoiceChipButton(
                          label: item.name,
                          selected: palette.id == item.id,
                          compact: true,
                          onTap: () => onSelectPalette(item.id),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 14),
                _sectionLabel('Kiểu tô màu'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: GrammarHighlightStyle.values
                      .map(
                        (style) => _ChoiceChipButton(
                          label: style.labelVi,
                          selected: settings.highlightStyle == style,
                          compact: true,
                          onTap: () => onSelectStyle(style),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 14),
                _sectionLabel('Bật/tắt từng nhóm từ loại'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: GrammarCategory.values.map((category) {
                    final selected = settings.visibleCategories.contains(category);
                    final style = palette.styleFor(category);
                    return FilterChip(
                      selected: selected,
                      selectedColor: style.color.withValues(alpha: 0.18),
                      backgroundColor: Colors.white.withValues(alpha: 0.04),
                      side: BorderSide(
                        color: selected
                            ? style.color.withValues(alpha: 0.45)
                            : Colors.white.withValues(alpha: 0.08),
                      ),
                      label: Text(
                        category.labelVi,
                        style: TextStyle(
                          color: selected ? style.color : Colors.white70,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onSelected: (_) => onToggleCategory(category),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _ChoiceChipButton extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  const _ChoiceChipButton({
    required this.label,
    this.subtitle,
    required this.selected,
    this.compact = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 10,
          vertical: compact ? 9 : 10,
        ),
        constraints: BoxConstraints(minWidth: compact ? 0 : 120),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF6C63FF).withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? const Color(0xFF6C63FF).withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? const Color(0xFFB8B5FF) : Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            if (!compact && subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 10.5,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
