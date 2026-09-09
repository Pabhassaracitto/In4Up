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

  static Future<int> insertBatch(
    String dbPath,
    List<Map<String, dynamic>> entries,
  ) async {
    final db = await openDatabase(dbPath);
    int count = 0;
    await db.transaction((txn) async {
      for (final entry in entries) {
        await txn.insert('dict_entries', entry);
        count++;
      }
    });
    await db.close();
    return count;
  }

  static Future<List<DictEntry>> lookup(String dbPath, String word) async {
    final db = await openDatabase(dbPath, readOnly: true);
    final maps = await db.query(
      'dict_entries',
      where: 'headword = ? COLLATE NOCASE',
      whereArgs: [word],
      limit: 10,
    );
    await db.close();
    return maps.map((m) => DictEntry.fromMap(m)).toList();
  }

  static Future<List<DictEntry>> lookupPrefix(
    String dbPath,
    String prefix, {
    int limit = 10,
  }) async {
    final db = await openDatabase(dbPath, readOnly: true);
    final maps = await db.query(
      'dict_entries',
      where: 'headword LIKE ? COLLATE NOCASE',
      whereArgs: ['$prefix%'],
      limit: limit,
    );
    await db.close();
    return maps.map((m) => DictEntry.fromMap(m)).toList();
  }

  static Future<void> deleteDb(String dbPath) async {
    await deleteDatabase(dbPath);
  }
}
