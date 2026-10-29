import '../../../models/word_analysis.dart';
import 'grammar_category.dart';

class GrammarToken {
  final String surface;
  final String normalized;
  final String lemma;
  final GrammarCategory category;
  final String? subCategory;
  final double confidence;
  final int startOffset;
  final int endOffset;
  final bool isStopWord;
  final WordType legacyWordType;

  const GrammarToken({
    required this.surface,
    required this.normalized,
    required this.lemma,
    required this.category,
    this.subCategory,
    required this.confidence,
    required this.startOffset,
    required this.endOffset,
    this.isStopWord = false,
    this.legacyWordType = WordType.unknown,
  });

  int get length => endOffset - startOffset;
  bool get isContentWord => category.isContentWord;
  bool get isFunctionWord => category.isFunctionWord;

  GrammarToken copyWith({
    String? surface,
    String? normalized,
    String? lemma,
    GrammarCategory? category,
    String? subCategory,
    double? confidence,
    int? startOffset,
    int? endOffset,
    bool? isStopWord,
    WordType? legacyWordType,
  }) {
    return GrammarToken(
      surface: surface ?? this.surface,
      normalized: normalized ?? this.normalized,
      lemma: lemma ?? this.lemma,
      category: category ?? this.category,
      subCategory: subCategory ?? this.subCategory,
      confidence: confidence ?? this.confidence,
      startOffset: startOffset ?? this.startOffset,
      endOffset: endOffset ?? this.endOffset,
      isStopWord: isStopWord ?? this.isStopWord,
      legacyWordType: legacyWordType ?? this.legacyWordType,
    );
  }

  Map<String, dynamic> toJson() => {
        'surface': surface,
        'normalized': normalized,
        'lemma': lemma,
        'category': category.name,
        'subCategory': subCategory,
        'confidence': confidence,
        'startOffset': startOffset,
        'endOffset': endOffset,
        'isStopWord': isStopWord,
        'legacyWordType': legacyWordType.name,
      };

  factory GrammarToken.fromJson(Map<String, dynamic> json) {
    return GrammarToken(
      surface: (json['surface'] ?? '').toString(),
      normalized: (json['normalized'] ?? '').toString(),
      lemma: (json['lemma'] ?? '').toString(),
      category: GrammarCategory.values.firstWhere(
        (value) => value.name == json['category'],
        orElse: () => GrammarCategory.unknown,
      ),
      subCategory: json['subCategory']?.toString(),
      confidence: ((json['confidence'] as num?) ?? 0).toDouble(),
      startOffset: ((json['startOffset'] as num?) ?? 0).toInt(),
      endOffset: ((json['endOffset'] as num?) ?? 0).toInt(),
      isStopWord: json['isStopWord'] == true,
      legacyWordType: WordType.values.firstWhere(
        (value) => value.name == json['legacyWordType'],
        orElse: () => WordType.unknown,
      ),
    );
  }

  factory GrammarToken.fromAnalyzedWord(
    AnalyzedWord word, {
    required int startOffset,
    required int endOffset,
    GrammarCategory? overrideCategory,
    String? overrideLemma,
    String? overrideSubCategory,
    double? overrideConfidence,
  }) {
    final normalized = word.word.toLowerCase().replaceAll(RegExp(r"[^\w']"), '');
    return GrammarToken(
      surface: word.originalWord,
      normalized: normalized,
      lemma: overrideLemma ?? normalized,
      category: overrideCategory ?? grammarCategoryFromLegacyWordType(word.wordType),
      subCategory: overrideSubCategory,
      confidence: overrideConfidence ?? 0.55,
      startOffset: startOffset,
      endOffset: endOffset,
      isStopWord: word.isStopWord,
      legacyWordType: word.wordType,
    );
  }
}
