// lib/features/translation/engines/deeplx_engine.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'translation_engine.dart';

/// DeepLX Engine - Wrap lại service cũ
/// Cần self-host hoặc dùng public instance
class DeepLXEngine extends TranslationEngine {
  String serverUrl;

  DeepLXEngine({
    this.serverUrl = 'http://localhost:1188/translate',
  });

  @override
  String get name => 'DeepLX';

  @override
  String get id => 'deeplx';

  @override
  int get maxCharsPerRequest => 5000;

  @override
  Duration get requestDelay => const Duration(milliseconds: 50);

  @override
  Future<bool> isAvailable() async {
    try {
      final baseUrl = serverUrl.replaceAll('/translate', '');
      final response = await http
          .get(Uri.parse(baseUrl))
          .timeout(const Duration(seconds: 3));
      return response.statusCode == 200 || response.statusCode == 404;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<TranslationResult> translate({
    required String text,
    required String targetLang,
    String sourceLang = 'auto',
  }) async {
    if (text.trim().isEmpty) {
      return TranslationResult.success(
        original: text,
        translated: '',
        engine: name,
      );
    }

    final stopwatch = Stopwatch()..start();

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
          .timeout(const Duration(seconds: 10));

      stopwatch.stop();

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final translated = data['data'] as String? ?? '';

        if (translated.isNotEmpty) {
          return TranslationResult.success(
            original: text,
            translated: translated,
            engine: name,
            responseTime: stopwatch.elapsed,
          );
        } else {
          return TranslationResult.failure(
            original: text,
            error: 'Empty response from DeepLX',
            engine: name,
          );
        }
      } else {
        return TranslationResult.failure(
          original: text,
          error: 'HTTP ${response.statusCode}: ${response.body}',
          engine: name,
        );
      }
    } catch (e) {
      stopwatch.stop();
      return TranslationResult.failure(
        original: text,
        error: e.toString(),
        engine: name,
      );
    }
  }
}
