import 'grammar_category.dart';

class GrammarHighlightPreset {
  final String id;
  final String name;
  final String description;
  final Set<GrammarCategory> visibleCategories;
  final bool showLegend;
  final bool emphasizeContentWords;

  const GrammarHighlightPreset({
    required this.id,
    required this.name,
    required this.description,
    required this.visibleCategories,
    this.showLegend = true,
    this.emphasizeContentWords = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'visibleCategories': visibleCategories.map((value) => value.name).toList(),
        'showLegend': showLegend,
        'emphasizeContentWords': emphasizeContentWords,
      };

  factory GrammarHighlightPreset.fromJson(Map<String, dynamic> json) {
    return GrammarHighlightPreset(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      visibleCategories: ((json['visibleCategories'] as List<dynamic>? ?? const [])
              .map((item) => GrammarCategory.values.firstWhere(
                    (value) => value.name == item,
                    orElse: () => GrammarCategory.unknown,
                  )))
          .toSet(),
      showLegend: json['showLegend'] != false,
      emphasizeContentWords: json['emphasizeContentWords'] == true,
    );
  }
}

class GrammarHighlightPresets {
  GrammarHighlightPresets._();

  static List<GrammarHighlightPreset> defaults() {
    return const [
      GrammarHighlightPreset(
        id: 'basic-pos',
        name: 'Basic POS',
        description: 'Hiển thị các nhóm từ loại phổ biến nhất để đọc và học nhanh.',
        visibleCategories: {
          GrammarCategory.noun,
          GrammarCategory.verb,
          GrammarCategory.adjective,
          GrammarCategory.adverb,
        },
        showLegend: true,
      ),
      GrammarHighlightPreset(
        id: 'content-words',
        name: 'Content Words',
        description: 'Tập trung vào từ mang nghĩa chính: noun, verb, adjective, adverb.',
        visibleCategories: {
          GrammarCategory.noun,
          GrammarCategory.verb,
          GrammarCategory.adjective,
          GrammarCategory.adverb,
          GrammarCategory.interjection,
          GrammarCategory.number,
        },
        showLegend: true,
        emphasizeContentWords: true,
      ),
      GrammarHighlightPreset(
        id: 'function-words',
        name: 'Function Words',
        description: 'Tập trung vào cấu trúc: pronoun, determiner, auxiliary, preposition...',
        visibleCategories: {
          GrammarCategory.pronoun,
          GrammarCategory.determiner,
          GrammarCategory.preposition,
          GrammarCategory.conjunction,
          GrammarCategory.auxiliary,
          GrammarCategory.modal,
          GrammarCategory.particle,
        },
        showLegend: true,
      ),
      GrammarHighlightPreset(
        id: 'verb-focus',
        name: 'Verb Focus',
        description: 'Nhấn mạnh động từ, trợ động từ và modal để luyện verb chain.',
        visibleCategories: {
          GrammarCategory.verb,
          GrammarCategory.auxiliary,
          GrammarCategory.modal,
          GrammarCategory.adverb,
        },
        showLegend: true,
      ),
      GrammarHighlightPreset(
        id: 'minimal',
        name: 'Minimal',
        description: 'Chỉ hiển thị noun + verb để giữ bề mặt đọc tối giản.',
        visibleCategories: {
          GrammarCategory.noun,
          GrammarCategory.verb,
        },
        showLegend: false,
      ),
    ];
  }

  static GrammarHighlightPreset byId(String? id) {
    final presets = defaults();
    return presets.firstWhere(
      (preset) => preset.id == id,
      orElse: () => presets.first,
    );
  }
}
