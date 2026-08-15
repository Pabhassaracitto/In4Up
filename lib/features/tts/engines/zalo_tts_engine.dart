// lib/features/tts/engines/zalo_tts_engine.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'tts_engine.dart';
import 'package:in4up/core/language/tr_extension.dart';

/// Zalo AI Text-to-Speech
///
/// ✅ MIỄN PHÍ: Đăng ký tại https://zalo.ai/
///    - Free tier: 50 request/giờ (đủ dùng cá nhân)
///    - Không cần thẻ tín dụng
///    - Chỉ cần tài khoản Zalo
///
/// Đăng ký lấy API key:
///   1. Vào https://zalo.ai/
///   2. Đăng nhập bằng tài khoản Zalo
///   3. Vào Console → Text to Speech
///   4. Tạo ứng dụng → Copy API Key
///
/// Giọng tiếng Việt CỰC TỰ NHIÊN:
///   - 1: Nữ miền Bắc (giọng chuẩn, rõ ràng)
///   - 2: Nam miền Bắc
///   - 3: Nữ miền Trung
///   - 4: Nam miền Trung
///   - 5: Nữ miền Nam (nhẹ nhàng)
///   - 6: Nam miền Nam
///   - 7: Nữ miền Bắc (trẻ trung)
///   - 8: Nam miền Bắc (trầm)
class ZaloTtsEngine extends TtsEngine {
  /// API key từ zalo.ai
  String? apiKey;

  ZaloTtsEngine({this.apiKey});

  @override
  String get name => 'Zalo AI TTS';

  @override
  String get id => 'zalo_tts';

  @override
  int get maxCharsPerRequest => 2000;

  @override
  List<String> get supportedLanguages => ['vi-VN', 'vi'];

  // Zalo TTS API endpoint
  static const String _baseUrl = 'https://api.zalo.ai/v1/tts/synthesize';

  // Danh sách giọng Zalo
  static const List<TtsVoice> _voices = [
    TtsVoice(
      id: '1',
      name: 'Content',
      language: 'vi-VN',
      gender: 'female',
      engine: 'Zalo AI',
      isNeural: true,
    ),
    TtsVoice(
      id: '2',
      name: 'Content',
      language: 'vi-VN',
      gender: 'male',
      engine: 'Zalo AI',
      isNeural: true,
    ),
    TtsVoice(
      id: '3',
      name: 'Content',
      language: 'vi-VN',
      gender: 'female',
      engine: 'Zalo AI',
      isNeural: true,
    ),
    TtsVoice(
      id: '4',
      name: 'Content',
      language: 'vi-VN',
      gender: 'male',
      engine: 'Zalo AI',
      isNeural: true,
    ),
    TtsVoice(
      id: '5',
      name: 'Content',
      language: 'vi-VN',
      gender: 'female',
      engine: 'Zalo AI',
      isNeural: true,
    ),
    TtsVoice(
      id: '6',
      name: 'Content',
      language: 'vi-VN',
      gender: 'male',
      engine: 'Zalo AI',
      isNeural: true,
    ),
    TtsVoice(
      id: '7',
      name: 'Content',
      language: 'vi-VN',
      gender: 'female',
      engine: 'Zalo AI',
      isNeural: true,
    ),
    TtsVoice(
      id: '8',
      name: 'Content',
      language: 'vi-VN',
      gender: 'male',
      engine: 'Zalo AI',
      isNeural: true,
    ),
  ];

  @override
  Future<bool> isAvailable() async {
    if (apiKey == null || apiKey!.isEmpty) return false;

    try {
      final response = await http.get(
        Uri.parse('https://api.zalo.ai'),
        headers: {'apikey': apiKey!},
      ).timeout(const Duration(seconds: 5));
      // Zalo trả 200 hoặc 401/403, miễn là server sống
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
        error: context.tr('Chưa có Zalo API key. Đăng ký miễn phí tại zalo.ai'),
        engine: name,
      );
    }

    // Zalo chỉ hỗ trợ tiếng Việt
    if (!language.toLowerCase().startsWith('vi')) {
      return TtsResult.failure(
        error: context.tr('Zalo AI chỉ hỗ trợ tiếng Việt'),
        engine: name,
      );
    }

    if (text.trim().isEmpty) {
      return TtsResult.failure(error: context.tr('Text trống'), engine: name);
    }

    final stopwatch = Stopwatch()..start();

