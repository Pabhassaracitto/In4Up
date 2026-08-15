import 'package:flutter/material.dart';

import '../models/grammar_category.dart';
import '../models/grammar_highlight_preset.dart';
import '../models/grammar_highlight_settings.dart';
import '../models/grammar_highlight_style.dart';
import '../models/grammar_palette.dart';
import 'grammar_legend_bar.dart';
import 'grammar_style_preview.dart';
import 'package:in4up/core/language/tr_extension.dart';

class GrammarQuickSettingsSheet extends StatefulWidget {
  final String title;
  final GrammarHighlightSettings settings;
  final GrammarPalette palette;
  final GrammarHighlightPreset activePreset;
  final List<GrammarHighlightPreset> presets;
  final Future<void> Function(bool value) onToggleEnabled;
  final Future<void> Function(String id) onSelectPreset;
  final Future<GrammarHighlightPreset> Function(String name, String description)
      onSaveCurrentAsPreset;
  final Future<void> Function() onRestorePreviousPreset;
  final Future<void> Function(bool value) onToggleAdvancedMode;
  final Future<void> Function(String id) onSelectPalette;
  final Future<void> Function(GrammarHighlightStyle style) onSelectStyle;
  final Future<void> Function(GrammarCategory category) onToggleCategory;
  final Future<void> Function(bool visible) onToggleLegend;
  final Future<void> Function() onShowAllCategories;

