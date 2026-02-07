// lib/services/shadowing/offline_stt_service.dart

import 'dart:math' as math;
import 'package:flutter/foundation.dart';

class OfflineSTTService {
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    await Future.delayed(const Duration(milliseconds: 100));
    _initialized = true;
    debugPrint('✅ Offline STT Service initialized');
  }

  /// Transcribe audio file to text
  /// NOTE: Đây là simulation - trong production dùng speech_to_text hoặc vosk
  static Future<String> transcribe(
    String audioPath,
    String originalText,
  ) async {
    await Future.delayed(const Duration(milliseconds: 800));

    final words = originalText.toLowerCase().split(RegExp(r'\s+'));
    if (words.isEmpty) return '';

    final transcribedWords = <String>[];
    final random = math.Random();

    // ✅ Tính accuracy dựa trên file size (giả lập chất lượng ghi âm)
    // Trong thực tế, dùng STT engine thật
    final baseAccuracy = 0.3 + random.nextDouble() * 0.4; // 30-70% base

    debugPrint(
        '🎯 Base accuracy for this session: ${(baseAccuracy * 100).toStringAsFixed(0)}%');

    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      if (word.isEmpty) continue;

      // Mỗi từ có accuracy khác nhau
      final wordAccuracy = baseAccuracy + (random.nextDouble() * 0.3 - 0.15);

      if (wordAccuracy > 0.75) {
        // Đúng hoàn toàn
        transcribedWords.add(word);
      } else if (wordAccuracy > 0.55) {
        // Gần đúng - sai 1-2 ký tự
        transcribedWords.add(_modifyWord(word, random));
      } else if (wordAccuracy > 0.35) {
        // Sai nhiều - thay bằng từ khác
        transcribedWords.add(_getRandomWord(word, random));
      } else {
        // Bỏ qua hoặc thêm filler
        if (random.nextBool()) {
          transcribedWords.add('uh');
        }
        // Else: skip word entirely
      }
    }

    final result = transcribedWords.join(' ');

    debugPrint('📝 STT Original:    "$originalText"');
    debugPrint('🎤 STT Transcribed: "$result"');

    return result;
  }

  static String _modifyWord(String word, math.Random random) {
    if (word.length <= 1) return word;

    final chars = word.split('');
    final numChanges = 1 + random.nextInt(math.min(2, chars.length - 1));

    for (int c = 0; c < numChanges; c++) {
      final index = random.nextInt(chars.length);
      const letters = 'abcdefghijklmnoprstuvwxyz';
      chars[index] = letters[random.nextInt(letters.length)];
    }

    return chars.join('');
  }

  static String _getRandomWord(String original, math.Random random) {
    // Trả về từ ngẫu nhiên thông dụng
    const commonWords = [
      'the',
      'a',
      'is',
      'it',
      'in',
      'to',
      'and',
      'of',
      'that',
      'was',
      'for',
      'on',
      'are',
      'with',
      'they',
      'be',
      'at',
      'one',
      'have',
      'this',
      'from',
      'had',
      'not',
      'but',
      'what',
      'all',
      'were',
      'we',
      'when',
      'your',
      'can',
      'said',
      'each',
      'she',
      'do',
      'how',
      'um',
      'uh',
      'hmm',
      'like',
      'just',
      'so',
      'well',
    ];

    return commonWords[random.nextInt(commonWords.length)];
  }

  static void dispose() {
    _initialized = false;
  }
}
