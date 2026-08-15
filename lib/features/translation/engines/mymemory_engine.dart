// lib/features/translation/engines/mymemory_engine.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'translation_engine.dart';
import 'package:in4up/core/language/tr_extension.dart';

/// MyMemory Translation API
/// ✅ Miễn phí 5000 chars/ngày (anonymous)
/// ✅ Không cần API key, không cần đăng ký
class MyMemoryEngine extends TranslationEngine {
  @override
  String get name => 'MyMemory';

  @override
  String get id => 'mymemory';

  @override
  int get maxCharsPerRequest => 500; // MyMemory giới hạn 500 chars/request

  @override
  Duration get requestDelay => const Duration(milliseconds: 500);

  static const String _baseUrl = 'https://api.mymemory.translated.net/get';

  static const Map<String, String> _langMap = {
    'AR': 'ar',
    'BN': 'bn',
    'BO': 'bo',
    'DE': 'de',
    'EN': 'en',
    'ES': 'es',
    'FR': 'fr',
    'HI': 'hi',
    'ID': 'id',
    'IT': 'it',
    'JA': 'ja',
    'KM': 'km',
    'KO': 'ko',
    'LO': 'lo',
    'MN': 'mn',
    'MR': 'mr',
    'MY': 'my',
    'PT': 'pt',
    'RU': 'ru',
    'SI': 'si',
    'TA': 'ta',
    'TE': 'te',
    'TH': 'th',
    'VI': 'vi',
    'ZH': 'zh-CN',
    'ZH-CN': 'zh-CN',
    'ZH-TW': 'zh-TW',
    'AUTO': 'en',
  };

  String _mapLang(String lang) {
    return _langMap[lang.toUpperCase()] ?? lang.toLowerCase();
  }

  @override
  Future<bool> isAvailable() async {
    try {
      final response = await http
          .get(Uri.parse('https://api.mymemory.translated.net'))
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

      // MyMemory dùng format: en|vi
      final langPair = '$sl|$tl';

      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'q': text,
        'langpair': langPair,
      });

      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      stopwatch.stop();

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final responseData = data['responseData'];

        if (responseData == null) {
          return TranslationResult.failure(
            original: text,
            error: 'Invalid response format',
            engine: name,
          );
        }

        final translated = responseData['translatedText'] as String? ?? '';
        final match = (responseData['match'] as num?)?.toDouble() ?? 0.0;

        // Bỏ qua nếu chất lượng quá thấp
        if (match < 0.3 && translated.isNotEmpty) {
          debugPrint('MyMemory: Low quality match ($match) for: $text');
        }

        // Check quota exceeded
        if (translated.contains('MYMEMORY WARNING') ||
            translated.contains('PLEASE CONTACT')) {
          return TranslationResult.failure(
            original: text,
            error: context.tr('MyMemory: Hết quota hôm nay (5000 chars/ngày)'),
            engine: name,
          );
        }

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
            error: 'Empty translation',
            engine: name,
          );
        }
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
}