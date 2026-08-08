import 'grammar_category.dart';
import 'grammar_highlight_preset.dart';
import 'grammar_highlight_style.dart';

class GrammarHighlightSettings {
  final bool enabled;
  final String activePresetId;
  final String paletteId;
  final GrammarHighlightStyle highlightStyle;
  final Set<GrammarCategory> visibleCategories;
  final bool showLegend;
  final bool legendCollapsed;
  final bool emphasizeContentWords;
  final bool dimHiddenCategories;

  const GrammarHighlightSettings({
    required this.enabled,
    required this.activePresetId,
    required this.paletteId,
    required this.highlightStyle,
    required this.visibleCategories,
    required this.showLegend,
    required this.legendCollapsed,
    required this.emphasizeContentWords,
    required this.dimHiddenCategories,
  });

  factory GrammarHighlightSettings.defaults() {
    final preset = GrammarHighlightPresets.byId('content-words');
    return GrammarHighlightSettings(
      enabled: true,
      activePresetId: preset.id,
      paletteId: 'classic-dark',
      highlightStyle: GrammarHighlightStyle.mixed,
      visibleCategories: Set<GrammarCategory>.from(preset.visibleCategories),
      showLegend: preset.showLegend,
      legendCollapsed: false,
      emphasizeContentWords: preset.emphasizeContentWords,
      dimHiddenCategories: true,
    );
  }

  GrammarHighlightSettings copyWith({
    bool? enabled,
    String? activePresetId,
    String? paletteId,
    GrammarHighlightStyle? highlightStyle,
    Set<GrammarCategory>? visibleCategories,
    bool? showLegend,
    bool? legendCollapsed,
    bool? emphasizeContentWords,
    bool? dimHiddenCategories,
  }) {
    return GrammarHighlightSettings(
      enabled: enabled ?? this.enabled,
      activePresetId: activePresetId ?? this.activePresetId,
      paletteId: paletteId ?? this.paletteId,
      highlightStyle: highlightStyle ?? this.highlightStyle,
      visibleCategories: visibleCategories ?? this.visibleCategories,
      showLegend: showLegend ?? this.showLegend,
      legendCollapsed: legendCollapsed ?? this.legendCollapsed,
      emphasizeContentWords: emphasizeContentWords ?? this.emphasizeContentWords,
      dimHiddenCategories: dimHiddenCategories ?? this.dimHiddenCategories,
    );
  }

  GrammarHighlightSettings applyPreset(GrammarHighlightPreset preset) {
    return copyWith(
      activePresetId: preset.id,
      visibleCategories: Set<GrammarCategory>.from(preset.visibleCategories),
      showLegend: preset.showLegend,
      emphasizeContentWords: preset.emphasizeContentWords,
    );
  }

  bool isVisible(GrammarCategory category) => visibleCategories.contains(category);

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'activePresetId': activePresetId,
        'paletteId': paletteId,
        'highlightStyle': highlightStyle.name,
        'visibleCategories': visibleCategories.map((value) => value.name).toList(),
        'showLegend': showLegend,
        'legendCollapsed': legendCollapsed,
        'emphasizeContentWords': emphasizeContentWords,
        'dimHiddenCategories': dimHiddenCategories,
      };

  factory GrammarHighlightSettings.fromJson(Map<String, dynamic> json) {
    final defaults = GrammarHighlightSettings.defaults();
    final parsedVisible = ((json['visibleCategories'] as List<dynamic>? ?? const [])
            .map((item) => GrammarCategory.values.firstWhere(
                  (value) => value.name == item,
                  orElse: () => GrammarCategory.unknown,
                )))
        .toSet();
    return GrammarHighlightSettings(
      enabled: json['enabled'] is bool ? json['enabled'] as bool : defaults.enabled,
      activePresetId: (json['activePresetId'] ?? defaults.activePresetId).toString(),
      paletteId: (json['paletteId'] ?? defaults.paletteId).toString(),
      highlightStyle: GrammarHighlightStyle.values.firstWhere(
        (style) => style.name == json['highlightStyle'],
        orElse: () => defaults.highlightStyle,
      ),
      visibleCategories:
          parsedVisible.isEmpty ? defaults.visibleCategories : parsedVisible,
      showLegend:
          json['showLegend'] is bool ? json['showLegend'] as bool : defaults.showLegend,
      legendCollapsed: json['legendCollapsed'] is bool
          ? json['legendCollapsed'] as bool
          : defaults.legendCollapsed,
      emphasizeContentWords: json['emphasizeContentWords'] is bool
          ? json['emphasizeContentWords'] as bool
          : defaults.emphasizeContentWords,
      dimHiddenCategories: json['dimHiddenCategories'] is bool
          ? json['dimHiddenCategories'] as bool
          : defaults.dimHiddenCategories,
    );
  }
}
