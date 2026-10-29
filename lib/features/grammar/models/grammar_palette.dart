import 'package:flutter/material.dart';

import 'grammar_category.dart';

class GrammarCategoryStyle {
  final int colorValue;
  final bool isBold;

  const GrammarCategoryStyle({
    required this.colorValue,
    this.isBold = false,
  });

  Color get color => Color(colorValue);

  Map<String, dynamic> toJson() => {
        'colorValue': colorValue,
        'isBold': isBold,
      };

  factory GrammarCategoryStyle.fromJson(Map<String, dynamic> json) {
    return GrammarCategoryStyle(
      colorValue: ((json['colorValue'] as num?) ?? 0xFFFFFFFF).toInt(),
      isBold: json['isBold'] == true,
    );
  }
}

class GrammarPalette {
  final String id;
  final String name;
  final bool isDark;
  final Map<GrammarCategory, GrammarCategoryStyle> styles;

  const GrammarPalette({
    required this.id,
    required this.name,
    required this.isDark,
    required this.styles,
  });

  GrammarCategoryStyle styleFor(GrammarCategory category) {
    return styles[category] ??
        const GrammarCategoryStyle(colorValue: 0xFFFFFFFF, isBold: false);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'isDark': isDark,
        'styles': {
          for (final entry in styles.entries) entry.key.name: entry.value.toJson(),
        },
      };

  factory GrammarPalette.fromJson(Map<String, dynamic> json) {
    final rawStyles = Map<String, dynamic>.from(
      json['styles'] as Map<String, dynamic>? ?? const <String, dynamic>{},
    );
    final resolved = <GrammarCategory, GrammarCategoryStyle>{};
    for (final category in GrammarCategory.values) {
      final raw = rawStyles[category.name];
      if (raw is Map<String, dynamic>) {
        resolved[category] = GrammarCategoryStyle.fromJson(raw);
      } else if (raw is Map) {
        resolved[category] =
            GrammarCategoryStyle.fromJson(Map<String, dynamic>.from(raw));
      }
    }
    return GrammarPalette(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      isDark: json['isDark'] == true,
      styles: resolved,
    );
  }
}

class GrammarPalettes {
  GrammarPalettes._();

  static List<GrammarPalette> defaults() {
    return [
      _classicDark(),
      _classicLight(),
      _nounVerbFocus(),
    ];
  }

  static GrammarPalette byId(String? id) {
    final all = defaults();
    return all.firstWhere(
      (palette) => palette.id == id,
      orElse: () => all.first,
    );
  }

  static GrammarPalette _classicDark() {
    return GrammarPalette(
      id: 'classic-dark',
      name: 'Classic Dark',
      isDark: true,
      styles: {
        GrammarCategory.verb:
            const GrammarCategoryStyle(colorValue: 0xFFF2777A),
        GrammarCategory.adverb:
            const GrammarCategoryStyle(colorValue: 0xFFF99157),
        GrammarCategory.adjective:
            const GrammarCategoryStyle(colorValue: 0xFFFFCC66),
        GrammarCategory.interjection:
            const GrammarCategoryStyle(colorValue: 0xFF99CC99),
        GrammarCategory.preposition:
            const GrammarCategoryStyle(colorValue: 0xFF66CCCC),
        GrammarCategory.noun:
            const GrammarCategoryStyle(colorValue: 0xFF6699CC),
        GrammarCategory.conjunction:
            const GrammarCategoryStyle(colorValue: 0xFFF2F0EC),
        GrammarCategory.pronoun:
            const GrammarCategoryStyle(colorValue: 0xFFCC99CC),
        GrammarCategory.determiner:
            const GrammarCategoryStyle(colorValue: 0xFFD3D0C8),
        GrammarCategory.particle:
            const GrammarCategoryStyle(colorValue: 0xFFE8E6DF),
        GrammarCategory.auxiliary:
            const GrammarCategoryStyle(colorValue: 0xFFD27B53, isBold: true),
        GrammarCategory.modal:
            const GrammarCategoryStyle(colorValue: 0xFF6699CC, isBold: true),
        GrammarCategory.number:
            const GrammarCategoryStyle(colorValue: 0xFFF99157),
        GrammarCategory.punctuation:
            const GrammarCategoryStyle(colorValue: 0xFFD3D0C8),
        GrammarCategory.unknown:
            const GrammarCategoryStyle(colorValue: 0xFF9E9E9E),
      },
    );
  }

  static GrammarPalette _classicLight() {
    return GrammarPalette(
      id: 'classic-light',
      name: 'Classic Light',
      isDark: false,
      styles: {
        GrammarCategory.verb:
            const GrammarCategoryStyle(colorValue: 0xFFA01120),
        GrammarCategory.adverb:
            const GrammarCategoryStyle(colorValue: 0xFFB955BE),
        GrammarCategory.adjective:
            const GrammarCategoryStyle(colorValue: 0xFFBB8902),
        GrammarCategory.interjection:
            const GrammarCategoryStyle(colorValue: 0xFF58AA58),
        GrammarCategory.preposition:
            const GrammarCategoryStyle(colorValue: 0xFF058D8D),
        GrammarCategory.noun:
            const GrammarCategoryStyle(colorValue: 0xFF2A79CA),
        GrammarCategory.conjunction:
            const GrammarCategoryStyle(colorValue: 0xFF3D2D0E),
        GrammarCategory.pronoun:
            const GrammarCategoryStyle(colorValue: 0xFF4B1AC5),
        GrammarCategory.determiner:
            const GrammarCategoryStyle(colorValue: 0xFF795B07),
        GrammarCategory.particle:
            const GrammarCategoryStyle(colorValue: 0xFF523F02),
        GrammarCategory.auxiliary:
            const GrammarCategoryStyle(colorValue: 0xFFD27B53, isBold: true),
        GrammarCategory.modal:
            const GrammarCategoryStyle(colorValue: 0xFF215D69, isBold: true),
        GrammarCategory.number:
            const GrammarCategoryStyle(colorValue: 0xFFB955BE),
        GrammarCategory.punctuation:
            const GrammarCategoryStyle(colorValue: 0xFF795B07),
        GrammarCategory.unknown:
            const GrammarCategoryStyle(colorValue: 0xFF757575),
      },
    );
  }

  static GrammarPalette _nounVerbFocus() {
    return GrammarPalette(
      id: 'noun-verb-focus',
      name: 'Noun + Verb Focus',
      isDark: false,
      styles: {
        for (final category in GrammarCategory.values)
          category: category == GrammarCategory.noun
              ? const GrammarCategoryStyle(colorValue: 0xFF005FC3, isBold: true)
              : category == GrammarCategory.verb
                  ? const GrammarCategoryStyle(colorValue: 0xFF9E0513, isBold: true)
                  : const GrammarCategoryStyle(colorValue: 0xFF000000),
      },
    );
  }
}
