// Điểm vào tĩnh — không cần BuildContext
// Gọi từ TextProvider, WebReaderController, PdfReaderController, v.v.

import 'package:flutter/foundation.dart';

import '../models/word_entry.dart';
import 'vocabulary_provider.dart';

class VocabularyBridge {
  static VocabularyProvider? _instance;

  static void init(VocabularyProvider provider) {
    _instance = provider;
    debugPrint('✅ VocabularyBridge initialized');
  }

  /// Thêm từ từ bất kỳ đâu trong app
  static void addWord({
    required String word,
    required String meaning,
    String? phonetic,
    String? example,
    String? source,
  }) {
    final inst = _instance;
    if (inst == null) {
      debugPrint('⚠️ VocabularyBridge: not initialized');
      return;
    }
    final normalized = word.toLowerCase().trim();
    if (normalized.isEmpty ||
        normalized.length < 2 ||
        inst.hasWord(normalized)) {
      return;
    }
    inst.addWord(WordEntry(
      id: 'bridge_${DateTime.now().millisecondsSinceEpoch}',
      word: normalized,
      meaning: meaning,
      phonetic: phonetic,
      example: example,
    ));
    debugPrint(
        '📚 VocabularyBridge: added "$normalized"${source != null ? " from $source" : ""}');
  }

  /// Thêm từ với thông tin phân tích ngôn ngữ
  static void addFromAnalyzed({
    required String word,
    String? meaning,
    String? phonetic,
    String? example,
    String? wordTypeName,
    String? cefrLevelName,
    String? sourceFile,
  }) {
    addWord(
      word: word,
      meaning: meaning ?? '',
      phonetic: phonetic,
      example: example,
      source: sourceFile,
    );
  }

  static bool hasWord(String word) => _instance?.hasWord(word) ?? false;
  static WordEntry? findByWord(String word) => _instance?.findByWord(word);
  static int get dueCount => _instance?.dueCount ?? 0;
  static int get totalCount => _instance?.total ?? 0;
  static bool get isReady => _instance != null;
}
