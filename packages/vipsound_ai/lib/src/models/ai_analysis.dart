// packages/vipsound_ai/lib/src/models/ai_analysis.dart
// v11.0 — Dữ liệu chuẩn cho AiAnalysis + AiAnalysisType (Backward-compatible với các API cũ)

// ─── Enum & Compatibility Helpers ─────────────────────────────────────────────

enum AiAnalysisType {
  wordLookup,
  sentenceParse,
  summarize,
  termExtract,
  conversation,
  paoGeneration, 
  error,
}

// ─── WordAnalysis ─────────────────────────────────────────────────────────────

class WordAnalysis {
  final String word;
  final String? meaning;
  final String? phonetic;
  final String? wordTypeLabel;
  final String? cefrLevel;
  final String? synonym;
  final String? memoryHook;

  const WordAnalysis({
    required this.word,
    this.meaning,
    this.phonetic,
    this.wordTypeLabel,
    this.cefrLevel,
    this.synonym,
    this.memoryHook,
  });

  factory WordAnalysis.fromJson(Map<String, dynamic> j) => WordAnalysis(
        word: j['word'] as String? ?? '',
        meaning: j['meaning'] as String?,
        phonetic: j['phonetic'] as String?,
        wordTypeLabel: j['word_type_label'] as String?,
        cefrLevel: j['cefr_level'] as String?,
        synonym: j['synonym'] as String?,
        memoryHook: j['memory_hook'] as String?,
      );

  // ★ KHÔI PHỤC: copyWith() cho backward compatibility
  WordAnalysis copyWith({
    String? meaning,
    String? phonetic,
  }) {
    return WordAnalysis(
      word: word,
      meaning: meaning ?? this.meaning,
      phonetic: phonetic ?? this.phonetic,
      wordTypeLabel: wordTypeLabel,
      cefrLevel: cefrLevel,
      synonym: synonym,
      memoryHook: memoryHook,
    );
  }
}

// ─── GrammarAnalysis ──────────────────────────────────────────────────────────

class GrammarAnalysis {
  final String subject;
  final String verb;
  final String object;
  final String? complement;
  final String? adverbial;
  final String pattern;
  final String explanationVi;

  const GrammarAnalysis({
    required this.subject,
    required this.verb,
    required this.object,
    this.complement,
    this.adverbial,
    required this.pattern,
    required this.explanationVi,
  });

  factory GrammarAnalysis.fromJson(Map<String, dynamic> j) => GrammarAnalysis(
        subject: j['subject'] as String? ?? '',
        verb: j['verb'] as String? ?? '',
        object: j['object'] as String? ?? '',
        complement: j['complement'] as String?,
        adverbial: j['adverbial'] as String?,
        pattern: j['pattern'] as String? ?? '',
        explanationVi: j['explanation_vi'] as String? ?? '',
      );
}

// ─── AiTerm ───────────────────────────────────────────────────────────────────

class AiTerm {
  final String text;
  final String definition;
  final double importance;
  final String sourceJoinKey;
  final int speakerId;

  const AiTerm({
    required this.text,
    required this.definition,
    required this.importance,
    required this.sourceJoinKey,
    this.speakerId = 0,
  });

  factory AiTerm.fromJson(Map<String, dynamic> j) => AiTerm(
        text: j['text'] as String? ?? '',
        definition: j['definition'] as String? ?? '',
        importance: (j['importance'] as num?)?.toDouble() ?? 0.0,
        sourceJoinKey: j['sourceJoinKey'] as String? ?? '',
        speakerId: j['speakerId'] as int? ?? 0,
      );
}

// ─── AiAnalysis ────────────────────────────────────────────────────────────────

class AiAnalysis {
  final String inputText;
  final AiAnalysisType type;
  final String summary;
  final List<String> topics;
  final List<AiTerm> terms;
  final List<String> actionItems;
  final List<String> paoSuggestions;
  final List<String> contextExamples;
  final WordAnalysis? wordDetail;
  final GrammarAnalysis? grammar;
  final String? visualPrompt;
  final String? ipaFallback;
  final bool isPartial;
  final bool success;
  final String? errorReason;
  final AiAnalysisSource source;
  final DateTime generatedAt;

