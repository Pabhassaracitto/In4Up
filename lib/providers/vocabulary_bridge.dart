// ═══════════════════════════════════════════════════════════════
//  PATCH CHO text_provider.dart
//  Đồng bộ saveWord() → VocabularyProvider
//  (Tổng quan, Bản đồ, Tam giác, Venn dùng chung VocabularyProvider)
// ═══════════════════════════════════════════════════════════════
//
//  Trong file text_provider.dart, tìm hàm saveWord() và THÊM đoạn này
//  sau dòng: _storage.saveWord(word.word, {...})
//
//  // ★ ĐỒNG BỘ sang VocabularyProvider (Tổng quan / Bản đồ / Tam giác / Venn)
//  Future.microtask(() {
//    try {
//      VocabularyBridge.addWord(
//        word: word.word,
//        meaning: word.meaning ?? '',
//        phonetic: word.phonetic,
//        example: word.example,
//      );
//    } catch (e) {
//      debugPrint('⚠️ VocabularyBridge error: $e');
//    }
//  });
//
// ═══════════════════════════════════════════════════════════════

// Đặt file này ở: lib/providers/vocabulary_bridge.dart

import 'package:flutter/material.dart';
import '../models/word_entry.dart';
import 'vocabulary_provider.dart';

/// Bridge tĩnh để bất kỳ đâu trong app cũng có thể thêm từ vào
/// VocabularyProvider mà không cần BuildContext.
class VocabularyBridge {
  static VocabularyProvider? _instance;

  /// Gọi trong main.dart sau khi khởi tạo provider:
  /// VocabularyBridge.init(vocabProvider);
  static void init(VocabularyProvider provider) {
    _instance = provider;
    debugPrint('✅ VocabularyBridge initialized');
  }

  /// Thêm từ từ bất kỳ đâu (TextProvider, MemoryProvider, v.v.)
  static void addWord({
    required String word,
    required String meaning,
    String? phonetic,
    String? example,
  }) {
    final inst = _instance;
    if (inst == null) {
      debugPrint('⚠️ VocabularyBridge: not initialized');
      return;
    }

    final normalized = word.toLowerCase().trim();
    if (normalized.isEmpty || inst.hasWord(normalized)) return;

    inst.addWord(WordEntry(
      id: 'sync_${DateTime.now().millisecondsSinceEpoch}',
      word: normalized,
      meaning: meaning,
      phonetic: phonetic,
      example: example,
    ));

    debugPrint('📚 VocabularyBridge: added "$normalized"');
  }

  /// Kiểm tra đã init chưa
  static bool get isReady => _instance != null;
}
