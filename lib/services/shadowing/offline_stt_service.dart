// lib/services/offline_stt_service.dart
// NEW - Dịch vụ nhận dạng giọng nói offline sử dụng Vosk API
// Offline Speech-to-Text Service (Simplified version)

import 'dart:math' as math;
import 'package:flutter/foundation.dart';

/// Simplified Offline STT Service
/// Trong production, có thể dùng:
/// - speech_to_text package (dùng STT của device)
/// - vosk_flutter (offline STT thực sự)
/// - google_speech (online)
class OfflineSTTService {
  static bool _initialized = false;

  /// Initialize service
  static Future<void> initialize() async {
    if (_initialized) return;

    // Trong production: Load model files
    await Future.delayed(const Duration(milliseconds: 100));

    _initialized = true;
    debugPrint('✅ Offline STT Service initialized');
  }

  /// Transcribe audio file to text
  /// Hiện tại: trả về text giả định với một số lỗi ngẫu nhiên
  static Future<String> transcribe(
      String audioPath, String originalText) async {
    // Simulate processing time
    await Future.delayed(const Duration(seconds: 1));

    // Trong production: thực sự transcribe audio
    // Hiện tại: trả về text với độ chính xác ngẫu nhiên 70-100%

    final words = originalText.toLowerCase().split(' ');
    final transcribedWords = <String>[];
    final random = math.Random();

    for (final word in words) {
      final accuracy = 0.7 + random.nextDouble() * 0.3; // 70-100%

      if (accuracy > 0.85) {
        // Từ đúng
        transcribedWords.add(word);
      } else if (accuracy > 0.70) {
        // Từ gần đúng (thay 1-2 ký tự)
        transcribedWords.add(_modifyWord(word));
      } else {
        // Bỏ qua từ hoặc thay bằng từ khác
        if (random.nextBool()) {
          transcribedWords.add(_getRandomSimilarWord(word));
        }
      }
    }

    return transcribedWords.join(' ');
  }

  static String _modifyWord(String word) {
    if (word.length <= 2) return word;

    final chars = word.split('');
    final random = math.Random();
    final index = random.nextInt(chars.length);

    // Thay một ký tự ngẫu nhiên
    const vowels = 'aeiou';
    const consonants = 'bcdfghjklmnpqrstvwxyz';

    if (vowels.contains(chars[index])) {
      chars[index] = vowels[random.nextInt(vowels.length)];
    } else {
      chars[index] = consonants[random.nextInt(consonants.length)];
    }

    return chars.join('');
  }

  static String _getRandomSimilarWord(String word) {
    final similarWords = {
      'the': ['that', 'this', 'a'],
      'is': ['was', 'are', 'be'],
      'hello': ['hi', 'hey', 'halo'],
      'world': ['word', 'work', 'would'],
      'good': ['god', 'could', 'great'],
      'practice': ['practical', 'perfect', 'protect'],
      // Add more...
    };

    final options = similarWords[word];
    if (options != null && options.isNotEmpty) {
      return options[math.Random().nextInt(options.length)];
    }

    return word;
  }

  /// Clean up resources
  static void dispose() {
    _initialized = false;
  }
}