    try {
      final speakerId = voiceId ?? '1'; // Mặc định: Nữ miền Bắc

      // Zalo speed: 0.5 - 2.0 (1.0 = bình thường)
      final zaloSpeed = speed.clamp(0.5, 2.0);

      // Chia nhỏ text nếu quá dài
      final chunks = _splitText(text, maxCharsPerRequest);
      final allBytes = <int>[];

      for (int i = 0; i < chunks.length; i++) {
        final chunk = chunks[i];
        if (chunk.trim().isEmpty) continue;

        final response = await http.post(
          Uri.parse(_baseUrl),
          headers: {
            'apikey': apiKey!,
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: {
            'input': chunk,
            'speaker_id': speakerId,
            'speed': zaloSpeed.toString(),
            'quality': '1', // 0: thường, 1: cao
          },
        ).timeout(const Duration(seconds: 15));

        stopwatch.stop();

        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          final errorCode = data['error_code'] as int? ?? -1;
          final errorMsg = data['error_message'] as String? ?? '';

          if (errorCode == 0) {
            // Thành công - lấy URL audio
            final audioUrl = data['data']?['url'] as String?;

            if (audioUrl != null && audioUrl.isNotEmpty) {
              // Tải audio bytes
              final audioBytes = await _downloadAudio(audioUrl);

              if (audioBytes != null && audioBytes.isNotEmpty) {
                allBytes.addAll(audioBytes);
              } else {
                // Không tải được bytes, trả URL
                if (chunks.length == 1) {
                  return TtsResult.successUrl(
                    url: audioUrl,
                    engine: '$name (speaker $speakerId)',
                    responseTime: stopwatch.elapsed,
                  );
                }
              }
            } else {
              return TtsResult.failure(
                error: context.tr('Không có audio URL trong response'),
                engine: name,
              );
            }
          } else if (errorCode == 107) {
            return TtsResult.failure(
              error: context.tr('Hết quota Zalo (50 req/giờ). Thử lại sau.'),
              engine: name,
            );
          } else if (errorCode == 104) {
            return TtsResult.failure(
              error: context.tr('API key Zalo không hợp lệ'),
              engine: name,
            );
          } else {
            return TtsResult.failure(
              error: 'Zalo error $errorCode: $errorMsg',
              engine: name,
            );
          }
        } else {
          return TtsResult.failure(
            error: 'HTTP ${response.statusCode}',
            engine: name,
          );
        }

        // Delay giữa chunks
        if (i < chunks.length - 1) {
          await Future.delayed(const Duration(milliseconds: 200));
        }
      }

      if (allBytes.isNotEmpty) {
        return TtsResult.successBytes(
          data: Uint8List.fromList(allBytes),
          engine: '$name (speaker $speakerId)',
          responseTime: stopwatch.elapsed,
        );
      }

      return TtsResult.failure(
        error: context.tr('Không nhận được audio data'),
        engine: name,
      );
    } catch (e) {
      stopwatch.stop();
      return TtsResult.failure(error: e.toString(), engine: name);
    }
  }

  /// Tải audio từ URL
  Future<Uint8List?> _downloadAudio(String url) async {
    // Retry tải audio (Zalo cần thời gian tạo)
    for (int retry = 0; retry < 3; retry++) {
      try {
        final response =
            await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200 && response.bodyBytes.length > 500) {
          return response.bodyBytes;
        }
      } catch (e) {
        debugPrint('Zalo download retry $retry: $e');
      }

      // Chờ trước khi retry
      await Future.delayed(Duration(milliseconds: 500 * (retry + 1)));
    }
    return null;
  }

  /// Chia text thành chunks nhỏ
  List<String> _splitText(String text, int maxLen) {
    if (text.length <= maxLen) return [text];

    final chunks = <String>[];

    // Chia theo câu (dấu chấm, chấm hỏi, chấm than, xuống dòng)
    final sentences = text.split(RegExp(r'(?<=[.!?\n])\s*'));
    final buffer = StringBuffer();

    for (final sentence in sentences) {
      if (buffer.length + sentence.length + 1 > maxLen) {
        if (buffer.isNotEmpty) {
          chunks.add(buffer.toString().trim());
          buffer.clear();
        }

        // Câu đơn dài hơn maxLen → cắt theo dấu phẩy
        if (sentence.length > maxLen) {
          final subParts = sentence.split(RegExp(r'(?<=[,;:])\s*'));
          final subBuffer = StringBuffer();

          for (final part in subParts) {
            if (subBuffer.length + part.length + 1 > maxLen) {
              if (subBuffer.isNotEmpty) {
                chunks.add(subBuffer.toString().trim());
                subBuffer.clear();
              }
              // Vẫn quá dài → cắt cứng
              if (part.length > maxLen) {
                for (int i = 0; i < part.length; i += maxLen) {
                  final end = (i + maxLen).clamp(0, part.length);
                  chunks.add(part.substring(i, end));
                }
              } else {
                subBuffer.write(part);
              }
            } else {
              if (subBuffer.isNotEmpty) subBuffer.write(' ');
              subBuffer.write(part);
            }
          }
          if (subBuffer.isNotEmpty) {
            buffer.write(subBuffer.toString());
          }
        } else {
          buffer.write(sentence);
        }
      } else {
        if (buffer.isNotEmpty) buffer.write(' ');
        buffer.write(sentence);
      }
    }

    if (buffer.isNotEmpty) {
      chunks.add(buffer.toString().trim());
    }

    return chunks.where((c) => c.trim().isNotEmpty).toList();
  }

  @override
  Future<List<TtsVoice>> getAvailableVoices(String language) async {
    if (!language.toLowerCase().startsWith('vi')) return [];
    return _voices;
  }
}