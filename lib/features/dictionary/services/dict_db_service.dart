import 'package:sqflite/sqflite.dart';
import '../models/dict_entry.dart';

/// SQLite CRUD cho dictionary entries
class DictDbService {
  /// Tạo DB mới cho 1 từ điển, trả về path
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

  /// Insert entries hàng loạt (batch)
  static Future<int> insertBatch(
    String dbPath,
    List<Map<String, dynamic>> entries,
  ) async {
    final db = await openDatabase(dbPath);
    int count = 0;
    // Chia batch 500 entries để tránh quá lớn
    for (var i = 0; i < entries.length; i += 500) {
      final end = (i + 500 < entries.length) ? i + 500 : entries.length;
      final batch = db.batch();
      for (var j = i; j < end; j++) {
        batch.insert('dict_entries', entries[j]);
      }
      final results = await batch.commit(noResult: true);
      count += results.length;
    }
    await db.close();
    return count;
  }

  /// Tra từ (exact match, case-insensitive)
  static Future<List<DictEntry>> lookup(
    String dbPath,
    String word, {
    String? dictId,
  }) async {
    final db = await openDatabase(dbPath, readOnly: true);
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'dict_entries',
        where: 'headword = ? COLLATE NOCASE',
        whereArgs: [word],
        limit: 20,
      );
      return maps.map((m) => DictEntry.fromMap(m)).toList();
    } finally {
      await db.close();
    }
  }

  /// Tra từ prefix (autocomplete)
  static Future<List<DictEntry>> lookupPrefix(
    String dbPath,
    String prefix, {
    int limit = 10,
  }) async {
    final db = await openDatabase(dbPath, readOnly: true);
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'dict_entries',
        where: 'headword >= ? COLLATE NOCASE AND headword < ? COLLATE NOCASE',
        whereArgs: [prefix, _nextString(prefix)],
        limit: limit,
      );
      return maps.map((m) => DictEntry.fromMap(m)).toList();
    } finally {
      await db.close();
    }
  }

  /// Đếm entries trong DB
  static Future<int> countEntries(String dbPath) async {
    final db = await openDatabase(dbPath, readOnly: true);
    try {
      final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM dict_entries');
      return (result.first['cnt'] as int?) ?? 0;
    } finally {
      await db.close();
    }
  }

  /// Xóa DB file
  static Future<void> deleteDb(String dbPath) async {
    await deleteDatabase(dbPath);
  }

  /// Tìm chuỗi tiếp theo theo thứ tự từ điển (cho prefix search)
  static String _nextString(String s) {
    if (s.isEmpty) return s;
    final chars = s.codeUnits.toList();
    chars[chars.length - 1] = chars[chars.length - 1] + 1;
    return String.fromCharCodes(chars);
  }
}
