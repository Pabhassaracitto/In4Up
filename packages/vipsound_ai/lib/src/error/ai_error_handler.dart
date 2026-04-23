import '../models/ai_analysis.dart';
import '../engine/ai_engine.dart';

/// Chiến lược xử lý lỗi và retry
class AiErrorHandler {

  /// Retry với temperature thấp hơn khi detect hallucination
  static double getRetryTemperature(int attemptCount) {
    switch (attemptCount) {
      case 1: return 0.1;   // Lần 1: standard
      case 2: return 0.05;  // Lần 2: conservative
      case 3: return 0.01;  // Lần 3: almost deterministic
      default: return 0.0;
    }
  }

  /// Detect các dấu hiệu hallucination trong output
  static HallucinationCheck checkForHallucination(AiAnalysis analysis) {
    final issues = <String>[];

    // Kiểm tra IPA format
    if (analysis.ipaFallback != null) {
      if (!_isValidIpaFormat(analysis.ipaFallback!)) {
        issues.add('Invalid IPA format: ${analysis.ipaFallback}');
      }
    }

    // Kiểm tra CEFR level hợp lệ
    if (analysis.wordDetail?.cefrLevel != null) {
      const validLevels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
      if (!validLevels.contains(analysis.wordDetail!.cefrLevel)) {
        issues.add('Invalid CEFR: ${analysis.wordDetail!.cefrLevel}');
      }
    }

    // Kiểm tra PAO suggestions không rỗng/lặp
    if (analysis.paoSuggestions.length > 1) {
      final unique = analysis.paoSuggestions.toSet();
      if (unique.length < analysis.paoSuggestions.length) {
        issues.add('Duplicate PAO suggestions detected');
      }
    }

    return HallucinationCheck(
      isClean: issues.isEmpty,
      issues: issues,
    );
  }

  static bool _isValidIpaFormat(String ipa) {
    // IPA phải bắt đầu bằng / và kết thúc bằng /
    return ipa.startsWith('/') && ipa.endsWith('/') && ipa.length > 2;
  }

  /// Log lỗi để thu thập data fine-tune prompt
  /// Lưu vào error_log (xử lý bởi vipsound_storage, không phải ở đây)
  static ErrorLogEntry createErrorLog({
    required String inputText,
    required String rawAiOutput,
    required List<String> issues,
  }) {
    return ErrorLogEntry(
      inputText: inputText,
      rawOutput: rawAiOutput,
      issues: issues,
      timestamp: DateTime.now(),
    );
  }
}

class HallucinationCheck {
  final bool isClean;
  final List<String> issues;
  const HallucinationCheck({required this.isClean, required this.issues});
}

class ErrorLogEntry {
  final String inputText;
  final String rawOutput;
  final List<String> issues;
  final DateTime timestamp;
  
  const ErrorLogEntry({
    required this.inputText,
    required this.rawOutput,
    required this.issues,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'input': inputText,
    'raw_output': rawOutput,
    'issues': issues,
    'timestamp': timestamp.toIso8601String(),
  };
}