  const GrammarQuickSettingsSheet({
    super.key,
    required this.title,
    required this.settings,
    required this.palette,
    required this.activePreset,
    required this.presets,
    required this.onToggleEnabled,
    required this.onSelectPreset,
    required this.onSaveCurrentAsPreset,
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
    required List<GrammarHighlightPreset> presets,
    required Future<void> Function(bool value) onToggleEnabled,
    required Future<void> Function(String id) onSelectPreset,
    required Future<GrammarHighlightPreset> Function(String name, String description)
        onSaveCurrentAsPreset,
    required Future<void> Function() onRestorePreviousPreset,
    required Future<void> Function(bool value) onToggleAdvancedMode,
    required Future<void> Function(String id) onSelectPalette,
    required Future<void> Function(GrammarHighlightStyle style) onSelectStyle,
    required Future<void> Function(GrammarCategory category) onToggleCategory,
    required Future<void> Function(bool visible) onToggleLegend,
    required Future<void> Function() onShowAllCategories,
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
          presets: presets,
          onToggleEnabled: onToggleEnabled,
          onSelectPreset: onSelectPreset,
          onSaveCurrentAsPreset: onSaveCurrentAsPreset,
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
  State<GrammarQuickSettingsSheet> createState() =>
      _GrammarQuickSettingsSheetState();
}

class _GrammarQuickSettingsSheetState extends State<GrammarQuickSettingsSheet> {
  late GrammarHighlightSettings _settings;
  late List<GrammarHighlightPreset> _presets;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
    _presets = List<GrammarHighlightPreset>.from(widget.presets);
  }

  GrammarPalette get _palette => GrammarPalettes.byId(_settings.paletteId);

  GrammarHighlightPreset get _activePreset =>
      _findPreset(_settings.activePresetId);

  GrammarHighlightPreset get _previousPreset =>
      _findPreset(_settings.lastNonCustomPresetId);

  GrammarHighlightPreset _findPreset(String? presetId) {
    for (final preset in _presets) {
      if (preset.id == presetId) return preset;
    }
    return GrammarHighlightPresets.byId(presetId);
  }

  List<GrammarHighlightPreset> get _builtInPresets =>
      _presets.where((preset) => preset.isBuiltIn).toList();

  List<GrammarHighlightPreset> get _customPresets =>
      _presets.where((preset) => !preset.isBuiltIn).toList();

  List<GrammarCategory> get _hiddenCategories {
    final hidden = GrammarCategory.values
        .where((category) => !_settings.visibleCategories.contains(category))
        .toList();
    hidden.sort((a, b) => a.referenceStyleIndex.compareTo(b.referenceStyleIndex));
    return hidden;
  }

  Future<void> _handleToggleEnabled(bool value) async {
    await widget.onToggleEnabled(value);
    if (!mounted) return;
    setState(() => _settings = _settings.copyWith(enabled: value));
  }

  Future<void> _handleSelectPreset(String presetId) async {
    final preset = _findPreset(presetId);
    await widget.onSelectPreset(presetId);
    if (!mounted) return;
    setState(() => _settings = _settings.applyPreset(preset));
  }

  Future<void> _handleRestorePreviousPreset() async {
    final preset = _previousPreset;
    await widget.onRestorePreviousPreset();
    if (!mounted) return;
    setState(() => _settings = _settings.applyPreset(preset));
  }

  Future<void> _handleSaveCurrentPreset() async {
    final draft = await _showSavePresetDialog(context, _activePreset.name);
    if (draft == null) return;
    final saved = await widget.onSaveCurrentAsPreset(draft.name, draft.description);
    if (!mounted) return;
    final next = List<GrammarHighlightPreset>.from(_presets);
    final index = next.indexWhere((preset) => preset.id == saved.id);
    if (index >= 0) {
      next[index] = saved;
    } else {
      next.add(saved);
    }
    setState(() {
      _presets = next;
      _settings = _settings.applyPreset(saved);
    });
  }

  Future<void> _handleToggleAdvancedMode(bool value) async {
    await widget.onToggleAdvancedMode(value);
    if (!mounted) return;
    setState(() => _settings = _settings.copyWith(showAdvancedControls: value));
  }

  Future<void> _handleSelectPalette(String paletteId) async {
    await widget.onSelectPalette(paletteId);
    if (!mounted) return;
    setState(() => _settings = _settings.copyWith(paletteId: paletteId));
  }

  Future<void> _handleSelectStyle(GrammarHighlightStyle style) async {
    await widget.onSelectStyle(style);
    if (!mounted) return;
    setState(() => _settings = _settings.copyWith(highlightStyle: style));
  }

  Future<void> _handleToggleCategory(GrammarCategory category) async {
    await widget.onToggleCategory(category);
    if (!mounted) return;
    final next = Set<GrammarCategory>.from(_settings.visibleCategories);
    if (next.contains(category)) {
      next.remove(category);
    } else {
      next.add(category);
    }
    setState(() {
      _settings = _settings.copyWith(
        activePresetId: 'custom',
        visibleCategories: next,
      );
    });
  }

  Future<void> _handleToggleLegend(bool visible) async {
    await widget.onToggleLegend(visible);
    if (!mounted) return;
    setState(() => _settings = _settings.copyWith(showLegend: visible));
  }

  Future<void> _handleShowAllCategories() async {
    await widget.onShowAllCategories();
    if (!mounted) return;
    setState(() {
      _settings = _settings.copyWith(
        activePresetId: 'custom',
        visibleCategories: Set<GrammarCategory>.from(GrammarCategory.values),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final groupOrder = const [
      GrammarCategoryGroup.contentWord,
      GrammarCategoryGroup.functionWord,
      GrammarCategoryGroup.symbols,
      GrammarCategoryGroup.structural,
    ];
    final hiddenCategories = _hiddenCategories;

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
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Switch(
                value: _settings.enabled,
                activeColor: const Color(0xFF6C63FF),
                onChanged: _handleToggleEnabled,
              ),
            ],
          ),
          TrText('Bản điều khiển grammar highlight dùng chung cho Read, Web và PDF. Chế độ mini ưu tiên thao tác nhanh; advanced mở sâu cho preset riêng và palette.', style: TextStyle(color: Colors.grey[400], height: 1.4),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView(
              children: [
                _SummaryControlCard(
                  settings: _settings,
                  activePreset: _activePreset,
                  previousPreset: _previousPreset,
                  visibleCount: _settings.visibleCategories.length,
                  hiddenCount: hiddenCategories.length,
                  onRestorePreviousPreset: _handleRestorePreviousPreset,
                  onToggleAdvancedMode: _handleToggleAdvancedMode,
                  onSaveCurrentPreset: _handleSaveCurrentPreset,
                ),
                const SizedBox(height: 14),
                _sectionLabel('Content'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _builtInPresets
                      .map(
                        (preset) => _PresetCard(
                          preset: preset,
                          selected: _activePreset.id == preset.id,
                          onTap: () => _handleSelectPreset(preset.id),
                        ),
                      )
                      .toList(),
                ),
                if (_customPresets.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _sectionLabel('Content'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _customPresets
                        .map(
                          (preset) => _PresetCard(
                            preset: preset,
                            selected: _activePreset.id == preset.id,
                            onTap: () => _handleSelectPreset(preset.id),
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 16),
                _sectionLabel(
                  _settings.showAdvancedControls
                      ? 'Content'
                      : 'Preview nhanh',
                ),
                const SizedBox(height: 8),
                GrammarStylePreview(settings: _settings, palette: _palette),
                const SizedBox(height: 14),
                _sectionLabel('Content'),
                const SizedBox(height: 8),
                GrammarLegendBar(
                  settings: _settings,
                  palette: _palette,
                  onToggleCategory: _handleToggleCategory,
                ),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const TrText('Hiện legend trên vùng đọc', style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  subtitle: Text(
                    _settings.showLegend
                        ? 'Content'
                        : 'Content',
                    style: TextStyle(color: Colors.grey[500], fontSize: 11.5),
                  ),
                  value: _settings.showLegend,
                  activeThumbColor: const Color(0xFF6C63FF),
                  onChanged: _handleToggleLegend,
                ),
                if (hiddenCategories.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _HiddenCategoriesCard(
                    hiddenCategories: hiddenCategories,
                    palette: _palette,
                    previousPresetName: _previousPreset.name,
                    onShowAllCategories: _handleShowAllCategories,
                    onToggleCategory: _handleToggleCategory,
                  ),
                ],
                if (!_settings.showAdvancedControls) ...[
                  const SizedBox(height: 14),
                  const _HintCard(
                    title: context.tr('Mini mode đang bật'),
                    message:
                        'Save',
                  ),
                ] else ...[
                  const SizedBox(height: 14),
                  _sectionLabel('Content'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: GrammarPalettes.defaults()
                        .map(
                          (item) => _PalettePreviewCard(
                            palette: item,
                            selected: _palette.id == item.id,
                            onTap: () => _handleSelectPalette(item.id),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 14),
                  _sectionLabel('Content'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: GrammarHighlightStyle.values
                        .map(
                          (style) => _ChoiceChipButton(
                            label: style.labelVi,
                            selected: _settings.highlightStyle == style,
                            compact: true,
                            onTap: () => _handleSelectStyle(style),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 14),
                  _sectionLabel('Content'),
                  const SizedBox(height: 8),
                  ...groupOrder.map((group) {
                    final categories = grammarCategoriesForGroup(group);
                    if (categories.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _GrammarGroupCard(
                        group: group,
                        categories: categories,
                        settings: _settings,
                        palette: _palette,
                        onToggleCategory: _handleToggleCategory,
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
  final Future<void> Function() onRestorePreviousPreset;
  final Future<void> Function(bool value) onToggleAdvancedMode;
  final Future<void> Function() onSaveCurrentPreset;

  const _SummaryControlCard({
    required this.settings,
    required this.activePreset,
    required this.previousPreset,
    required this.visibleCount,
    required this.hiddenCount,
    required this.onRestorePreviousPreset,
    required this.onToggleAdvancedMode,
    required this.onSaveCurrentPreset,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = settings.isCustomPreset
        ? 'Content'
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
                          ? 'Content'
                          : 'Content',
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
                label: 'Content',
              ),
              _InfoPill(
                icon: Icons.visibility_off_outlined,
                label: 'Content',
              ),
              _InfoPill(
                icon:
                    settings.showLegend ? Icons.drag_handle : Icons.view_day_rounded,
                label: settings.showLegend ? 'Content' : 'Content',
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
              OutlinedButton.icon(
                onPressed: onSaveCurrentPreset,
                icon: const Icon(Icons.bookmark_add_outlined, size: 16),
                label: const TrText(context.l10n.grammarSavePreset),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFB8B5FF),
                  side: BorderSide(
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.35),
                  ),
                ),
              ),
              if (settings.isCustomPreset)
                OutlinedButton.icon(
                  onPressed: onRestorePreviousPreset,
                  icon: const Icon(Icons.undo_rounded, size: 16),
                  label: Text('Content'),
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

class _PresetCard extends StatelessWidget {
  final GrammarHighlightPreset preset;
  final bool selected;
  final VoidCallback onTap;

  const _PresetCard({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 168,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF6C63FF).withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? const Color(0xFF6C63FF).withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    preset.audienceLabel,
                    style: TextStyle(
                      color: selected ? const Color(0xFFD4D2FF) : Colors.white70,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(
                  preset.isBuiltIn ? Icons.auto_awesome : Icons.person_outline,
                  size: 15,
                  color: selected ? const Color(0xFFD4D2FF) : Colors.grey,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              preset.name,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              preset.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              preset.focusSummary,
              style: TextStyle(
                color: selected ? const Color(0xFFB8B5FF) : Colors.grey[500],
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PalettePreviewCard extends StatelessWidget {
  final GrammarPalette palette;
  final bool selected;
  final VoidCallback onTap;

  const _PalettePreviewCard({
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sampleCategories = [
      GrammarCategory.verb,
      GrammarCategory.adjective,
      GrammarCategory.noun,
      GrammarCategory.preposition,
      GrammarCategory.pronoun,
    ];

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 170,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF6C63FF).withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? const Color(0xFF6C63FF).withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    palette.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    palette.isDark ? 'Dark' : 'Light',
                    style: TextStyle(
                      color: selected ? const Color(0xFFD4D2FF) : Colors.white70,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: sampleCategories.map((category) {
                final color = palette.styleFor(category).color;
                return Expanded(
                  child: Container(
                    height: 12,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            Text(
              _paletteHint(palette.id),
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _paletteHint(String id) {
    switch (id) {
      case 'classic-dark':
        return 'Content';
      case 'classic-light':
        return 'Content';
      case 'noun-verb-focus':
        return 'Content';
      default:
        return 'Content';
    }
  }
}

class _HiddenCategoriesCard extends StatelessWidget {
  final List<GrammarCategory> hiddenCategories;
  final GrammarPalette palette;
  final String previousPresetName;
  final Future<void> Function() onShowAllCategories;
  final Future<void> Function(GrammarCategory category) onToggleCategory;

  const _HiddenCategoriesCard({
    required this.hiddenCategories,
    required this.palette,
    required this.previousPresetName,
    required this.onShowAllCategories,
    required this.onToggleCategory,
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
            'Content',
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
                label: const TrText(context.l10n.grammarEnableAll),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFB8B5FF),
                  side: BorderSide(
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.35),
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
  final Future<void> Function(GrammarCategory category) onToggleCategory;

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

class _PresetDraft {
  final String name;
  final String description;

  const _PresetDraft({required this.name, required this.description});
}

Future<_PresetDraft?> _showSavePresetDialog(
  BuildContext context,
  String suggestedName,
) async {
  final nameCtrl = TextEditingController(
    text: suggestedName == 'Content' ? 'Content' : 'Content',
  );
  final descCtrl = TextEditingController();

  final shouldSave = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: const Color(0xFF151B26),
        title: const TrTrText('Lưu preset cá nhân'),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: _dialogInputDecoration(
                  label: context.tr('Tên preset'),
                  hint: context.tr('Ví dụ: Verb focus riêng'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: _dialogInputDecoration(
                  label: context.tr('Mô tả ngắn'),
                  hint: context.tr('Ghi chú cách dùng của preset này'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const TrTrText('Huỷ'),
          ),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(dialogContext, true);
            },
            child: const TrTrText('Lưu preset'),
          ),
        ],
      );
    },
  );

  if (shouldSave != true) return null;
  return _PresetDraft(
    name: nameCtrl.text.trim(),
    description: descCtrl.text.trim(),
  );
}

InputDecoration _dialogInputDecoration({
  required String label,
  required String hint,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    labelStyle: const TextStyle(color: Colors.white70),
    hintStyle: const TextStyle(color: Colors.grey),
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.04),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF6C63FF)),
    ),
  );
}