import 'dart:convert';
import '../models/ai_analysis.dart';

/// Parse JSON output của Gemma → AiAnalysis
/// KHÔNG throw exception ra ngoài - luôn trả về object hợp lệ
class AiModelMapper {
  
  static AiAnalysis parse({
    required String rawOutput,
    required String inputText,
    required AiAnalysisType type,
  }) {
    // Bước 1: Trích xuất JSON từ output (Gemma hay thêm text thừa)
    final jsonString = _extractJson(rawOutput);
    if (jsonString == null) {
      return AiAnalysis.fallback(
        inputText,
        errorReason: 'No valid JSON in output',
      );
    }

    // Bước 2: Parse JSON
    Map<String, dynamic> jsonMap;
    try {
      jsonMap = json.decode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      return AiAnalysis.fallback(
        inputText,
        errorReason: 'JSON parse error: $e',
      );
    }

    // Bước 3: Validate schema tối thiểu
    if (!_validateMinimalSchema(jsonMap)) {
      return AiAnalysis.fallback(
        inputText,
        errorReason: 'Schema validation failed',
      );
    }

    // Bước 4: Map sang AiAnalysis
    try {
      return AiAnalysis.fromJson(jsonMap, inputText);
    } catch (e) {
      return AiAnalysis.fallback(
        inputText,
        errorReason: 'Mapping error: $e',
      );
    }
  }

  /// Trích xuất JSON từ output có thể có text thừa
  /// Gemma thường output: "Here is the analysis: {...}"
  static String? _extractJson(String raw) {
    // Tìm cặp {} đầu tiên
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    
    if (start == -1 || end == -1 || end <= start) return null;
    
    return raw.substring(start, end + 1);
  }

  /// Validate schema tối thiểu - chỉ cần có ít nhất 1 field hữu ích
  static bool _validateMinimalSchema(Map<String, dynamic> json) {
    return json.containsKey('word_detail') ||
        json.containsKey('grammar') ||
        json.containsKey('visual_prompt') ||
        json.containsKey('pao_suggestions') ||
        json.containsKey('summary') ||
        json.containsKey('action_items');
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
