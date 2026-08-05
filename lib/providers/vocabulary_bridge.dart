// Điểm vào tĩnh — không cần BuildContext
// Gọi từ TextProvider, WebReaderController, PdfReaderController, v.v.

import 'package:flutter/foundation.dart';
import 'package:in2up_core/vocab_level_difficulty.dart';

import '../models/vocab_context.dart';
import '../models/vocabulary_type.dart';
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

  /// Thêm vào WordList với context để tích luỹ ngữ cảnh gặp lại.
  static WordEntry? addContextual({
    required String text,
    String meaning = '',
    String? phonetic,
    String? example,
    VocabContext? context,
    VocabularyType? forceType,
    String language = 'en',
    String? topic,
  }) {
    final inst = _instance;
    if (inst == null) {
      debugPrint('⚠️ VocabularyBridge: not initialized');
      return null;
    }

    final normalized = text.trim();
    if (normalized.isEmpty || normalized.length < 2) {
      return null;
    }

    final entry = inst.addWithAutoClassify(
      text: normalized,
      meaning: meaning,
      phonetic: phonetic,
      forceType: forceType,
      context: context,
      language: language,
      topic: topic,
    );

    final normalizedExample = example?.trim() ?? '';
    if (normalizedExample.isNotEmpty &&
        (entry.example == null || entry.example!.trim().isEmpty)) {
      inst.updateWord(entry.id, example: normalizedExample);
    }

    return entry;
  }

  static WordEntry? upsertDifficulty({
    required String text,
    required DifficultyLevel difficulty,
    VocabContext? context,
    VocabularyType? forceType,
    String meaning = '',
    String? phonetic,
    String language = 'en',
    String? topic,
  }) {
    final inst = _instance;
    if (inst == null) {
      debugPrint('⚠️ VocabularyBridge: not initialized');
      return null;
    }
    return inst.upsertDifficulty(
      text: text.trim(),
      difficulty: difficulty,
      context: context,
      forceType: forceType,
      meaning: meaning,
      phonetic: phonetic,
      language: language,
      topic: topic,
    );
  }

  static void updateDifficulty(String id, DifficultyLevel? difficulty) {
    _instance?.updateDifficulty(id, difficulty);
  }

  static DifficultyLevel? difficultyOf(String word) =>
      _instance?.findByWord(word.trim().toLowerCase())?.userDifficulty;

  static Map<String, String> exportDifficultyMap() {
    final inst = _instance;
    if (inst == null) return const {};
    final out = <String, String>{};
    for (final entry in inst.allWords) {
      final difficulty = entry.userDifficulty;
      if (difficulty == null) continue;
      out[entry.word.toLowerCase().trim()] = difficulty.name;
    }
    return out;
  }

  static bool hasWord(String word) => _instance?.hasWord(word) ?? false;
  static WordEntry? findByWord(String word) => _instance?.findByWord(word);
  static int get dueCount => _instance?.dueCount ?? 0;
  static int get totalCount => _instance?.total ?? 0;
  static bool get isReady => _instance != null;
}
