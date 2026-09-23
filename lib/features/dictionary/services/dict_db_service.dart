import 'package:sqflite/sqflite.dart';

import '../models/dict_entry.dart';

/// SQLite CRUD cho dictionary entries
class DictDbService {
  static Future<String> createDb(String dbPath) async {
    final db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE dict_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            headword TEXT NOT NULL,
            definition TEXT NOT NULL,
            phonetic TEXT,
            audio_path TEXT,
            part_of_speech TEXT,
            dict_id TEXT NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_headword ON dict_entries(headword COLLATE NOCASE)',
        );
        await db.execute(
          'CREATE INDEX idx_dict_id ON dict_entries(dict_id)',
        );
      },
    );
    await db.close();
    return dbPath;
  }

  /// Ghi nhiều entry bằng `Batch` (thay vì 1 transaction với N insert đơn
  /// lẻ — cách cũ mất nhiều phút cho từ điển 100k mục).
  ///
  /// [onProgress](số-đã-ghi, tổng-số) để UI hiện thanh tiến trình.
  static Future<int> insertBatch(
    String dbPath,
    List<Map<String, dynamic>> entries, {
    int batchSize = 500,
    void Function(int done, int total)? onProgress,
  }) async {
    if (entries.isEmpty) return 0;
    final size = batchSize <= 0 ? 500 : batchSize;
    final db = await openDatabase(dbPath);
    var count = 0;
    try {
      for (var start = 0; start < entries.length; start += size) {
        final end = start + size > entries.length ? entries.length : start + size;
        final batch = db.batch();
        for (var i = start; i < end; i++) {
          batch.insert('dict_entries', entries[i]);
        }
        await batch.commit(noResult: true);
        count = end;
        onProgress?.call(count, entries.length);
      }
    } finally {
      await db.close();
    }
    return count;
  }

  static Future<List<DictEntry>> lookup(String dbPath, String word) async {
    if (word.isEmpty) return const [];
    final db = await openDatabase(dbPath, readOnly: true);
    try {
      final maps = await db.query(
        'dict_entries',
        where: 'headword = ? COLLATE NOCASE',
        whereArgs: [word],
        limit: 10,
      );
      return maps.map((m) => DictEntry.fromMap(m)).toList();
    } finally {
      await db.close();
    }
  }

  static Future<List<DictEntry>> lookupPrefix(
    String dbPath,
    String prefix, {
    int limit = 10,
  }) async {
    if (prefix.isEmpty) return const [];
    final db = await openDatabase(dbPath, readOnly: true);
    try {
      final maps = await db.query(
        'dict_entries',
        where: 'headword LIKE ? COLLATE NOCASE',
        whereArgs: ['$prefix%'],
        limit: limit,
      );
      return maps.map((m) => DictEntry.fromMap(m)).toList();
    } finally {
      await db.close();
    }
  }

  static Future<void> deleteDb(String dbPath) async {
    await deleteDatabase(dbPath);
  }
}
