import 'phrase_info.dart';
import 'sentence_structure.dart';

class StructureAnalysis {
  final String sourceText;
  final bool supported;
  final PhraseInfo? phrase;
  final PhraseInfo? outer;
  final SentenceStructure? sentence;
  final ClauseRole? clauseRole;
  final int? conditionalType;
  final int sentenceStart;
  final int sentenceEnd;
  final double confidence;
  final List<String> notes;

  const StructureAnalysis({
    required this.sourceText,
    required this.supported,
    this.phrase,
    this.outer,
    this.sentence,
    this.clauseRole,
    this.conditionalType,
    this.sentenceStart = 0,
    this.sentenceEnd = 0,
    this.confidence = 0.85,
    this.notes = const [],
  });

  bool get isConfident => supported && confidence >= 0.6;
  bool get hasLineContinuationNote => notes.contains('line_continues');

  String get sentenceSpanText {
    if (sourceText.isEmpty) return '';
    final start = sentenceStart.clamp(0, sourceText.length).toInt();
    final end = sentenceEnd.clamp(start, sourceText.length).toInt();
    return sourceText.substring(start, end);
  }

  Map<String, dynamic> toJson() => {
        'sourceText': sourceText,
        'supported': supported,
        if (phrase != null) 'phrase': phrase!.toJson(sourceText: sourceText),
        if (outer != null) 'outer': outer!.toJson(sourceText: sourceText),
        if (sentence != null) 'sentence': sentence!.toJson(sourceText: sourceText),
        if (clauseRole != null) 'clause_role': clauseRole!.wireName,
        if (conditionalType != null) 'conditional': conditionalType,
        'sentence_span': sentenceSpanText,
        'confidence': confidence,
        'notes': notes,
      };
}
