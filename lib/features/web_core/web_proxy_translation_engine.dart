import 'dart:convert';

import 'package:http/http.dart' as http;

import '../translation/engines/google_free_engine.dart';
import '../translation/engines/translation_engine.dart';
import 'web_proxy_config.dart';

/// Browser-safe translation engine.
///
/// Production builds use the controlled proxy configured with
/// `IN4UP_WEB_PROXY_BASE_URL`. A direct CORS call is available only when the
/// explicit development flag `IN4UP_ALLOW_DIRECT_CORS=true` is supplied.
class WebProxyTranslationEngine extends TranslationEngine {
  WebProxyTranslationEngine({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  String get name => 'Web proxy';

  @override
  String get id => 'web_proxy';

  @override
  int get maxCharsPerRequest => 5000;

  @override
  Duration get requestDelay => const Duration(milliseconds: 250);

  @override
  Future<bool> isAvailable() async {
    final endpoint = WebProxyConfig.endpoint('/health');
    if (endpoint == null) return WebProxyConfig.allowDirectCors;

    try {
      final response = await _client
          .get(endpoint)
          .timeout(const Duration(seconds: 4));
      return response.statusCode >= 200 && response.statusCode < 300;
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
    final original = text.trim();
    if (original.isEmpty) {
      return TranslationResult.success(
        original: text,
        translated: '',
        engine: name,
        targetLang: targetLang,
      );
    }

    if (original.length > maxCharsPerRequest) {
      return TranslationResult.failure(
        original: text,
        error: 'Đoạn dịch quá dài (tối đa $maxCharsPerRequest ký tự).',
        engine: name,
        targetLang: targetLang,
      );
    }

    final endpoint = WebProxyConfig.endpoint('/translate');
    if (endpoint == null) {
      if (WebProxyConfig.allowDirectCors) {
        return GoogleFreeEngine(client: _client).translate(
          text: original,
          targetLang: targetLang,
          sourceLang: sourceLang,
        );
      }
      return TranslationResult.failure(
        original: text,
        error: 'Web chưa được cấu hình translation proxy.',
        engine: name,
        targetLang: targetLang,
      );
    }

    final stopwatch = Stopwatch()..start();
    try {
      final response = await _client
          .post(
            endpoint,
            headers: const {'content-type': 'application/json'},
            body: jsonEncode({
              'text': original,
              'sourceLang': sourceLang,
              'targetLang': targetLang,
            }),
          )
          .timeout(const Duration(seconds: 12));
      stopwatch.stop();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return TranslationResult.failure(
          original: text,
          error: 'Translation proxy HTTP ${response.statusCode}.',
          engine: name,
          targetLang: targetLang,
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        return TranslationResult.failure(
          original: text,
          error: 'Translation proxy trả về dữ liệu không hợp lệ.',
          engine: name,
          targetLang: targetLang,
        );
      }

      final translated = (decoded['translatedText'] ?? decoded['translation'])
          ?.toString()
          .trim();
      if (translated == null || translated.isEmpty) {
        return TranslationResult.failure(
          original: text,
          error: 'Translation proxy không có bản dịch.',
          engine: name,
          targetLang: targetLang,
        );
      }

      return TranslationResult.success(
        original: text,
        translated: translated,
        engine: name,
        detectedLang: decoded['detectedLang']?.toString(),
        targetLang: targetLang,
        responseTime: stopwatch.elapsed,
      );
    } catch (error) {
      stopwatch.stop();
      return TranslationResult.failure(
        original: text,
        error: 'Không kết nối được translation proxy: $error',
        engine: name,
        targetLang: targetLang,
      );
    }
  }
}
