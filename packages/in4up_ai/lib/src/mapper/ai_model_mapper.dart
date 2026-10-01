import '../models/ai_analysis.dart';

/// Parse JSON output của Gemma → AiAnalysis
/// KHÔNG throw exception ra ngoài - luôn trả về object hợp lệ
class AiModelMapper {
  static AiAnalysis parse({
    required String rawOutput,
    required String inputText,
    required AiAnalysisType type,
  }) {
    // Dùng chung parser phòng thủ của AiAnalysis để local Gemma, remote LLM
    // và callers legacy đều xử lý được markdown fence / prose quanh JSON /
    // JSON bị cắt. Khi không cứu được, parser trả lỗi rõ (summary +
    // errorReason) thay vì object rỗng.
    return AiAnalysis.fromGemmaJson(
      rawOutput,
      inputText: inputText,
      analysisType: type,
    );
  }

  /// Map wordType string → WordType enum (tương thích word_analysis.dart)
  static String mapWordType(String? raw) {
    const mapping = {
      'noun': 'noun',
      'verb': 'verb',
      'adjective': 'adjective',
      'adverb': 'adverb',
      'preposition': 'preposition',
      'conjunction': 'conjunction',
      'pronoun': 'pronoun',
      'determiner': 'determiner',
      'n': 'noun',
      'v': 'verb',
      'adj': 'adjective',
      'adv': 'adverb',
    };
    return mapping[raw?.toLowerCase()] ?? 'unknown';
  }
}
