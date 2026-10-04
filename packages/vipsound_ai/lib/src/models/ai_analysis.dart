// packages/vipsound_ai/lib/src/models/ai_analysis.dart
// v11.0 — Dữ liệu chuẩn cho AiAnalysis + AiAnalysisType

import 'dart:convert';

enum AiAnalysisType {
  wordLookup,
  sentenceParse,
  summarize,
  termExtract,
  conversation,
  paoGeneration,
  error,
}

// ─── WordDetail (canonical) ──────────────────────────────────────────────────

class WordDetail {
  final String word;
  final String? meaning;
  final String? phonetic;
  final String? wordType;
  final String? wordTypeLabel;
  final String? cefrLevel;
  final String? synonym;
  final String? etymologyHint;
  final String? memoryHook;

  const WordDetail({
    required this.word,
    this.meaning,
    this.phonetic,
    this.wordType,
    this.wordTypeLabel,
    this.cefrLevel,
    this.synonym,
    this.etymologyHint,
    this.memoryHook,
  });

  factory WordDetail.fromJson(Map<String, dynamic> j) => WordDetail(
        word: j['word'] as String? ?? '',
        meaning: j['meaning'] as String?,
        phonetic: j['phonetic'] as String?,
        wordType: j['word_type'] as String? ?? j['wordType'] as String?,
        wordTypeLabel: j['word_type_label'] as String?,
        cefrLevel: j['cefr_level'] as String? ?? j['cefrLevel'] as String?,
        synonym: j['synonym'] as String?,
        etymologyHint: j['etymology_hint'] as String?,
        memoryHook: j['memory_hook'] as String?,
      );

  WordDetail copyWith({String? meaning, String? phonetic}) {
    return WordDetail(
      word: word,
      meaning: meaning ?? this.meaning,
      phonetic: phonetic ?? this.phonetic,
      wordType: wordType,
      wordTypeLabel: wordTypeLabel,
      cefrLevel: cefrLevel,
      synonym: synonym,
      etymologyHint: etymologyHint,
      memoryHook: memoryHook,
    );
  }
}

typedef WordAnalysis = WordDetail;

// ─── GrammarAnalysis ─────────────────────────────────────────────────────────

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
        sourceJoinKey: j['sourceJoinKey'] as String? ?? j['source_join_key'] as String? ?? '',
        speakerId: j['speakerId'] as int? ?? j['speaker_id'] as int? ?? 0,
      );
}

// ─── AiAnalysis ───────────────────────────────────────────────────────────────

class AiAnalysis {
  final String inputText;
  final AiAnalysisType type;
  AiAnalysisType get analysisType => type;
  final String summary;
  final List<String> topics;
  final List<AiTerm> terms;
  final List<String> actionItems;
  final List<String> paoSuggestions;
  final List<String> contextExamples;
  final WordDetail? wordDetail;
  final GrammarAnalysis? grammar;
  final String? visualPrompt;
  final String? ipaFallback;
  final bool isPartial;
  final bool success;
  final String? errorReason;
  final AiAnalysisSource source;
  final DateTime generatedAt;
  final String language;

  const AiAnalysis({
    this.inputText = '',
    AiAnalysisType? type,
    AiAnalysisType? analysisType,
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
    this.language = 'en',
  }) : type = type ?? analysisType ?? AiAnalysisType.wordLookup;

  factory AiAnalysis.fromJson(Map<String, dynamic> json, String inputText) {
    return AiAnalysis(
      inputText: inputText,
      type: AiAnalysisType.values.firstWhere(
        (e) => e.name == (json['analysisType'] as String? ?? json['analysis_type'] as String? ?? ''),
        orElse: () => AiAnalysisType.wordLookup,
      ),
      summary: json['summary'] as String? ?? '',
      topics: (json['topics'] as List?)?.map((e) => e.toString()).toList() ?? [],
      terms: (json['technical_terms'] as List?)
              ?.map((e) => AiTerm.fromJson(e as Map<String, dynamic>))
              .toList() ??
          (json['technicalTerms'] as List?)?.map((e) => AiTerm.fromJson(e as Map<String, dynamic>)).toList() ??
          [],
      actionItems: (json['action_items'] as List?)?.map((e) => e.toString()).toList() ??
          (json['actionItems'] as List?)?.map((e) => e.toString()).toList() ??
          [],
      grammar: json['grammar'] != null ? GrammarAnalysis.fromJson(json['grammar'] as Map<String, dynamic>) : null,
      wordDetail: json['word_detail'] != null
          ? WordDetail.fromJson(json['word_detail'] as Map<String, dynamic>)
          : json['wordDetail'] != null
              ? WordDetail.fromJson(json['wordDetail'] as Map<String, dynamic>)
              : null,
      visualPrompt: json['visual_prompt'] as String?,
      ipaFallback: json['ipa_fallback'] as String?,
      paoSuggestions: (json['pao_suggestions'] as List?)?.map((e) => e.toString()).toList() ?? [],
      contextExamples: (json['context_examples'] as List?)?.map((e) => e.toString()).toList() ?? [],
      success: json['success'] as bool? ?? true,
      isPartial: json['isPartial'] as bool? ?? false,
      generatedAt: DateTime.now(),
      source: AiAnalysisSource.gemma,
      language: json['language'] as String? ?? 'en',
    );
  }

  factory AiAnalysis.fromGemmaJson(String rawJson, {AiAnalysisType? analysisType}) {
    try {
      final map = jsonDecode(rawJson) as Map<String, dynamic>;
      if (analysisType != null && map['analysisType'] == null) {
        map['analysisType'] = analysisType.name;
      }
      return AiAnalysis.fromJson(map, map['inputText'] as String? ?? '');
    } catch (_) {
      return AiAnalysis.fallback('', errorReason: 'Invalid Gemma JSON', analysisType: analysisType);
    }
  }

  factory AiAnalysis.fallback(String inputText, {String? errorReason, AiAnalysisType? analysisType}) {
    return AiAnalysis(
      inputText: inputText,
      type: analysisType ?? AiAnalysisType.error,
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

  factory AiAnalysis.fromLocalDict({required String inputText, required String meaning, String? phonetic}) {
    return AiAnalysis(
      inputText: inputText,
      type: AiAnalysisType.wordLookup,
      summary: meaning,
      topics: const ['Vocabulary'],
      terms: const [],
      success: true,
      wordDetail: WordDetail(word: inputText, meaning: meaning, phonetic: phonetic),
      generatedAt: DateTime.now(),
      source: AiAnalysisSource.localDict,
      isPartial: true,
    );
  }

  factory AiAnalysis.empty() {
    return AiAnalysis(
      summary: '',
      topics: const [],
      terms: const [],
      success: false,
      generatedAt: DateTime.now(),
      source: AiAnalysisSource.fallback,
    );
  }

  AiAnalysis withIpa(String ipa) {
    return AiAnalysis(
      inputText: inputText,
      type: type,
      summary: summary,
      topics: topics,
      terms: terms,
      success: success,
      actionItems: actionItems,
      wordDetail: wordDetail == null ? null : wordDetail!.copyWith(phonetic: ipa),
      grammar: grammar,
      visualPrompt: visualPrompt,
      ipaFallback: ipa,
      paoSuggestions: paoSuggestions,
      contextExamples: contextExamples,
      generatedAt: generatedAt,
      source: AiAnalysisSource.cmuDict,
      isPartial: true,
      errorReason: errorReason,
      language: language,
    );
  }
}

enum AiAnalysisSource {
  localDict,
  cmuDict,
  gemma,
  fallback,
}