  const AiAnalysis({
    required this.inputText,
    required this.type,
    required this.summary,
    required this.topics,
    required this.terms,
    required this.success,
    this.actionItems = const [],
    this.wordDetail,
    this.grammar,
    this.visualPrompt,
    this.ipaFallback,
    this.paoSuggestions = const [],
    this.contextExamples = const [],
    this.isPartial = false,
    this.errorReason,
    this.source = AiAnalysisSource.gemma,
    required this.generatedAt,
  });

  factory AiAnalysis.fromJson(Map<String, dynamic> json, String inputText) {
    return AiAnalysis(
      inputText: inputText,
      type: AiAnalysisType.values.firstWhere(
        (e) => e.name == (json['type'] as String? ?? ''),
        orElse: () => AiAnalysisType.wordLookup,
      ),
      summary: json['summary'] as String? ?? '',
      topics: (json['topics'] as List?)?.map((e) => e.toString()).toList() ?? [],
      terms: (json['technical_terms'] as List?)
              ?.map((e) => AiTerm.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      actionItems:
          (json['action_items'] as List?)?.map((e) => e.toString()).toList() ?? [],
      grammar: json['grammar'] != null ? GrammarAnalysis.fromJson(json['grammar'] as Map<String, dynamic>) : null,
      wordDetail: json['word_detail'] != null ? WordAnalysis.fromJson(json['word_detail'] as Map<String, dynamic>) : null,
      visualPrompt: json['visual_prompt'] as String?,
      ipaFallback: json['ipa_fallback'] as String?,
      paoSuggestions:
          (json['pao_suggestions'] as List?)?.map((e) => e.toString()).toList() ?? [],
      contextExamples:
          (json['context_examples'] as List?)?.map((e) => e.toString()).toList() ?? [],
      success: true,
      isPartial: false,
      generatedAt: DateTime.now(),
      source: AiAnalysisSource.gemma,
    );
  }

  // ★ KHÔI PHỤC: fromLocalDict()
  factory AiAnalysis.fromLocalDict({
    required String inputText,
    required String meaning,
    String? phonetic,
  }) {
    return AiAnalysis(
      inputText: inputText,
      type: AiAnalysisType.wordLookup,
      summary: meaning,
      topics: const ['Vocabulary'],
      terms: const [],
      success: true,
      wordDetail: WordAnalysis(
        word: inputText,
        meaning: meaning,
        phonetic: phonetic,
      ),
      generatedAt: DateTime.now(),
      source: AiAnalysisSource.localDict,
      isPartial: true,
    );
  }

  // ★ KHÔI PHỤC: withIpa()
  AiAnalysis withIpa(String ipa) {
    return AiAnalysis(
      inputText: inputText,
      type: type,
      summary: summary,
      topics: topics,
      terms: terms,
      success: success,
      actionItems: actionItems,
      wordDetail: wordDetail == null
          ? null
          : wordDetail!.copyWith(
              phonetic: ipa,
            ),
      grammar: grammar,
      visualPrompt: visualPrompt,
      ipaFallback: ipa,
      paoSuggestions: paoSuggestions,
      contextExamples: contextExamples,
      generatedAt: generatedAt,
      source: AiAnalysisSource.cmuDict,
      isPartial: true,
      errorReason: errorReason,
    );
  }

  factory AiAnalysis.fallback(String inputText, {String? errorReason}) {
    return AiAnalysis(
      inputText: inputText,
      type: AiAnalysisType.error,
      summary: '',
      topics: const [],
      terms: const [],
      success: false,
      errorReason: errorReason ?? 'Unknown error',
      isPartial: true,
      generatedAt: DateTime.now(),
      source: AiAnalysisSource.fallback,
    );
  }
}

enum AiAnalysisSource {
  localDict,
  cmuDict, // ★ KHÔI PHỤC
  gemma,
  fallback,
}
