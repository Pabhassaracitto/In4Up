import 'grammar_category.dart';
import 'grammar_token.dart';

class GrammarAnalysisResult {
  final String sourceText;
  final List<GrammarToken> tokens;
  final String? sourceLabel;

  const GrammarAnalysisResult({
    required this.sourceText,
    required this.tokens,
    this.sourceLabel,
  });

  bool get isEmpty => tokens.isEmpty;
  int get tokenCount => tokens.length;
  int get unknownCount =>
      tokens.where((token) => token.category == GrammarCategory.unknown).length;
  int get contentWordCount =>
      tokens.where((token) => token.isContentWord).length;
  int get functionWordCount =>
      tokens.where((token) => token.isFunctionWord).length;

  Set<GrammarCategory> get categoriesFound =>
      tokens.map((token) => token.category).toSet();

  List<GrammarToken> byCategory(GrammarCategory category) {
    return tokens.where((token) => token.category == category).toList();
  }

  Map<String, dynamic> toJson() => {
        'sourceText': sourceText,
        'sourceLabel': sourceLabel,
        'tokens': tokens.map((token) => token.toJson()).toList(),
      };

  factory GrammarAnalysisResult.fromJson(Map<String, dynamic> json) {
    return GrammarAnalysisResult(
      sourceText: (json['sourceText'] ?? '').toString(),
      sourceLabel: json['sourceLabel']?.toString(),
      tokens: (json['tokens'] as List<dynamic>? ?? const [])
          .map((item) => GrammarToken.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
    );
  }
}
