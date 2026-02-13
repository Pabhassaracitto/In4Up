// lib/services/phoneme_analyzer.dart
// NEW - Phân tích phiên âm nâng cao với G2P rules và CMU Dictionary
// Unified Phoneme Analyzer - kết hợp CMU Dict và G2P Rules

import '../models/phoneme_models.dart';
import 'cmu_dictionary_service.dart';
import 'g2p_rules_service.dart';

class PhonemeAnalyzer {
  static bool _initialized = false;

  /// Khởi tạo - gọi 1 lần khi app start
  static Future<void> initialize() async {
    if (_initialized) return;
    await CMUDictionaryService.initialize();
    _initialized = true;
  }

  static bool get isInitialized => _initialized;

  /// Lấy IPA cho BẤT KỲ từ tiếng Anh nào
  static PhonemeResult getPhonemes(String word) {
    final cleanWord = word.toLowerCase().replaceAll(RegExp(r'[^\w]'), '');

    if (cleanWord.isEmpty) {
      return PhonemeResult(
        word: word,
        phonemes: [],
        source: PhonemeSource.g2pRules,
        confidence: 0.0,
      );
    }

    // 1. Try CMU Dictionary first
    final cmuResult = CMUDictionaryService.getIPA(cleanWord);
    if (cmuResult != null) {
      return PhonemeResult(
        word: word,
        phonemes: cmuResult,
        source: PhonemeSource.cmuDictionary,
        confidence: 1.0,
      );
    }

    // 2. Fallback to G2P rules
    final g2pResult = G2PRulesService.predict(cleanWord);
    return PhonemeResult(
      word: word,
      phonemes: g2pResult,
      source: PhonemeSource.g2pRules,
      confidence: 0.75,
    );
  }

  /// Get detailed phoneme info
  static List<PhonemeInfo> getDetailedPhonemes(String word) {
    final result = getPhonemes(word);

    return result.phonemes.asMap().entries.map((entry) {
      final idx = entry.key;
      final phoneme = entry.value;

      return PhonemeInfo(
        symbol: phoneme,
        type: CMUDictionaryService.getPhonemeType(phoneme),
        position: idx,
        isStressed: phoneme.contains('ˈ') || phoneme.contains('ˌ'),
        description: CMUDictionaryService.getPhonemeDescription(phoneme),
        examples: CMUDictionaryService.getPhonemeExamples(phoneme),
      );
    }).toList();
  }

  /// Analyze sentence
  static List<PhonemeResult> analyzeSentence(String sentence) {
    final words = sentence.split(RegExp(r'\s+'));
    return words
        .where((w) => w.isNotEmpty)
        .map((w) => getPhonemes(w.replaceAll(RegExp(r'[^\w]'), '')))
        .where((r) => r.phonemes.isNotEmpty)
        .toList();
  }
}
