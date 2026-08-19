import 'grammar_category.dart';
import 'grammar_highlight_preset.dart';
import 'grammar_highlight_style.dart';

class GrammarHighlightSettings {
  final bool enabled;
  final String activePresetId;
  final String lastNonCustomPresetId;
  final String paletteId;
  final GrammarHighlightStyle highlightStyle;
  final Set<GrammarCategory> visibleCategories;
  final bool showLegend;
  final bool legendCollapsed;
  final bool emphasizeContentWords;
  final bool dimHiddenCategories;
  final bool showAdvancedControls;

  const GrammarHighlightSettings({
    required this.enabled,
    required this.activePresetId,
    required this.lastNonCustomPresetId,
    required this.paletteId,
    required this.highlightStyle,
    required this.visibleCategories,
    required this.showLegend,
    required this.legendCollapsed,
    required this.emphasizeContentWords,
    required this.dimHiddenCategories,
    required this.showAdvancedControls,
  });

  factory GrammarHighlightSettings.defaults() {
    final preset = GrammarHighlightPresets.byId('content-words');
    return GrammarHighlightSettings(
      enabled: true,
      activePresetId: preset.id,
      lastNonCustomPresetId: preset.id,
      paletteId: 'classic-dark',
      highlightStyle: GrammarHighlightStyle.mixed,
      visibleCategories: Set<GrammarCategory>.from(preset.visibleCategories),
      showLegend: preset.showLegend,
      legendCollapsed: false,
      emphasizeContentWords: preset.emphasizeContentWords,
      dimHiddenCategories: true,
      showAdvancedControls: false,
    );
  }

  GrammarHighlightSettings copyWith({
    bool? enabled,
    String? activePresetId,
    String? lastNonCustomPresetId,
    String? paletteId,
    GrammarHighlightStyle? highlightStyle,
    Set<GrammarCategory>? visibleCategories,
    bool? showLegend,
    bool? legendCollapsed,
    bool? emphasizeContentWords,
    bool? dimHiddenCategories,
    bool? showAdvancedControls,
  }) {
    return GrammarHighlightSettings(
      enabled: enabled ?? this.enabled,
      activePresetId: activePresetId ?? this.activePresetId,
      lastNonCustomPresetId:
          lastNonCustomPresetId ?? this.lastNonCustomPresetId,
      paletteId: paletteId ?? this.paletteId,
      highlightStyle: highlightStyle ?? this.highlightStyle,
      visibleCategories: visibleCategories ?? this.visibleCategories,
      showLegend: showLegend ?? this.showLegend,
      legendCollapsed: legendCollapsed ?? this.legendCollapsed,
      emphasizeContentWords:
          emphasizeContentWords ?? this.emphasizeContentWords,
      dimHiddenCategories: dimHiddenCategories ?? this.dimHiddenCategories,
      showAdvancedControls: showAdvancedControls ?? this.showAdvancedControls,
    );
  }

  GrammarHighlightSettings applyPreset(GrammarHighlightPreset preset) {
    return copyWith(
      activePresetId: preset.id,
      lastNonCustomPresetId: preset.id,
      visibleCategories: Set<GrammarCategory>.from(preset.visibleCategories),
      showLegend: preset.showLegend,
      emphasizeContentWords: preset.emphasizeContentWords,
    );
  }

  GrammarHighlightSettings restorePreviousPreset() {
    return applyPreset(GrammarHighlightPresets.byId(lastNonCustomPresetId));
  }

  bool get isCustomPreset => activePresetId == 'custom';
  bool get hasHiddenCategories => visibleCategories.length < GrammarCategory.values.length;

  bool isVisible(GrammarCategory category) => visibleCategories.contains(category);

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'activePresetId': activePresetId,
        'lastNonCustomPresetId': lastNonCustomPresetId,
        'paletteId': paletteId,
        'highlightStyle': highlightStyle.name,
        'visibleCategories': visibleCategories.map((value) => value.name).toList(),
        'showLegend': showLegend,
        'legendCollapsed': legendCollapsed,
        'emphasizeContentWords': emphasizeContentWords,
        'dimHiddenCategories': dimHiddenCategories,
        'showAdvancedControls': showAdvancedControls,
      };

  factory GrammarHighlightSettings.fromJson(Map<String, dynamic> json) {
    final defaults = GrammarHighlightSettings.defaults();
    final rawVisible = json['visibleCategories'];
    final parsedVisible = (rawVisible is List
            ? rawVisible
            : const <dynamic>[])
        .map((item) => GrammarCategory.values.firstWhere(
              (value) => value.name == item,
              orElse: () => GrammarCategory.unknown,
            ))
        .toSet();
    final resolvedActivePresetId =
        (json['activePresetId'] ?? defaults.activePresetId).toString();
    final resolvedLastPresetId =
        (json['lastNonCustomPresetId'] ?? '').toString().trim();
    return GrammarHighlightSettings(
      enabled:
          json['enabled'] is bool ? json['enabled'] as bool : defaults.enabled,
      activePresetId: resolvedActivePresetId,
      lastNonCustomPresetId: resolvedLastPresetId.isNotEmpty
          ? resolvedLastPresetId
          : resolvedActivePresetId == 'custom'
              ? defaults.lastNonCustomPresetId
              : resolvedActivePresetId,
      paletteId: (json['paletteId'] ?? defaults.paletteId).toString(),
      highlightStyle: GrammarHighlightStyle.values.firstWhere(
        (style) => style.name == json['highlightStyle'],
        orElse: () => defaults.highlightStyle,
      ),
      visibleCategories: rawVisible == null
          ? defaults.visibleCategories
          : parsedVisible,
      showLegend: json['showLegend'] is bool
          ? json['showLegend'] as bool
          : defaults.showLegend,
      legendCollapsed: json['legendCollapsed'] is bool
          ? json['legendCollapsed'] as bool
          : defaults.legendCollapsed,
      emphasizeContentWords: json['emphasizeContentWords'] is bool
          ? json['emphasizeContentWords'] as bool
          : defaults.emphasizeContentWords,
      dimHiddenCategories: json['dimHiddenCategories'] is bool
          ? json['dimHiddenCategories'] as bool
          : defaults.dimHiddenCategories,
      showAdvancedControls: json['showAdvancedControls'] is bool
          ? json['showAdvancedControls'] as bool
          : defaults.showAdvancedControls,
    );
  }
}
