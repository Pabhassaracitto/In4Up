// lib/features/deeplx/services/deeplx_service.dart
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Kết quả dịch một dòng
class TranslationResult {
  final String originalText;
  final String translatedText;
  final bool isSuccess;
  final String? error;

  const TranslationResult({
    required this.originalText,
    required this.translatedText,
    required this.isSuccess,
    this.error,
  });

  factory TranslationResult.error(String original, String error) {
    return TranslationResult(
      originalText: original,
      translatedText: '',
      isSuccess: false,
      error: error,
    );
  }
}

class DeepLXService {
  /// URL của DeepLX server
  /// Mặc định: 'http://localhost:1188/translate' (nếu chạy local)
  /// Hoặc dùng các free instance public (không ổn định): 'https://api.deeplx.org/translate'
  static String serverUrl = 'http://localhost:1188/translate';

  /// Ngôn ngữ nguồn (auto = tự detect)
  static String sourceLang = 'auto';

  /// Ngôn ngữ đích
  static String targetLang = 'VI';

  /// Timeout mỗi request
  static const Duration _timeout = Duration(seconds: 10);

  // --------------------------------------------------------------------------
  // TRANSLATE SINGLE
  // --------------------------------------------------------------------------

  /// Dịch một đoạn văn bản
  static Future<TranslationResult> translateText(String text) async {
    if (text.trim().isEmpty) {
      return TranslationResult(
        originalText: text,
        translatedText: '',
        isSuccess: true,
      );
    }

    try {
      final response = await http
          .post(
            Uri.parse(serverUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'text': text,
              'source_lang': sourceLang,
              'target_lang': targetLang,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        // DeepLX response format: {"code": 200, "data": "translated text", ...}
        final translated = data['data'] as String? ?? '';
        return TranslationResult(
          originalText: text,
          translatedText: translated,
          isSuccess: translated.isNotEmpty,
          error: translated.isEmpty ? 'Empty response' : null,
        );
      } else {
        return TranslationResult.error(
          text,
          'HTTP ${response.statusCode}: ${response.body}',
        );
      }
    } on Exception catch (e) {
      return TranslationResult.error(
          text, 'Lỗi kết nối: $e. Kiểm tra Server URL.');
    }
  }

  // --------------------------------------------------------------------------
  // TRANSLATE BATCH
  // --------------------------------------------------------------------------

  /// Dịch nhiều dòng cùng lúc, gọi tuần tự để tránh rate limit.
  static Future<List<TranslationResult>> translateBatch(
    List<String> texts, {
    void Function(int done, int total)? onProgress,
    int delayMs = 100,
  }) async {
    final results = <TranslationResult>[];

    for (int i = 0; i < texts.length; i++) {
      final result = await translateText(texts[i]);
      results.add(result);
      onProgress?.call(i + 1, texts.length);

      if (i < texts.length - 1 && delayMs > 0) {
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }

    return results;
  }

  // --------------------------------------------------------------------------
  // HELPERS
  // --------------------------------------------------------------------------

  static Future<bool> checkHealth() async {
    try {
      // Simple check by calling root or a known endpoint
      final response = await http
          .get(
            Uri.parse(serverUrl.replaceAll('/translate', '')),
          )
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200 || response.statusCode == 404;
    } catch (_) {
      return false;
    }
  }

  static void configure({
    String? url,
    String? source,
    String? target,
  }) {
    if (url != null) serverUrl = url;
    if (source != null) sourceLang = source;
    if (target != null) targetLang = target;
  }
}
