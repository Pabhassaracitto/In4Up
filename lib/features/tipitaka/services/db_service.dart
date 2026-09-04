import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:in4up/features/tipitaka/models/segment.dart';
import 'package:in4up/features/tipitaka/models/book.dart';
import 'package:in4up/features/tipitaka/models/collection.dart';

class TipitakaDb {
  static Database? _db;
  static const String dbName = 'tipitaka.sqlite';

  static Future<Database> init(String path) async {
    if (_db != null && _db!.isOpen) return _db!;
    final fullPath = join(path, dbName);
    _db = await openDatabase(
      fullPath,
      version: 1,
      onCreate: (db, version) async {
        await _createSchema(db);
      },
    );
    return _db!;
  }

  static Future<Database> openAt(String filePath) async {
    if (_db != null && _db!.isOpen) await _db!.close();
    _db = await openDatabase(filePath);
    return _db!;
  }

  static Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tipitaka_collections (
        id INTEGER PRIMARY KEY,
        name_pali TEXT,
        name_en TEXT,
        name_vi TEXT,
        order_index INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tipitaka_books (
        id INTEGER PRIMARY KEY,
        collection_id INTEGER,
        code TEXT,
        name_pali TEXT,
        name_en TEXT,
        name_vi TEXT,
        order_index INTEGER,
        metadata_json TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tipitaka_segments (
        id INTEGER PRIMARY KEY,
        book_id INTEGER,
        section_id INTEGER,
        reference TEXT,
        paragraph_no INTEGER,
        pali_text TEXT,
        translation_en TEXT,
        translation_vi TEXT,
        translation_my TEXT,
        translation_th TEXT,
        order_index INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tipitaka_user_notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER DEFAULT 1,
        segment_id INTEGER,
        note TEXT,
        tags TEXT,
        created_at INTEGER DEFAULT (strftime('%s','now')),
        updated_at INTEGER DEFAULT (strftime('%s','now'))
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_segments_book ON tipitaka_segments(book_id)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_segments_ref ON tipitaka_segments(reference)
    ''');
    // Optional full-text index; requires SQLite FTS5 enabled at compile time
    // If unavailable, search will fallback to LIKE queries.
    await db.execute('''
      CREATE VIRTUAL TABLE IF NOT EXISTS tipitaka_fts USING fts5(
        reference, pali_text, translation_en, translation_vi, tokenize='unicode61'
      )
    ''');
  }

  static Future<List<TipitakaCollection>> getCollections(Database db) async {
    final rows = await db.query('tipitaka_collections', orderBy: 'order_index ASC');
    return rows.map((r) => TipitakaCollection.fromMap(r)).toList();
  }

  static Future<List<TipitakaBook>> getBooksByCollection(Database db, int collectionId) async {
    final rows = await db.query(
      'tipitaka_books',
      where: 'collection_id = ?',
      whereArgs: [collectionId],
      orderBy: 'order_index ASC',
    );
    return rows.map((r) => TipitakaBook.fromMap(r)).toList();
  }

  static Future<List<TipitakaSegment>> getSegmentsByBook(Database db, int bookId, {int limit = 200, int offset = 0}) async {
    final rows = await db.query(
      'tipitaka_segments',
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'order_index ASC, paragraph_no ASC',
      limit: limit,
      offset: offset,
    );
    return rows.map((r) => TipitakaSegment.fromMap(r)).toList();
  }

  static Future<List<TipitakaSegment>> searchSegments(Database db, String q) async {
    // Try FTS if exists; else LIKE
    try {
      final rows = await db.query(
        'tipitaka_fts',
        where: 'tipitaka_fts MATCH ?',
        whereArgs: [q],
        limit: 50,
      );
      if (rows.isNotEmpty) {
        // Map FTS results back via segment id if we stored id in FTS; for simplicity return direct
        // In production, join with tipitaka_segments using rowid.
        // Here we do a simple LIKE fallback for reliability.
      }
    } catch (_) {}
    final like = '%$q%';
    final rows = await db.query(
      'tipitaka_segments',
      where: 'pali_text LIKE ? OR translation_en LIKE ? OR translation_vi LIKE ? OR reference LIKE ?',
      whereArgs: [like, like, like, like],
      limit: 50,
    );
    return rows.map((r) => TipitakaSegment.fromMap(r)).toList();
  }
}