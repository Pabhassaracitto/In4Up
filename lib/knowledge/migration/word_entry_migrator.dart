// BISECT B1 — bộ khung tối thiểu, chỉ giữ import word_entry.
// (Sẽ thay lại bản đầy đủ sau khi定位 được chỗ gây lỗi analyze.)

library;

import 'package:in4up/models/word_entry.dart';

class MigrationResult {
  const MigrationResult();
}

class WordEntryMigrator {
  WordEntryMigrator._();

  static MigrationResult migrate(
    List<WordEntry> entries, {
    DateTime? now,
    String Function()? newUnitId,
  }) =>
      const MigrationResult();
}
