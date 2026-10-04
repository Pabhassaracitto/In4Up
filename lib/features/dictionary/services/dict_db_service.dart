import 'package:sqflite/sqflite.dart';
import '../models/dict_entry.dart';

/// SQLite CRUD cho dictionary entries (DICT-001).
///
/// Import dùng WAL + transaction batch: từ điển lớn (vài trăm nghìn entry)
/// ghi nhanh hơn nhiều so với insert từng dòng.
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
    // WAL: import nhiều batch không block reader và giảm fsync.
    // (Ngoài onCreate — sqflite chạy onCreate trong transaction mà PRAGMA
    // journal_mode không chạy được trong transaction.)
    await db.execute('PRAGMA journal_mode=WAL');
    await db.close();
    return dbPath;
  }

  static Future<int> insertBatch(
    String dbPath,
    List<Map<String, dynamic>> entries,
  ) async {
    if (entries.isEmpty) return 0;
    final db = await openDatabase(dbPath);
    try {
      final batch = db.batch();
      for (final entry in entries) {
        batch.insert('dict_entries', entry);
      }
      await batch.commit(noResult: true);
    } finally {
      await db.close();
    }
    return entries.length;
  }

  static Future<List<DictEntry>> lookup(String dbPath, String word) async {
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
