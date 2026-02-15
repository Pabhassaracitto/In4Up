// lib/features/translation/engines/google_free_engine.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'translation_engine.dart';

class GoogleFreeEngine extends TranslationEngine {
  @override
  String get name => 'Google Translate';

  @override
  String get id => 'google_free';

  @override
  int get maxCharsPerRequest => 5000;

  @override
  Duration get requestDelay => const Duration(milliseconds: 300);

  // Dùng endpoint miễn phí - KHÔNG cần API key
  static const String _baseUrl =
      'https://translate.googleapis.com/translate_a/single';

  // Map ngôn ngữ DeepL format → Google format
  static const Map<String, String> _langMap = {
    'VI': 'vi',
    'EN': 'en',
    'ZH': 'zh-cn',
    'JA': 'ja',
    'KO': 'ko',
    'FR': 'fr',
    'DE': 'de',
    'ES': 'es',
    'RU': 'ru',
    'TH': 'th',
    'PT': 'pt',
    'IT': 'it',
    'AR': 'ar',
    'HI': 'hi',
    'AUTO': 'auto',
  };

  String _mapLang(String lang) {
    return _langMap[lang.toUpperCase()] ?? lang.toLowerCase();
  }

  @override
  Future<bool> isAvailable() async {
    try {
      final response = await http
          .get(Uri.parse('https://translate.googleapis.com'))
          .timeout(const Duration(seconds: 5));
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
      final sl = _mapLang(sourceLang);
      final tl = _mapLang(targetLang);

      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'client': 'gtx',
        'sl': sl,
        'tl': tl,
        'dt': 't', // Chỉ lấy bản dịch
        'q': text,
      });

      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36',
        },
      ).timeout(const Duration(seconds: 8));

      stopwatch.stop();

      if (response.statusCode == 200) {
        final translated = _parseResponse(
          utf8.decode(response.bodyBytes),
        );
        final detectedLang = _parseDetectedLang(
          utf8.decode(response.bodyBytes),
        );

        if (translated.isNotEmpty) {
          return TranslationResult.success(
            original: text,
            translated: translated,
            engine: name,
            detectedLang: detectedLang,
            responseTime: stopwatch.elapsed,
          );
        } else {
          return TranslationResult.failure(
            original: text,
            error: 'Empty response from Google',
            engine: name,
          );
        }
      } else if (response.statusCode == 429) {
        return TranslationResult.failure(
          original: text,
          error: 'Rate limited (429). Thử lại sau 30s.',
          engine: name,
        );
      } else {
        return TranslationResult.failure(
          original: text,
          error: 'HTTP ${response.statusCode}',
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

  /// Parse Google Translate response
  /// Format: [[["translated","original",null,null,10]],null,"en"]
  String _parseResponse(String jsonStr) {
    try {
      final List<dynamic> json = jsonDecode(jsonStr);
      final List<dynamic> translations = json[0];

      final buffer = StringBuffer();
      for (final t in translations) {
        if (t is List && t.isNotEmpty && t[0] is String) {
          buffer.write(t[0]);
        }
      }
      return buffer.toString();
    } catch (e) {
      debugPrint('Google parse error: $e');
      return '';
    }
  }

  String? _parseDetectedLang(String jsonStr) {
    try {
      final List<dynamic> json = jsonDecode(jsonStr);
      if (json.length > 2 && json[2] is String) {
        return json[2];
      }
    } catch (_) {}
    return null;
  }
}
