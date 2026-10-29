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
    final typeName = _stringFrom(
      json,
      const ['analysisType', 'analysis_type', 'type'],
    );
    final type = AiAnalysisType.values.firstWhere(
      (e) => e.name == typeName,
      orElse: () => AiAnalysisType.wordLookup,
    );
    final wordMap = _mapFrom(json['word_detail']) ?? _mapFrom(json['wordDetail']);
    final grammarMap = _mapFrom(json['grammar']);

    return AiAnalysis(
      inputText: inputText,
      type: type,
      summary: _stringFrom(
        json,
        const ['summary', 'feedback', 'comment', 'answer', 'response', 'review'],
      ),
      topics: _stringListFrom(
        json,
        const ['topics', 'topic', 'tags', 'labels'],
      ),
      terms: _termsFrom(json['technical_terms'] ??
          json['technicalTerms'] ??
          json['terms'] ??
          json['key_terms']),
      actionItems: _stringListFrom(
        json,
        const [
          'action_items',
          'actionItems',
          'actions',
          'next_steps',
          'nextSteps',
          'suggestions',
          'recommendations',
        ],
      ),
      grammar: grammarMap != null ? GrammarAnalysis.fromJson(grammarMap) : null,
      wordDetail: wordMap != null ? WordDetail.fromJson(wordMap) : null,
      visualPrompt: _nullableStringFrom(json, const ['visual_prompt', 'visualPrompt']),
      ipaFallback: _nullableStringFrom(json, const ['ipa_fallback', 'ipaFallback']),
      paoSuggestions: _stringListFrom(json, const ['pao_suggestions', 'paoSuggestions']),
      contextExamples: _stringListFrom(json, const ['context_examples', 'contextExamples']),
      success: json['success'] as bool? ?? true,
      isPartial: json['isPartial'] as bool? ?? json['is_partial'] as bool? ?? false,
      errorReason: _nullableStringFrom(
        json,
        const ['errorReason', 'error_reason', 'error', 'message'],
      ),
      generatedAt: DateTime.now(),
      source: AiAnalysisSource.gemma,
      language: _stringFrom(json, const ['language'], fallback: 'en'),
    );
  }

  factory AiAnalysis.fromGemmaJson(
    String rawJson, {
    AiAnalysisType? analysisType,
    String? inputText,
  }) {
    final payload = _extractJsonPayload(rawJson);
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) {
        return _parseFailure(
          inputText ?? '',
          analysisType,
          'AI output is JSON but not an object',
        );
      }
      var map = Map<String, dynamic>.from(decoded);
      final nested = _mapFrom(map['analysis']) ??
          _mapFrom(map['result']) ??
          _mapFrom(map['output']) ??
          _mapFrom(map['data']);
      if (!_hasUsefulMap(map) && nested != null) {
        map = nested;
      }
      if (analysisType != null &&
          map['analysisType'] == null &&
          map['analysis_type'] == null) {
        map['analysisType'] = analysisType.name;
      }
      final resolved = (inputText != null && inputText.isNotEmpty)
          ? inputText
          : _stringFrom(map, const ['inputText', 'input_text']);
      final analysis = AiAnalysis.fromJson(map, resolved);
      if (_hasUsefulAnalysis(analysis)) return analysis;
      return _parseFailure(
        resolved,
        analysisType ?? analysis.analysisType,
        'AI JSON missing useful fields (summary/topics/action_items)',
      );
    } catch (e) {
      // Local/remote LLMs often wrap JSON in markdown fences, add prose around
      // it, or get cut off after writing the first fields. Rescue the fields
      // the Write tab needs (summary/topics/action_items) before declaring a
      // parser failure so the UI never shows three empty rows for a real model.
      final rescued = _rescuePartialAnalysis(
        rawJson,
        inputText: inputText ?? '',
        analysisType: analysisType,
        reason: 'Invalid AI JSON: $e',
      );
      if (rescued != null) return rescued;
      return _parseFailure(
        inputText ?? '',
        analysisType,
        'Invalid AI JSON: $e',
      );
    }
  }

  static AiAnalysis _parseFailure(
    String inputText,
    AiAnalysisType? analysisType,
    String reason,
  ) {
    return AiAnalysis(
      inputText: inputText,
      analysisType: analysisType ?? AiAnalysisType.error,
      summary: 'Không đọc được phản hồi JSON từ AI: $reason',
      topics: const ['AI parse error'],
      terms: const [],
      actionItems: const [
        'Chạy lại phản hồi AI; nếu vẫn lỗi, rút ngắn đoạn nhập hoặc đổi model.',
      ],
      success: false,
      errorReason: reason,
      isPartial: true,
      source: AiAnalysisSource.fallback,
      generatedAt: DateTime.now(),
      language: 'vi',
    );
  }

  static AiAnalysis? _rescuePartialAnalysis(
    String raw, {
    required String inputText,
    AiAnalysisType? analysisType,
    required String reason,
  }) {
    final summary = _rescueStringField(
      raw,
      const ['summary', 'feedback', 'comment', 'answer', 'response', 'review'],
    );
    var topics = _rescueStringList(
      raw,
      const ['topics', 'topic', 'tags', 'labels'],
    );
    var actions = _rescueStringList(
      raw,
      const [
        'action_items',
        'actionItems',
        'actions',
        'next_steps',
        'nextSteps',
        'suggestions',
        'recommendations',
      ],
    );
    if ((summary == null || summary.trim().isEmpty) &&
        topics.isEmpty &&
        actions.isEmpty) {
      return null;
    }
    topics = topics.isEmpty
        ? _defaultTopicsFor(inputText, analysisType)
        : _dedupeStrings(topics);
    actions = actions.isEmpty
        ? _defaultActionsFor(inputText, analysisType)
        : _dedupeStrings(actions);
    return AiAnalysis(
      inputText: inputText,
      analysisType: analysisType ?? AiAnalysisType.sentenceParse,
      summary: summary?.trim().isNotEmpty == true
          ? summary!.trim()
          : 'AI trả về JSON bị cắt; đã khôi phục một phần phản hồi.',
      topics: topics,
      terms: const [],
      actionItems: actions,
      success: true,
      errorReason: reason,
      isPartial: true,
      source: AiAnalysisSource.gemma,
      generatedAt: DateTime.now(),
      language: 'vi',
    );
  }

  /// Extract one JSON object from model output. Handles markdown fences and
  /// trailing prose; if the object is truncated, returns from the first `{` so
  /// the rescue path can still read early fields.
  static String _extractJsonPayload(String raw) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      final firstNewline = text.indexOf('\n');
      if (firstNewline > 0) text = text.substring(firstNewline + 1);
      final fenceEnd = text.lastIndexOf('```');
      if (fenceEnd >= 0) text = text.substring(0, fenceEnd);
      text = text.trim();
    }
    final start = text.indexOf('{');
    if (start < 0) return text;
    var depth = 0;
    var inString = false;
    var escaping = false;
    for (var i = start; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      if (inString) {
        if (escaping) {
          escaping = false;
        } else if (code == 0x5C) {
          escaping = true;
        } else if (code == 0x22) {
          inString = false;
        }
        continue;
      }
      if (code == 0x22) {
        inString = true;
      } else if (code == 0x7B) {
        depth++;
      } else if (code == 0x7D) {
        depth--;
        if (depth == 0) return text.substring(start, i + 1);
      }
    }
    return text.substring(start);
  }

  static String _stringFrom(
    Map<String, dynamic> json,
    List<String> keys, {
    String fallback = '',
  }) {
    return _nullableStringFrom(json, keys) ?? fallback;
  }

  static String? _nullableStringFrom(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
      if (value is num || value is bool) return value.toString();
    }
    return null;
  }

  static List<String> _stringListFrom(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = json[key];
      final parsed = _toStringList(value);
      if (parsed.isNotEmpty) return parsed;
    }
    return const [];
  }

  static List<String> _toStringList(Object? value) {
    if (value == null) return const [];
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? const [] : <String>[trimmed];
    }
    if (value is Iterable) {
      return _dedupeStrings([
        for (final item in value)
          if (item != null && item.toString().trim().isNotEmpty)
            item.toString().trim(),
      ]);
    }
    return const [];
  }

  static List<AiTerm> _termsFrom(Object? value) {
    if (value is! Iterable) return const [];
    final out = <AiTerm>[];
    for (final item in value) {
      final map = _mapFrom(item);
      if (map == null) continue;
      out.add(AiTerm.fromJson(map));
    }
    return out;
  }

  static Map<String, dynamic>? _mapFrom(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static bool _hasUsefulMap(Map<String, dynamic> map) {
    return _stringFrom(
          map,
          const ['summary', 'feedback', 'comment', 'answer', 'response', 'review'],
        ).isNotEmpty ||
        _stringListFrom(map, const ['topics', 'topic', 'tags', 'labels']).isNotEmpty ||
        _stringListFrom(map, const [
          'action_items',
          'actionItems',
          'actions',
          'next_steps',
          'nextSteps',
          'suggestions',
          'recommendations',
        ]).isNotEmpty ||
        _termsFrom(map['technical_terms'] ?? map['technicalTerms'] ?? map['terms']).isNotEmpty ||
        _mapFrom(map['word_detail']) != null ||
        _mapFrom(map['wordDetail']) != null ||
        _mapFrom(map['grammar']) != null ||
        _stringListFrom(map, const ['pao_suggestions', 'paoSuggestions']).isNotEmpty ||
        _stringListFrom(map, const ['context_examples', 'contextExamples']).isNotEmpty ||
        _nullableStringFrom(map, const ['visual_prompt', 'visualPrompt']) != null ||
        _nullableStringFrom(map, const ['ipa_fallback', 'ipaFallback']) != null;
  }

  static bool _hasUsefulAnalysis(AiAnalysis analysis) {
    return analysis.summary.trim().isNotEmpty ||
        analysis.topics.isNotEmpty ||
        analysis.actionItems.isNotEmpty ||
        analysis.terms.isNotEmpty ||
        analysis.wordDetail != null ||
        analysis.grammar != null ||
        analysis.paoSuggestions.isNotEmpty ||
        analysis.contextExamples.isNotEmpty ||
        (analysis.visualPrompt?.trim().isNotEmpty ?? false) ||
        (analysis.ipaFallback?.trim().isNotEmpty ?? false);
  }

  static String? _rescueStringField(String raw, List<String> names) {
    for (final name in names) {
      final escaped = RegExp.escape(name);
      final pattern = RegExp(
        '"$escaped"\\s*:\\s*"((?:[^"\\\\]|\\\\.)*)(?:"|\$)',
        dotAll: true,
      );
      final match = pattern.firstMatch(raw);
      final captured = match?.group(1);
      if (captured != null && captured.trim().isNotEmpty) {
        return _decodeJsonStringFragment(captured);
      }
    }
    return null;
  }

  static List<String> _rescueStringList(String raw, List<String> names) {
    for (final name in names) {
      final escaped = RegExp.escape(name);
      final start = RegExp('"$escaped"\\s*:\\s*\\[', dotAll: true)
          .firstMatch(raw);
      if (start == null) {
        final scalar = _rescueStringField(raw, <String>[name]);
        if (scalar != null && scalar.trim().isNotEmpty) {
          return <String>[scalar.trim()];
        }
        continue;
      }
      var tail = raw.substring(start.end);
      final close = tail.indexOf(']');
      if (close >= 0) {
        tail = tail.substring(0, close);
      } else {
        final nextFieldNewline =
            RegExp('\n\\s*"[A-Za-z_][A-Za-z0-9_]*"\\s*:')
                .firstMatch(tail);
        final nextFieldComma =
            RegExp(',\\s*"[A-Za-z_][A-Za-z0-9_]*"\\s*:')
                .firstMatch(tail);
        final cutPoints = <int>[
          if (nextFieldNewline != null) nextFieldNewline.start,
          if (nextFieldComma != null) nextFieldComma.start,
        ];
        if (cutPoints.isNotEmpty) {
          cutPoints.sort();
          tail = tail.substring(0, cutPoints.first);
        }
      }
      final values = <String>[];
      final itemPattern = RegExp('"((?:[^"\\\\]|\\\\.)*)"', dotAll: true);
      for (final match in itemPattern.allMatches(tail)) {
        final captured = match.group(1);
        if (captured == null) continue;
        final value = _decodeJsonStringFragment(captured).trim();
        if (value.isNotEmpty) values.add(value);
      }
      if (values.isNotEmpty) return _dedupeStrings(values);
    }
    return const [];
  }

  static String _decodeJsonStringFragment(String captured) {
    try {
      return jsonDecode('"$captured"') as String;
    } catch (_) {
      return captured
          .replaceAll(r'\"', '"')
          .replaceAll(r'\n', '\n')
          .replaceAll(r'\\', r'\');
    }
  }

  static List<String> _dedupeStrings(Iterable<String> values) {
    final seen = <String>{};
    final out = <String>[];
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) continue;
      final key = trimmed.toLowerCase();
      if (seen.add(key)) out.add(trimmed);
    }
    return out;
  }

  static List<String> _defaultTopicsFor(String inputText, AiAnalysisType? type) {
    if (inputText.contains('in4up_SUMMARY_REVIEW')) {
      return const ['Summary', 'Compression'];
    }
    if (inputText.contains('in4up_REWRITE_REVIEW')) {
      return const ['Rewrite', 'Output'];
    }
    if (inputText.contains('in4up_WRITE_REVIEW')) {
      return const ['Writing', 'Recall'];
    }
    switch (type) {
      case AiAnalysisType.wordLookup:
        return const ['Vocabulary'];
      case AiAnalysisType.sentenceParse:
        return const ['Grammar'];
      case AiAnalysisType.summarize:
        return const ['Summary'];
      case AiAnalysisType.termExtract:
        return const ['Terminology'];
      case AiAnalysisType.conversation:
        return const ['Conversation'];
      case AiAnalysisType.paoGeneration:
        return const ['Memory', 'Vocabulary'];
      case AiAnalysisType.error:
      case null:
        return const ['AI review'];
    }
  }

  static List<String> _defaultActionsFor(String inputText, AiAnalysisType? type) {
    if (inputText.contains('in4up_SUMMARY_REVIEW') ||
        inputText.contains('in4up_REWRITE_REVIEW') ||
        inputText.contains('in4up_WRITE_REVIEW')) {
      return const [
        'Đọc lại nhận xét đã khôi phục; chạy lại AI nếu cần gợi ý chi tiết hơn.',
      ];
    }
    if (type == AiAnalysisType.conversation) return const [];
    return const [
      'Chạy lại phản hồi AI hoặc giảm độ dài đoạn nhập để model trả JSON đầy đủ.',
    ];
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
