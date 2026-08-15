// lib/features/tts/engines/fpt_tts_engine.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'tts_engine.dart';
import 'package:in4up/core/language/tr_extension.dart';

/// FPT.AI Text-to-Speech
///
/// ✅ MIỄN PHÍ: Đăng ký tại https://fpt.ai/ → lấy API key miễn phí
///    - Free tier: ~50,000 ký tự/tháng (đủ dùng)
///    - Không cần thẻ tín dụng
///    - Chỉ cần email
///
/// Giọng tiếng Việt RẤT TỰ NHIÊN:
///   - banmai (Nữ miền Bắc - tự nhiên nhất)
///   - linhsan (Nữ miền Bắc)
///   - leminh (Nam miền Bắc)
///   - myan (Nữ miền Trung)
///   - thuminh (Nữ miền Nam)
///   - giahuy (Nam miền Trung)
class FptTtsEngine extends TtsEngine {
  /// API key miễn phí từ fpt.ai
  /// Đăng ký: https://fpt.ai/tts → Lấy key → Paste vào đây
  String? apiKey;

  FptTtsEngine({this.apiKey});

  @override
  String get name => 'FPT.AI TTS';

  @override
  String get id => 'fpt_tts';

  @override
  int get maxCharsPerRequest => 10000; // FPT cho phép text dài

  @override
  List<String> get supportedLanguages => ['vi-VN', 'vi'];

  static const String _baseUrl = 'https://api.fpt.ai/hmi/tts/v5';

  // Danh sách giọng FPT
  static const Map<String, TtsVoice> _voices = {
    'banmai': TtsVoice(
      id: 'banmai',
      name: 'Ban Mai',
      language: 'vi-VN',
      gender: 'female',
      engine: 'FPT.AI',
      isNeural: true,
    ),
    'linhsan': TtsVoice(
      id: 'linhsan',
      name: 'Linh San',
      language: 'vi-VN',
      gender: 'female',
      engine: 'FPT.AI',
      isNeural: true,
    ),
    'leminh': TtsVoice(
      id: 'leminh',
      name: 'Content',
      language: 'vi-VN',
      gender: 'male',
      engine: 'FPT.AI',
      isNeural: true,
    ),
    'myan': TtsVoice(
      id: 'myan',
      name: 'Content',
      language: 'vi-VN',
      gender: 'female',
      engine: 'FPT.AI',
      isNeural: true,
    ),
    'thuminh': TtsVoice(
      id: 'thuminh',
      name: 'Content',
      language: 'vi-VN',
      gender: 'female',
      engine: 'FPT.AI',
      isNeural: true,
    ),
    'giahuy': TtsVoice(
      id: 'giahuy',
      name: 'Content',
      language: 'vi-VN',
      gender: 'male',
      engine: 'FPT.AI',
      isNeural: true,
    ),
  };

  @override
  Future<bool> isAvailable() async {
    // Chỉ khả dụng khi có API key
    if (apiKey == null || apiKey!.isEmpty) return false;

    try {
      final response = await http
          .get(Uri.parse('https://api.fpt.ai'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode < 500;
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
    if (apiKey == null || apiKey!.isEmpty) {
      return TtsResult.failure(
        error: context.tr('Chưa có FPT API key. Đăng ký miễn phí tại fpt.ai'),
        engine: name,
      );
    }

    // FPT chỉ hỗ trợ tiếng Việt
    if (!language.toLowerCase().startsWith('vi')) {
      return TtsResult.failure(
        error: context.tr('FPT.AI chỉ hỗ trợ tiếng Việt'),
        engine: name,
      );
    }

    if (text.trim().isEmpty) {
      return TtsResult.failure(
        error: context.tr('Text trống'),
        engine: name,
      );
    }

    final stopwatch = Stopwatch()..start();

    try {
      final voice = voiceId ?? 'banmai'; // Mặc định giọng nữ miền Bắc

      // FPT speed: -3 đến 3 (0 = bình thường)
      // Map: 0.5 → -2, 1.0 → 0, 2.0 → 3
      final fptSpeed = ((speed - 1.0) * 3).round().clamp(-3, 3).toString();

      final response = await http
          .post(
            Uri.parse(_baseUrl),
            headers: {
              'api-key': apiKey!,
              'Content-Type':
                  'application/x-www-form-urlencoded; charset=utf-8',
              'voice': voice,
              'speed': fptSpeed,
            },
            body: text,
          )
          .timeout(const Duration(seconds: 15));

      stopwatch.stop();

      if (response.statusCode == 200) {
        // FPT trả về JSON với URL audio
        // {"async": "...", "error": 0, "message": "...", "request_id": "..."}
        final body = response.body;

        // Kiểm tra nếu response là audio trực tiếp
        final contentType = response.headers['content-type'] ?? '';
        if (contentType.contains('audio')) {
          return TtsResult.successBytes(
            data: response.bodyBytes,
            engine: name,
            responseTime: stopwatch.elapsed,
          );
        }

        // Nếu là JSON, lấy URL audio
        try {
          final data = _parseJson(body);
          final audioUrl = data['async'] as String?;

          if (audioUrl != null && audioUrl.isNotEmpty) {
            // Tải audio từ URL
            await Future.delayed(const Duration(milliseconds: 500));

            final audioResponse = await http
                .get(Uri.parse(audioUrl))
                .timeout(const Duration(seconds: 15));

            if (audioResponse.statusCode == 200) {
              return TtsResult.successBytes(
                data: audioResponse.bodyBytes,
                engine: '$name ($voice)',
                responseTime: stopwatch.elapsed,
              );
            }

            // Nếu chưa sẵn sàng, trả URL để stream
            return TtsResult.successUrl(
              url: audioUrl,
              engine: '$name ($voice)',
              responseTime: stopwatch.elapsed,
            );
          }

          final error = data['message'] as String? ?? 'Unknown error';
          return TtsResult.failure(error: error, engine: name);
        } catch (e) {
          return TtsResult.failure(
            error: 'Parse error: $e',
            engine: name,
          );
        }
      } else if (response.statusCode == 401) {
        return TtsResult.failure(
          error: context.tr('API key không hợp lệ'),
          engine: name,
        );
      } else if (response.statusCode == 429) {
        return TtsResult.failure(
          error: context.tr('Hết quota tháng này'),
          engine: name,
        );
      } else {
        return TtsResult.failure(
          error: 'HTTP ${response.statusCode}: ${response.body}',
          engine: name,
        );
      }
    } catch (e) {
      stopwatch.stop();
      return TtsResult.failure(error: e.toString(), engine: name);
    }
  }

  @override
  Future<List<TtsVoice>> getAvailableVoices(String language) async {
    if (!language.toLowerCase().startsWith('vi')) return [];
    return _voices.values.toList();
  }

  Map<String, dynamic> _parseJson(String body) {
    // Simple JSON parse
    return jsonDecode(body) as Map<String, dynamic>;
  }
}