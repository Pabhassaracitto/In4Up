import 'package:vipsound_core/vocab_level_difficulty.dart';

/// JSON Schema chuẩn - mọi output của Gemma PHẢI khớp schema này
/// Nếu không khớp → AiModelMapper trả về AiAnalysis.fallback()
class AiAnalysis {
  /// Văn bản gốc được phân tích
  final String inputText;

  /// Loại phân tích được thực hiện
  final AiAnalysisType type;

  /// Phân tích ngữ pháp theo "5 đầu ngón tay"
  final GrammarAnalysis? grammar;

  /// Phân tích từ vựng đơn lẻ
  final WordAnalysis? wordDetail;

  /// Gợi ý hình ảnh (thay thế Google Images - offline)
  final String? visualPrompt;

  /// Phiên âm IPA (fallback khi Tầng 1+2 thất bại)
  final String? ipaFallback;

  /// PAO - 3 gợi ý câu chuyện để user chọn
  final List<String> paoSuggestions;

  /// Câu ví dụ minh họa trong ngữ cảnh
  final List<String> contextExamples;

  /// Metadata
  final DateTime generatedAt;
  final AiAnalysisSource source;
  final bool isPartial; // true = Tầng 1/2, false = Tầng 3 đầy đủ

  const AiAnalysis({
    required this.inputText,
    required this.type,
    this.grammar,
    this.wordDetail,
    this.visualPrompt,
    this.ipaFallback,
    this.paoSuggestions = const [],
    this.contextExamples = const [],
    required this.generatedAt,
    this.source = AiAnalysisSource.gemma,
    this.isPartial = false,
  });

  /// Factory: Tầng 1 - chỉ có dict offline (0ms)
  factory AiAnalysis.fromLocalDict({
    required String inputText,
    required String meaning,
    String? phonetic,
  }) {
    return AiAnalysis(
      inputText: inputText,
      type: AiAnalysisType.wordLookup,
      wordDetail: WordAnalysis(
        word: inputText,
        meaning: meaning,
        phonetic: phonetic,
        cefrLevel: null,
        wordTypeLabel: null,
      ),
      generatedAt: DateTime.now(),
      source: AiAnalysisSource.localDict,
      isPartial: true,
    );
  }

  /// Factory: Tầng 2 - thêm IPA từ CMU/Wiktionary
  AiAnalysis withIpa(String ipa) {
    return AiAnalysis(
      inputText: inputText,
      type: type,
      grammar: grammar,
      wordDetail: wordDetail?.copyWith(phonetic: ipa),
      visualPrompt: visualPrompt,
      ipaFallback: ipa,
      paoSuggestions: paoSuggestions,
      contextExamples: contextExamples,
      generatedAt: generatedAt,
      source: AiAnalysisSource.cmuDict,
      isPartial: true,
    );
  }

  /// Factory: Fallback khi mọi thứ thất bại
  factory AiAnalysis.fallback(String inputText, {String? errorReason}) {
    return AiAnalysis(
      inputText: inputText,
      type: AiAnalysisType.error,
      generatedAt: DateTime.now(),
      source: AiAnalysisSource.fallback,
      isPartial: true,
    );
  }

  /// Parse từ JSON của Gemma
  /// Ném AiParseException nếu JSON không hợp lệ
  factory AiAnalysis.fromJson(Map<String, dynamic> json, String inputText) {
    return AiAnalysis(
      inputText: inputText,
      type: AiAnalysisType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => AiAnalysisType.wordLookup,
      ),
      grammar: json['grammar'] != null
          ? GrammarAnalysis.fromJson(json['grammar'])
          : null,
      wordDetail: json['word_detail'] != null
          ? WordAnalysis.fromJson(json['word_detail'])
          : null,
      visualPrompt: json['visual_prompt'] as String?,
      ipaFallback: json['ipa_fallback'] as String?,
      paoSuggestions: (json['pao_suggestions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      contextExamples: (json['context_examples'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      generatedAt: DateTime.now(),
      source: AiAnalysisSource.gemma,
      isPartial: false,
    );
  }
}

// ─── Sub-models ───────────────────────────────────────────

class GrammarAnalysis {
  final String subjectPart;    // Ngón 1: Chủ ngữ
  final String verbPart;       // Ngón 2: Động từ
  final String objectPart;     // Ngón 3: Tân ngữ
  final String? complementPart; // Ngón 4: Bổ ngữ
  final String? adverbialPart;  // Ngón 5: Trạng ngữ
  final String patternLabel;   // Ví dụ: "S + V + O"
  final String explanationVi;  // Giải thích bằng tiếng Việt

  const GrammarAnalysis({
    required this.subjectPart,
    required this.verbPart,
    required this.objectPart,
    this.complementPart,
    this.adverbialPart,
    required this.patternLabel,
    required this.explanationVi,
  });

  factory GrammarAnalysis.fromJson(Map<String, dynamic> json) {
    return GrammarAnalysis(
      subjectPart: json['subject'] as String? ?? '',
      verbPart: json['verb'] as String? ?? '',
      objectPart: json['object'] as String? ?? '',
      complementPart: json['complement'] as String?,
      adverbialPart: json['adverbial'] as String?,
      patternLabel: json['pattern'] as String? ?? 'S + V',
      explanationVi: json['explanation_vi'] as String? ?? '',
    );
  }
}

class WordAnalysis {
  final String word;
  final String? meaning;
  final String? phonetic;
  final String? cefrLevel;   // "B2", "C1"...
  final String? wordTypeLabel; // "noun", "verb"...
  final String? etymologyHint;
  final String? memoryHook;  // Gợi nhớ theo Wyner

  const WordAnalysis({
    required this.word,
    this.meaning,
    this.phonetic,
    this.cefrLevel,
    this.wordTypeLabel,
    this.etymologyHint,
    this.memoryHook,
  });

  WordAnalysis copyWith({String? phonetic, String? meaning}) {
    return WordAnalysis(
      word: word,
      meaning: meaning ?? this.meaning,
      phonetic: phonetic ?? this.phonetic,
      cefrLevel: cefrLevel,
      wordTypeLabel: wordTypeLabel,
      etymologyHint: etymologyHint,
      memoryHook: memoryHook,
    );
  }

  factory WordAnalysis.fromJson(Map<String, dynamic> json) {
    return WordAnalysis(
      word: json['word'] as String? ?? '',
      meaning: json['meaning'] as String?,
      phonetic: json['phonetic'] as String?,
      cefrLevel: json['cefr_level'] as String?,
      wordTypeLabel: json['word_type'] as String?,
      etymologyHint: json['etymology_hint'] as String?,
      memoryHook: json['memory_hook'] as String?,
    );
  }
}

// ─── Enums ────────────────────────────────────────────────

enum AiAnalysisType {
  wordLookup,    // Tra từ đơn
  sentenceAnalysis, // Phân tích câu
  shadowingContent, // Tạo nội dung shadowing
  paoGeneration,    // Tạo PAO
  error,
}

enum AiAnalysisSource {
  localDict,  // Tầng 1: offline_dictionary.dart
  cmuDict,    // Tầng 2: CMU/Wiktionary
  gemma,      // Tầng 3: Gemma Isolate
  fallback,   // Không có gì hoạt động
}
