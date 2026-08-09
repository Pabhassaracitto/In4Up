// lib/features/translation/data/dictionary_loader.dart
//
// STUB for Branch B — Import glossary + canon vào Drift/Hive
// Branch B điền, tham chiếu docs/DICTIONARY_SPEC.md §3
// Hiện tại chỉ là stub để DictionaryEngine có nơi gọi, không vỡ build.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Helper tải glossary + extract từ canon .md
class DictionaryLoader {
  static const String glossaryAsset = 'assets/dictionary/glossary_phathoc.csv';

  /// Đếm số entries đã import (stub)
  Future<int> count() async {
    // TODO(Branch B): return Drift/Hive count
    // return await _drift.countDictEntries();
    return 0;
  }

  /// Import từ assets (gọi 1 lần khi cài app / khi update)
  Future<int> importFromAssets({bool force = false}) async {
    try {
      final csv = await rootBundle.loadString(glossaryAsset);
      final lines = csv.split('\n').where((l) => l.trim().isNotEmpty && !l.startsWith('id,')).toList();
      debugPrint('[DictionaryLoader] Found ${lines.length} glossary lines (stub, chưa ghi Drift)');

      // TODO(Branch B):
      // 1. Parse CSV → List<DictEntry>
      // 2. Drift batch insert: await _drift.batchInsert(entries)
      // 3. Rebuild FTS: await _fts.rebuild()
      // 4. Extract thêm từ assets/canon/*.md (bảng | Pali | Việt |) → merge

      // Tạm trả số dòng để UI hiện progress
      return lines.length;
    } catch (e) {
      debugPrint('[DictionaryLoader] import error: $e');
      return 0;
    }
  }

  /// Xóa toàn bộ (khi cần re-import)
  Future<void> clear() async {
    // TODO(Branch B): await _drift.clearDict();
    debugPrint('[DictionaryLoader] clear stub');
  }

  /// Tìm theo term_norm exact (để DictionaryEngine gọi)
  Future<Map<String, dynamic>?> findByNorm(String norm) async {
    // TODO(Branch B): return await _drift.findByNorm(norm);
    return null;
  }
}
