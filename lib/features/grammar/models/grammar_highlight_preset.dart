import 'grammar_category.dart';

class GrammarHighlightPreset {
  final String id;
  final String name;
  final String description;
  final Set<GrammarCategory> visibleCategories;
  final bool showLegend;
  final bool emphasizeContentWords;
  final String audienceLabel;
  final String focusSummary;
  final bool isBuiltIn;

  const GrammarHighlightPreset({
    required this.id,
    required this.name,
    required this.description,
    required this.visibleCategories,
    this.showLegend = true,
    this.emphasizeContentWords = false,
    this.audienceLabel = 'Cá nhân',
    this.focusSummary = '',
    this.isBuiltIn = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'visibleCategories': visibleCategories.map((value) => value.name).toList(),
        'showLegend': showLegend,
        'emphasizeContentWords': emphasizeContentWords,
        'audienceLabel': audienceLabel,
        'focusSummary': focusSummary,
        'isBuiltIn': isBuiltIn,
      };

  factory GrammarHighlightPreset.fromJson(Map<String, dynamic> json) {
    final rawVisible = json['visibleCategories'];
    final visible = (rawVisible is List ? rawVisible : const <dynamic>[])
        .map((item) => GrammarCategory.values.firstWhere(
              (value) => value.name == item,
              orElse: () => GrammarCategory.unknown,
            ))
        .toSet();
    return GrammarHighlightPreset(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      visibleCategories: visible,
      showLegend: json['showLegend'] != false,
      emphasizeContentWords: json['emphasizeContentWords'] == true,
      audienceLabel: (json['audienceLabel'] ?? 'Cá nhân').toString(),
      focusSummary: (json['focusSummary'] ?? '').toString(),
      isBuiltIn: json['isBuiltIn'] == true,
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
        audienceLabel: 'Học nhanh',
        focusSummary: 'Noun · Verb · Adj · Adv',
        isBuiltIn: true,
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
        audienceLabel: 'Đọc sâu',
        focusSummary: 'Nhấn nghĩa chính trong câu',
        isBuiltIn: true,
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
        audienceLabel: 'Ngữ pháp',
        focusSummary: 'Khung câu · liên kết · trợ từ',
        isBuiltIn: true,
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
        audienceLabel: 'Verb chain',
        focusSummary: 'Động từ chính · trợ động · modal',
        isBuiltIn: true,
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
        audienceLabel: 'Tối giản',
        focusSummary: 'Chỉ giữ noun + verb',
        isBuiltIn: true,
      ),
    ];
  }

  static GrammarHighlightPreset byId(String? id) {
    final presets = defaults();
    for (final preset in presets) {
      if (preset.id == id) return preset;
    }
    if ((id ?? '').trim().toLowerCase() == 'custom') {
      return const GrammarHighlightPreset(
        id: 'custom',
        name: 'Tùy chỉnh',
        description: 'Preset tùy chỉnh — bật/tắt thủ công từng nhóm từ loại.',
        visibleCategories: <GrammarCategory>{},
        showLegend: true,
        audienceLabel: 'Cá nhân',
        focusSummary: 'Tùy biến thủ công',
      );
    }
    return presets.first;
  }
}
