import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

import 'package:in4up/features/tipitaka/models/book.dart';
import 'package:in4up/features/tipitaka/models/collection.dart';
import 'package:in4up/features/tipitaka/models/segment.dart';

/// The normalized database contract used by the Tipiṭaka UI.
///
/// A database downloaded from Pa-Auk may be a source database with a
/// different schema. It must be passed through `scripts/import_tipitaka.py`
/// before it is installed here. This prevents sqflite from silently creating a
/// new, empty database beside an incompatible source file.
class TipitakaDatabaseException implements Exception {
  final String message;

  const TipitakaDatabaseException(this.message);

  @override
  String toString() => 'TipitakaDatabaseException: $message';
}

enum TipitakaDatabaseSource { installed, bundled }

class TipitakaDatabaseInfo {
  final String path;
  final TipitakaDatabaseSource source;
  final int bytes;
  final int collectionCount;
  final int bookCount;
  final int segmentCount;
  final Set<String> availableLanguages;

  const TipitakaDatabaseInfo({
    required this.path,
    required this.source,
    required this.bytes,
    required this.collectionCount,
    required this.bookCount,
    required this.segmentCount,
    required this.availableLanguages,
  });

  bool get isReady => collectionCount > 0 && bookCount > 0 && segmentCount > 0;
}

class TipitakaDb {
  static Database? _db;
  static String? _openPath;
  static TipitakaDatabaseSource _openSource = TipitakaDatabaseSource.installed;
  static bool _databaseFactoryReady = false;

  static const String dbName = 'tipitaka.sqlite';
  static const String bundledAssetPath = 'assets/db/tipitaka.sqlite';
  static const String _appDirectoryName = 'in4up/tipitaka';
  static const int _schemaVersion = 2;

  /// Opens an explicitly supplied application database path.
  ///
  /// `path` is kept optional for compatibility with the original module API.
  /// New code should use [openReady], which resolves the platform path and
  /// copies the bundled asset when appropriate.
  static Future<Database> init([String? path]) async {
    if (path == null) return openReady();
    return openAt(p.join(path, dbName));
  }

  /// Opens the installed database, or seeds it from the bundled asset.
  ///
  /// No empty database is created when neither source is available. Callers
  /// can therefore show an import/download action instead of displaying a
  /// misleading empty library.
  static Future<Database> openReady() async {
    await _ensureDatabaseFactory();
    final installedPath = await installedDatabasePath();
    if (!await _isUsableDatabaseFile(installedPath) &&
        await _isEmptyAppDatabase(installedPath)) {
      // Older builds of this module created a blank DB at a hard-coded path.
      // Replace that known-empty file with the developer asset, but never
      // overwrite a non-empty raw/source DB that a user may want to import.
      await copyBundledDatabaseIfPresent(force: true);
    }
    if (await _isUsableDatabaseFile(installedPath)) {
      return openAt(installedPath, source: TipitakaDatabaseSource.installed);
    }

    final bundledPath = await copyBundledDatabaseIfPresent();
    if (bundledPath != null && await _isUsableDatabaseFile(bundledPath)) {
      return openAt(bundledPath, source: TipitakaDatabaseSource.bundled);
    }

    throw const TipitakaDatabaseException(
      'Chưa có cơ sở dữ liệu Tipiṭaka hợp lệ. Hãy import file đã chuẩn hóa '
      'hoặc tải gói ngôn ngữ rồi chạy scripts/import_tipitaka.py.',
    );
  }

  /// Returns the persistent application path used for Tipiṭaka data.
  static Future<String> installedDatabasePath() async {
    final documents = await getApplicationDocumentsDirectory();
    return p.join(documents.path, _appDirectoryName, dbName);
  }

  /// Copies `assets/db/tipitaka.sqlite` to the writable application directory.
  ///
  /// The copy is only made when no installed DB exists. A developer can put a
  /// newer normalized DB in the asset and it will be used on a fresh install;
  /// user-imported data is never overwritten automatically.
  static Future<String?> copyBundledDatabaseIfPresent({bool force = false}) async {
    final target = await installedDatabasePath();
    final targetFile = File(target);
    if (await targetFile.exists() && !force) return target;

    ByteData data;
    try {
      data = await rootBundle.load(bundledAssetPath);
    } on FlutterError {
      // The asset is optional for production builds.
      return null;
    }

    final directory = Directory(p.dirname(target));
    await directory.create(recursive: true);
    final temporary = File('$target.part');
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    await temporary.writeAsBytes(bytes, flush: true);
    if (await targetFile.exists()) await targetFile.delete();
    await temporary.rename(target);
    return target;
  }

  /// Installs a normalized SQLite database selected by the user/developer.
  ///
  /// Raw Pa-Auk language databases are deliberately rejected with a useful
  /// error. They contain source-specific tables and cannot be queried by the
  /// reader until they have been merged by the importer.
  static Future<String> installDatabaseFile(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const TipitakaDatabaseException('Không tìm thấy file cơ sở dữ liệu.');
    }

