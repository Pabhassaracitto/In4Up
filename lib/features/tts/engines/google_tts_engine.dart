// lib/features/tts/engines/google_tts_engine.dart

import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'tts_engine.dart';
import 'package:in4up/core/language/tr_extension.dart';

/// Google Translate TTS - MIỄN PHÍ
///
/// Ưu điểm:
/// - Chất lượng rất tự nhiên (giống Google Translate web)
/// - Hỗ trợ tiếng Việt rất tốt
/// - Không cần API key, không cần đăng ký
///
/// Nhược điểm:
/// - Giới hạn ~200 ký tự/request
/// - Có thể bị rate limit
/// - Cần chia nhỏ text dài
class GoogleTtsEngine extends TtsEngine {
  @override
  String get name => 'Google TTS';

  @override
  String get id => 'google_tts';

  @override
  int get maxCharsPerRequest => 200;

  @override
  List<String> get supportedLanguages => [
        'vi',
        'en',
        'ja',
        'ko',
        'zh-CN',
        'zh-TW',
        'fr',
        'de',
        'es',
        'ru',
        'th',
        'pt',
        'it',
        'id',
        'ar',
        'hi',
        'tr',
        'pl',
        'nl',
      ];

  // Google Translate TTS endpoint (miễn phí)
  static const String _baseUrl = 'https://translate.google.com/translate_tts';

  // Map ngôn ngữ
  static const Map<String, String> _langMap = {
    'vi-VN': 'vi',
    'en-US': 'en',
    'en-GB': 'en',
    'ja-JP': 'ja',
    'ko-KR': 'ko',
    'zh-CN': 'zh-CN',
    'zh-TW': 'zh-TW',
    'fr-FR': 'fr',
    'de-DE': 'de',
    'es-ES': 'es',
    'ru-RU': 'ru',
    'th-TH': 'th',
    'pt-BR': 'pt',
    'it-IT': 'it',
    'id-ID': 'id',
  };

  String _mapLang(String lang) {
    return _langMap[lang] ?? lang.split('-').first.toLowerCase();
  }

  @override
  Future<bool> isAvailable() async {
    try {
      final response = await http
          .head(Uri.parse('https://translate.google.com'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200 || response.statusCode == 302;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<TtsResult> synthesize({
    required String text,
    required String language,
    double speed = 1.0,
    double pitch = 1.0,
    String? voiceId,
  }) async {
    if (text.trim().isEmpty) {
      return TtsResult.failure(
        error: context.tr('Text trống'),
        engine: name,
      );
    }

    final stopwatch = Stopwatch()..start();

    try {
      final lang = _mapLang(language);

      // Google TTS giới hạn ~200 ký tự, cần chia nhỏ
      final chunks = _splitText(text, maxCharsPerRequest);
      final allBytes = <int>[];

      for (int i = 0; i < chunks.length; i++) {
        final chunk = chunks[i];
        if (chunk.trim().isEmpty) continue;

        // Tạo URL
        final uri = Uri.parse(_baseUrl).replace(queryParameters: {
          'ie': 'UTF-8',
          'tl': lang,
          'q': chunk,
          'client': 'tw-ob',
          // speed: Google TTS không hỗ trợ speed qua URL
          // nhưng ta sẽ xử lý bằng audio player
          'ttsspeed': speed <= 0.7 ? '0.5' : '1',
          'idx': '$i',
          'total': '${chunks.length}',
          'textlen': '${chunk.length}',
        });

        final response = await http.get(
          uri,
          headers: {
            'User-Agent': 'Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36',
            'Referer': 'https://translate.google.com/',
          },
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          allBytes.addAll(response.bodyBytes);
        } else if (response.statusCode == 429) {
          return TtsResult.failure(
            error: context.tr('Rate limited (429). Thử lại sau.'),
            engine: name,
          );
        } else {
          return TtsResult.failure(
            error: 'HTTP ${response.statusCode}',
            engine: name,
          );
        }

        // Delay nhỏ giữa các chunk
        if (i < chunks.length - 1) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }

      stopwatch.stop();

      if (allBytes.isNotEmpty) {
        return TtsResult.successBytes(
          data: Uint8List.fromList(allBytes),
          engine: name,
          responseTime: stopwatch.elapsed,
        );
      } else {
        return TtsResult.failure(
          error: 'No audio data received',
          engine: name,
        );
      }
    } catch (e) {
      stopwatch.stop();
      return TtsResult.failure(
        error: e.toString(),
        engine: name,
      );
    }
  }

  @override
  Future<List<TtsVoice>> getAvailableVoices(String language) async {
    // Google Translate TTS chỉ có 1 giọng mỗi ngôn ngữ
    final lang = _mapLang(language);
    return [
      TtsVoice(
        id: 'google_$lang',
        name: 'Google ${_getLanguageName(lang)}',
        language: language,
        gender: 'female', // Mặc định là giọng nữ
        engine: name,
        isNeural: false,
      ),
    ];
  }

  /// Chia text thành chunks nhỏ, cắt theo câu/dấu phẩy
  List<String> _splitText(String text, int maxLen) {
    if (text.length <= maxLen) return [text];

    final chunks = <String>[];
    final sentences = text.split(RegExp(r'(?<=[.!?;:,\n])\s*'));
    var current = StringBuffer();

    for (final sentence in sentences) {
      if (current.length + sentence.length + 1 > maxLen) {
        if (current.isNotEmpty) {
          chunks.add(current.toString().trim());
          current = StringBuffer();
        }
        // Nếu 1 câu dài hơn maxLen, cắt cứng
        if (sentence.length > maxLen) {
          for (int i = 0; i < sentence.length; i += maxLen) {
            final end = (i + maxLen).clamp(0, sentence.length);
            chunks.add(sentence.substring(i, end));
          }
        } else {
          current.write(sentence);
        }
      } else {
        if (current.isNotEmpty) current.write(' ');
        current.write(sentence);
      }
    }

    if (current.isNotEmpty) {
      chunks.add(current.toString().trim());
    }

    return chunks.where((c) => c.trim().isNotEmpty).toList();
  }

  String _getLanguageName(String code) {
    const names = {
      'vi': 'Content',
      'en': 'English',
      'ja': 'Japanese',
      'ko': 'Korean',
      'zh-CN': 'Chinese',
      'fr': 'French',
      'de': 'German',
      'es': 'Spanish',
    };
    return names[code] ?? code;
  }
}