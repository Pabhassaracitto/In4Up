// lib/features/translation/engines/offline_engine.dart

import 'translation_engine.dart';
import '../data/offline_dictionary.dart';

/// Offline translation - dịch từng từ bằng từ điển local
/// Fallback cuối cùng khi không có internet
class OfflineEngine extends TranslationEngine {
  final OfflineDictionary _dictionary = OfflineDictionary();

  @override
  String get name => 'Offline Dictionary';

  @override
  String get id => 'offline';

  @override
  int get maxCharsPerRequest => 10000;

  @override
  Duration get requestDelay => Duration.zero;

  @override
  Future<bool> isAvailable() async => true; // Luôn sẵn sàng

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

    final source = sourceLang.replaceAll('_', '-').toUpperCase();
    final target = targetLang.replaceAll('_', '-').toUpperCase();
    if (source != 'EN' || target != 'VI') {
      return TranslationResult.failure(
        original: text,
        error: 'Từ điển offline hiện chỉ hỗ trợ EN → VI',
        engine: name,
        detectedLang: source,
        targetLang: target,
      );
    }

    final stopwatch = Stopwatch()..start();

    try {
      final translated = _translateText(text);
      stopwatch.stop();

      return TranslationResult.success(
        original: text,
        translated: translated,
        engine: name,
        responseTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return TranslationResult.failure(
        original: text,
        error: e.toString(),
        engine: name,
      );
    }
  }

  String _translateText(String text) {
    // Thử tra cả câu/cụm trước
    final fullLookup = _dictionary.lookup(text.trim().toLowerCase());
    if (fullLookup != null) return fullLookup;

    // Dịch từng từ
    final words = text.split(RegExp(r'\s+'));
    final buffer = StringBuffer();

    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      final cleaned = word.replaceAll(RegExp(r"[^\w']"), '').toLowerCase();

      if (cleaned.isEmpty) {
        buffer.write(word);
      } else {
        final translation = _dictionary.lookup(cleaned);
        if (translation != null) {
          buffer.write(translation);
        } else {
          buffer.write(word); // Giữ nguyên nếu không tìm thấy
        }
      }

      if (i < words.length - 1) buffer.write(' ');
    }

    return buffer.toString();
  }
}
