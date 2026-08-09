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
  final VoidCallback onRestorePreviousPreset;
  final ValueChanged<bool> onToggleAdvancedMode;
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
    required this.onRestorePreviousPreset,
    required this.onToggleAdvancedMode,
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
    required VoidCallback onRestorePreviousPreset,
    required ValueChanged<bool> onToggleAdvancedMode,
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
        heightFactor: 0.9,
        child: GrammarQuickSettingsSheet(
          title: title,
          settings: settings,
          palette: palette,
          activePreset: activePreset,
          onToggleEnabled: onToggleEnabled,
          onSelectPreset: onSelectPreset,
          onRestorePreviousPreset: onRestorePreviousPreset,
          onToggleAdvancedMode: onToggleAdvancedMode,
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
    final previousPreset =
        GrammarHighlightPresets.byId(settings.lastNonCustomPresetId);
    final hiddenCategories = GrammarCategory.values
        .where((category) => !settings.visibleCategories.contains(category))
        .toList()
      ..sort((a, b) => a.referenceStyleIndex.compareTo(b.referenceStyleIndex));
    final visibleCount = settings.visibleCategories.length;
    final groupOrder = const [
      GrammarCategoryGroup.contentWord,
      GrammarCategoryGroup.functionWord,
      GrammarCategoryGroup.symbols,
      GrammarCategoryGroup.structural,
    ];

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
            'Bản điều khiển grammar highlight dùng chung cho Read, Web và PDF. Bạn có thể dùng chế độ mini để thao tác nhanh hoặc mở advanced để canh sâu hơn.',
            style: TextStyle(color: Colors.grey[400], height: 1.4),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView(
              children: [
                _SummaryControlCard(
                  settings: settings,
                  activePreset: activePreset,
                  previousPreset: previousPreset,
                  visibleCount: visibleCount,
                  hiddenCount: hiddenCategories.length,
                  onRestorePreviousPreset: onRestorePreviousPreset,
                  onToggleAdvancedMode: onToggleAdvancedMode,
                ),
                const SizedBox(height: 14),
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
                _sectionLabel(
                  settings.showAdvancedControls
                      ? 'Preview & cảm nhận'
                      : 'Preview nhanh',
                ),
                const SizedBox(height: 8),
                GrammarStylePreview(settings: settings, palette: palette),
                const SizedBox(height: 14),
                _sectionLabel('Legend điều khiển'),
                const SizedBox(height: 8),
                GrammarLegendBar(
                  settings: settings,
                  palette: palette,
                  onToggleCategory: onToggleCategory,
                ),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Hiện legend trên vùng đọc',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  subtitle: Text(
                    settings.showLegend
                        ? 'Đang bật thanh legend để đổi nhanh category ngay trên màn đọc.'
                        : 'Tắt để mặt đọc sạch hơn; bạn vẫn điều chỉnh được trong bảng này.',
                    style: TextStyle(color: Colors.grey[500], fontSize: 11.5),
                  ),
                  value: settings.showLegend,
                  activeThumbColor: const Color(0xFF6C63FF),
                  onChanged: onToggleLegend,
                ),
                if (hiddenCategories.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _HiddenCategoriesCard(
                    hiddenCategories: hiddenCategories,
                    palette: palette,
                    onShowAllCategories: onShowAllCategories,
                    onToggleCategory: onToggleCategory,
                    previousPresetName: previousPreset.name,
                  ),
                ],
                if (!settings.showAdvancedControls) ...[
                  const SizedBox(height: 14),
                  _HintCard(
                    title: 'Mini mode đang bật',
                    message:
                        'Bạn đang thấy các nút cốt lõi trước: preset, legend và phục hồi nhanh. Bật advanced nếu muốn chia nhóm content/function words, đổi palette và style chi tiết hơn.',
                  ),
                ] else ...[
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
                  _sectionLabel('Nhóm từ loại'),
                  const SizedBox(height: 8),
                  ...groupOrder.map((group) {
                    final categories = grammarCategoriesForGroup(group);
                    if (categories.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _GrammarGroupCard(
                        group: group,
                        categories: categories,
                        settings: settings,
                        palette: palette,
                        onToggleCategory: onToggleCategory,
                      ),
                    );
                  }),
                ],
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

class _SummaryControlCard extends StatelessWidget {
  final GrammarHighlightSettings settings;
  final GrammarHighlightPreset activePreset;
  final GrammarHighlightPreset previousPreset;
  final int visibleCount;
  final int hiddenCount;
  final VoidCallback onRestorePreviousPreset;
  final ValueChanged<bool> onToggleAdvancedMode;

  const _SummaryControlCard({
    required this.settings,
    required this.activePreset,
    required this.previousPreset,
    required this.visibleCount,
    required this.hiddenCount,
    required this.onRestorePreviousPreset,
    required this.onToggleAdvancedMode,
  });

  @override
  Widget build(BuildContext context) {
    final presetName = activePreset.name;
    final subtitle = settings.isCustomPreset
        ? 'Đang chỉnh tay từ preset gần nhất: ${previousPreset.name}'
        : activePreset.description;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  size: 18,
                  color: Color(0xFFB8B5FF),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      settings.isCustomPreset
                          ? 'Preset hiện tại: Tùy chỉnh'
                          : 'Preset hiện tại: $presetName',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoPill(
                icon: Icons.visibility_outlined,
                label: '$visibleCount nhóm đang bật',
              ),
              _InfoPill(
                icon: Icons.visibility_off_outlined,
                label: '$hiddenCount nhóm đang ẩn',
              ),
              _InfoPill(
                icon: settings.showLegend
                    ? Icons.view_agenda_outlined
                    : Icons.view_day_outlined,
                label: settings.showLegend ? 'Legend đang hiện' : 'Legend đang tắt',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Mini'),
                selected: !settings.showAdvancedControls,
                onSelected: (_) => onToggleAdvancedMode(false),
                selectedColor:
                    const Color(0xFF6C63FF).withValues(alpha: 0.22),
                backgroundColor: Colors.white.withValues(alpha: 0.04),
                labelStyle: TextStyle(
                  color: !settings.showAdvancedControls
                      ? const Color(0xFFB8B5FF)
                      : Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
                side: BorderSide(
                  color: !settings.showAdvancedControls
                      ? const Color(0xFF6C63FF).withValues(alpha: 0.45)
                      : Colors.white.withValues(alpha: 0.08),
                ),
              ),
              ChoiceChip(
                label: const Text('Advanced'),
                selected: settings.showAdvancedControls,
                onSelected: (_) => onToggleAdvancedMode(true),
                selectedColor:
                    const Color(0xFF6C63FF).withValues(alpha: 0.22),
                backgroundColor: Colors.white.withValues(alpha: 0.04),
                labelStyle: TextStyle(
                  color: settings.showAdvancedControls
                      ? const Color(0xFFB8B5FF)
                      : Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
                side: BorderSide(
                  color: settings.showAdvancedControls
                      ? const Color(0xFF6C63FF).withValues(alpha: 0.45)
                      : Colors.white.withValues(alpha: 0.08),
                ),
              ),
              if (settings.isCustomPreset)
                OutlinedButton.icon(
                  onPressed: onRestorePreviousPreset,
                  icon: const Icon(Icons.undo_rounded, size: 16),
                  label: Text('Khôi phục ${previousPreset.name}'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB8B5FF),
                    side: BorderSide(
                      color: const Color(0xFF6C63FF).withValues(alpha: 0.35),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HiddenCategoriesCard extends StatelessWidget {
  final List<GrammarCategory> hiddenCategories;
  final GrammarPalette palette;
  final VoidCallback onShowAllCategories;
  final ValueChanged<GrammarCategory> onToggleCategory;
  final String previousPresetName;

  const _HiddenCategoriesCard({
    required this.hiddenCategories,
    required this.palette,
    required this.onShowAllCategories,
    required this.onToggleCategory,
    required this.previousPresetName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Đang ẩn ${hiddenCategories.length} nhóm từ loại. Chúng chưa bị mất — bạn có thể bật lại từng nhóm, bật lại tất cả, hoặc quay về preset gần nhất $previousPresetName.',
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
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.35),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
              for (final category in hiddenCategories.take(6))
                ActionChip(
                  backgroundColor: Colors.white.withValues(alpha: 0.04),
                  side: BorderSide(
                    color: palette.styleFor(category).color.withValues(alpha: 0.28),
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
    );
  }
}

class _GrammarGroupCard extends StatelessWidget {
  final GrammarCategoryGroup group;
  final List<GrammarCategory> categories;
  final GrammarHighlightSettings settings;
  final GrammarPalette palette;
  final ValueChanged<GrammarCategory> onToggleCategory;

  const _GrammarGroupCard({
    required this.group,
    required this.categories,
    required this.settings,
    required this.palette,
    required this.onToggleCategory,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(group.icon, size: 16, color: const Color(0xFFB8B5FF)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  group.labelVi,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            group.helperVi,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 11.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: categories.map((category) {
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
                avatar: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: selected ? style.color : Colors.grey,
                    shape: BoxShape.circle,
                  ),
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
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  final String title;
  final String message;

  const _HintCard({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF6C63FF).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF6C63FF).withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFD4D2FF),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: const TextStyle(
              color: Color(0xFFB8B5FF),
              height: 1.45,
              fontSize: 12,
            ),
          ),
        ],
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