    final valid = await _isUsableDatabaseFile(sourcePath);
    if (!valid) {
      throw const TipitakaDatabaseException(
        'File này chưa phải tipitaka.sqlite chuẩn của In4Up. '
        'Hãy giải nén các gói .zip và chạy scripts/import_tipitaka.py để hợp nhất Pāli/bản dịch.',
      );
    }

    await close();
    final targetPath = await installedDatabasePath();
    final target = File(targetPath);
    await target.parent.create(recursive: true);
    final temporary = File('$targetPath.part');
    await source.copy(temporary.path);
    if (await target.exists()) await target.delete();
    await temporary.rename(target.path);
    return target.path;
  }

  static Future<Database> openAt(
    String filePath, {
    TipitakaDatabaseSource source = TipitakaDatabaseSource.installed,
  }) async {
    await _ensureDatabaseFactory();
    if (_db != null && _db!.isOpen && _openPath == filePath) return _db!;
    await close();

    final file = File(filePath);
    if (!await file.exists()) {
      throw TipitakaDatabaseException('Không tìm thấy DB tại $filePath.');
    }

    _db = await openDatabase(
      filePath,
      version: _schemaVersion,
      onCreate: (db, version) => _createSchema(db),
      onUpgrade: (db, oldVersion, newVersion) => _createSchema(db),
      onOpen: (db) => _ensureSchema(db),
    );
    _openPath = filePath;
    _openSource = source;
    return _db!;
  }

  static Future<void> close() async {
    if (_db != null && _db!.isOpen) await _db!.close();
    _db = null;
    _openPath = null;
    _openSource = TipitakaDatabaseSource.installed;
  }

  static Future<void> _ensureDatabaseFactory() async {
    if (_databaseFactoryReady) return;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      ffi.sqfliteFfiInit();
      databaseFactory = ffi.databaseFactoryFfi;
    }
    _databaseFactoryReady = true;
  }

  static Future<bool> _isEmptyAppDatabase(String filePath) async {
    await _ensureDatabaseFactory();
    final file = File(filePath);
    if (!await file.exists() || await file.length() < 100) return false;
    Database? db;
    try {
      db = await openDatabase(
        filePath,
        readOnly: true,
        singleInstance: false,
      );
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
      );
      final names = tables.map((row) => row['name'] as String).toSet();
      if (names.isEmpty) return true;
      if (!names.contains('tipitaka_segments')) return false;
      final rows = await db.rawQuery('SELECT COUNT(*) AS n FROM tipitaka_segments');
      return (rows.first['n'] as int? ?? 0) == 0;
    } catch (_) {
      return false;
    } finally {
      await db?.close();
    }
  }

  static Future<bool> _isUsableDatabaseFile(String filePath) async {
    await _ensureDatabaseFactory();
    final file = File(filePath);
    if (!await file.exists() || await file.length() < 100) return false;

    Database? db;
    try {
      db = await openDatabase(
        filePath,
        readOnly: true,
        singleInstance: false,
      );
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );
      final names = tables.map((row) => row['name'] as String).toSet();
      if (!names.contains('tipitaka_collections') ||
          !names.contains('tipitaka_books') ||
          !names.contains('tipitaka_segments')) {
        return false;
      }
      final counts = await Future.wait([
        db.rawQuery('SELECT COUNT(*) AS n FROM tipitaka_collections'),
        db.rawQuery('SELECT COUNT(*) AS n FROM tipitaka_books'),
        db.rawQuery('SELECT COUNT(*) AS n FROM tipitaka_segments'),
      ]);
      return counts.every((rows) => (rows.first['n'] as int? ?? 0) > 0);
    } catch (_) {
      return false;
    } finally {
      await db?.close();
    }
  }

  static Future<void> _ensureSchema(Database db) async {
    await _createSchema(db);
  }

  static Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tipitaka_collections (
        id INTEGER PRIMARY KEY,
        name_pali TEXT NOT NULL DEFAULT '',
        name_en TEXT NOT NULL DEFAULT '',
        name_vi TEXT NOT NULL DEFAULT '',
        order_index INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tipitaka_books (
        id INTEGER PRIMARY KEY,
        collection_id INTEGER NOT NULL DEFAULT 0,
        code TEXT NOT NULL DEFAULT '',
        name_pali TEXT NOT NULL DEFAULT '',
        name_en TEXT NOT NULL DEFAULT '',
        name_vi TEXT NOT NULL DEFAULT '',
        order_index INTEGER NOT NULL DEFAULT 0,
        metadata_json TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tipitaka_segments (
        id INTEGER PRIMARY KEY,
        book_id INTEGER NOT NULL DEFAULT 0,
        section_id INTEGER,
        reference TEXT NOT NULL DEFAULT '',
        paragraph_no INTEGER,
        pali_text TEXT NOT NULL DEFAULT '',
        translation_en TEXT,
        translation_vi TEXT,
        translation_my TEXT,
        translation_th TEXT,
        order_index INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tipitaka_translations (
        segment_id INTEGER NOT NULL,
        language_code TEXT NOT NULL,
        text TEXT NOT NULL DEFAULT '',
        PRIMARY KEY(segment_id, language_code)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tipitaka_user_notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL DEFAULT 1,
        segment_id INTEGER NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        tags TEXT,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
        updated_at INTEGER NOT NULL DEFAULT (strftime('%s','now'))
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tipitaka_learning_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL DEFAULT 1,
        segment_id INTEGER NOT NULL,
        next_review_at INTEGER,
        memory_strength REAL NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
        updated_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
        UNIQUE(user_id, segment_id)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_segments_book ON tipitaka_segments(book_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_segments_ref ON tipitaka_segments(reference)',
    );

    // FTS5 is optional on desktop/web SQLite builds. LIKE search remains the
    // portable fallback, so an unavailable FTS5 extension must not block DB
    // startup.
    try {
      await db.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS tipitaka_fts USING fts5(
          segment_id UNINDEXED,
          reference,
          pali_text,
          translation_en,
          translation_vi,
          tokenize = 'unicode61'
        )
      ''');
    } catch (_) {
      // Optional feature; searchSegments uses LIKE below.
    }
  }

  static Future<TipitakaDatabaseInfo> info(
    Database db, {
    TipitakaDatabaseSource? source,
  }) async {
    final counts = await Future.wait([
      db.rawQuery('SELECT COUNT(*) AS n FROM tipitaka_collections'),
      db.rawQuery('SELECT COUNT(*) AS n FROM tipitaka_books'),
      db.rawQuery('SELECT COUNT(*) AS n FROM tipitaka_segments'),
    ]);
    final languages = <String>{'pi'};
    final columns = await db.rawQuery('PRAGMA table_info(tipitaka_segments)');
    final columnNames = columns.map((row) => row['name'] as String).toSet();
    if (columnNames.contains('translation_vi') &&
        (await _hasText(db, 'translation_vi'))) {
      languages.add('vi');
    }
    if (columnNames.contains('translation_en') &&
        (await _hasText(db, 'translation_en'))) {
      languages.add('en');
    }
    final extraLanguages = await db.rawQuery(
      'SELECT DISTINCT language_code FROM tipitaka_translations '
      'WHERE text <> \'\'',
    );
    languages.addAll(
      extraLanguages.map((row) => row['language_code'] as String),
    );
    final fileLength = await File(_openPath ?? '').length();
    return TipitakaDatabaseInfo(
      path: _openPath ?? '',
      source: source ?? _openSource,
      bytes: fileLength,
      collectionCount: counts[0].first['n'] as int? ?? 0,
      bookCount: counts[1].first['n'] as int? ?? 0,
      segmentCount: counts[2].first['n'] as int? ?? 0,
      availableLanguages: languages,
    );
  }

  static Future<bool> _hasText(Database db, String column) async {
    final rows = await db.rawQuery(
      'SELECT 1 FROM tipitaka_segments WHERE "$column" IS NOT NULL '
      'AND "$column" <> \'\' LIMIT 1',
    );
    return rows.isNotEmpty;
  }

  static Future<List<TipitakaCollection>> getCollections(Database db) async {
    final rows = await db.query(
      'tipitaka_collections',
      orderBy: 'order_index ASC, id ASC',
    );
    return rows.map((r) => TipitakaCollection.fromMap(r)).toList();
  }

  static Future<List<TipitakaBook>> getBooksByCollection(
    Database db,
    int collectionId,
  ) async {
    final rows = await db.query(
      'tipitaka_books',
      where: 'collection_id = ?',
      whereArgs: [collectionId],
      orderBy: 'order_index ASC, id ASC',
    );
    return rows.map((r) => TipitakaBook.fromMap(r)).toList();
  }

  static Future<List<TipitakaSegment>> getSegmentsByBook(
    Database db,
    int bookId, {
    int limit = 200,
    int offset = 0,
  }) async {
    final rows = await db.query(
      'tipitaka_segments',
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'order_index ASC, paragraph_no ASC, id ASC',
      limit: limit,
      offset: offset,
    );
    return rows.map((r) => TipitakaSegment.fromMap(r)).toList();
  }

  static Future<List<TipitakaSegment>> searchSegments(
    Database db,
    String query,
  ) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final like = '%$q%';
    final rows = await db.query(
      'tipitaka_segments',
      where: 'pali_text LIKE ? OR translation_en LIKE ? OR '
          'translation_vi LIKE ? OR translation_my LIKE ? OR '
          'translation_th LIKE ? OR reference LIKE ?',
      whereArgs: [like, like, like, like, like, like],
      orderBy: 'order_index ASC, id ASC',
      limit: 50,
    );
    return rows.map((r) => TipitakaSegment.fromMap(r)).toList();
  }
}
