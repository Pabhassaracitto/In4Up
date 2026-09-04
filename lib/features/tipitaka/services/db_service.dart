import 'dart:io';

import 'package:archive/archive_io.dart';
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
/// different schema. The app can normalize a source `.db` directly; the
/// Python importer remains available for large offline/release builds. This
/// prevents sqflite from silently creating a new, empty database beside an
/// incompatible source file.
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
      'Chưa có cơ sở dữ liệu Tipiṭaka hợp lệ. Hãy chọn file .db/.sqlite '
      'hoặc tải một gói ngôn ngữ để ứng dụng tự import.',
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

  /// Installs either a normalized DB or a Pa-Auk source DB selected by the
  /// user/developer. Source databases are normalized in-app, so the user does
  /// not need Python just to import a downloaded language package.
  static Future<String> installDatabaseFile(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const TipitakaDatabaseException('Không tìm thấy file cơ sở dữ liệu.');
    }

    if (await _isZipFile(sourcePath)) {
      return _installDatabaseArchive(sourcePath);
    }

    if (await _isUsableDatabaseFile(sourcePath)) {
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

    return importSourceDatabase(sourcePath);
  }

  static Future<bool> _isZipFile(String path) async {
    final file = File(path);
    if (!await file.exists() || await file.length() < 4) return false;
    final handle = await file.open();
    try {
      final header = await handle.read(4);
      return header.length == 4 &&
          header[0] == 0x50 &&
          header[1] == 0x4b &&
          header[2] == 0x03 &&
          header[3] == 0x04;
    } finally {
      await handle.close();
    }
  }

  static Future<String> _installDatabaseArchive(String archivePath) async {
    final temporaryDirectory = await getTemporaryDirectory();
    final extractedPaths = <String>[];
    final input = InputFileStream(archivePath);
    try {
      final archive = ZipDecoder().decodeStream(input);
      for (final entry in archive) {
        if (!entry.isFile) continue;
        final name = entry.name.toLowerCase();
        if (!(name.endsWith('.db') ||
            name.endsWith('.sqlite') ||
            name.endsWith('.sqlite3'))) {
          continue;
        }
        final outputPath = p.join(
          temporaryDirectory.path,
          'in4up-import-${DateTime.now().microsecondsSinceEpoch}-${p.basename(entry.name)}',
        );
        final output = OutputFileStream(outputPath);
        entry.writeContent(output);
        output.closeSync();
        extractedPaths.add(outputPath);
      }
    } catch (error) {
      throw TipitakaDatabaseException(
        'Không thể giải nén gói cơ sở dữ liệu: $error',
      );
    } finally {
      input.closeSync();
    }

    if (extractedPaths.isEmpty) {
      throw const TipitakaDatabaseException(
        'Gói tải xuống không chứa file .db, .sqlite hoặc .sqlite3.',
      );
    }

    try {
      // A package can contain metadata copies; the first usable DB is the
      // deterministic choice and is also how the download service behaves.
      for (final extractedPath in extractedPaths) {
        try {
          return await installDatabaseFile(extractedPath);
        } on TipitakaDatabaseException {
          // Try the next DB entry before reporting a package failure.
        }
      }
      throw const TipitakaDatabaseException(
        'Không tìm thấy cơ sở dữ liệu Tipiṭaka dùng được trong gói.',
      );
    } finally {
      for (final extractedPath in extractedPaths) {
        final file = File(extractedPath);
        if (await file.exists()) await file.delete();
      }
    }
  }

  /// Imports a raw Pa-Auk SQLite source directly on the device.
  ///
  /// A Pāli source creates the normalized content DB. A translation source is
  /// merged into the already installed Pāli DB. Download/import Pāli first if
  /// the app does not yet have a Pāli database.
  static Future<String> importSourceDatabase(
    String sourcePath, {
    String? languageCode,
  }) async {
    await _ensureDatabaseFactory();
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw const TipitakaDatabaseException('Không tìm thấy file nguồn.');
    }

    final language = languageCode ?? _languageFromFilename(sourcePath);
    Database? source;
    try {
      source = await openDatabase(
        sourcePath,
        readOnly: true,
        singleInstance: false,
      );
      if (language == 'pi') {
        return await _importPaliSource(source);
      }

      final target = await openReady();
      final updated = await _mergeTranslationSource(target, source, language);
      if (updated == 0) {
        throw TipitakaDatabaseException(
          'Không tìm thấy đoạn Pāli tương ứng cho gói ngôn ngữ $language. '
          'Hãy import Pāli trước rồi thử lại.',
        );
      }
      return await installedDatabasePath();
    } on DatabaseException catch (error) {
      throw TipitakaDatabaseException(
        'File không phải SQLite hợp lệ hoặc không thể đọc: $error',
      );
    } finally {
      await source?.close();
    }
  }

  static Future<String> _importPaliSource(Database source) async {
    final targetPath = await installedDatabasePath();
    final temporaryPath = '$targetPath.importing';
    final temporary = File(temporaryPath);
    if (await temporary.exists()) await temporary.delete();
    await temporary.parent.create(recursive: true);

    Database? target;
    try {
      target = await openDatabase(
        temporaryPath,
        version: _schemaVersion,
        onCreate: (db, version) => _createSchema(db),
        onUpgrade: (db, oldVersion, newVersion) => _createSchema(db),
        onOpen: (db) => _ensureSchema(db),
      );
      final imported = await _copyPaliTables(source, target);
      if (imported == 0) {
        throw const TipitakaDatabaseException(
          'Không tìm thấy bảng văn bản Pāli trong file nguồn.',
        );
      }
      await target.close();
      target = null;
      await close();
      final destination = File(targetPath);
      if (await destination.exists()) await destination.delete();
      await temporary.rename(targetPath);
      return targetPath;
    } catch (_) {
      await target?.close();
      if (await temporary.exists()) await temporary.delete();
      rethrow;
    }
  }

  static Future<int> _copyPaliTables(
    Database source,
    Database target,
  ) async {
    final tables = await _sourceTables(source, textLanguage: 'pi');
    final collectionIds = <String, int>{};
    var imported = 0;
    var bookOrder = 0;

    for (final table in tables) {
      final columns = await _sourceColumns(source, table);
      final textColumn = _findSourceColumn(columns, const [
        'pali_text', 'text', 'content', 'paragraph', 'body', 'html', 'xml', 'data',
      ]);
      if (textColumn == null) continue;
      final rowCount = await _sourceRowCount(source, table);
      if (rowCount == 0) continue;

      final collection = _collectionForTable(table);
      final collectionId = collectionIds.putIfAbsent(collection.$1, () => 0);
      var actualCollectionId = collectionId;
      if (actualCollectionId == 0) {
        actualCollectionId = await target.insert('tipitaka_collections', {
          'name_pali': collection.$2,
          'name_en': collection.$2,
          'name_vi': collection.$3,
          'order_index': collectionIds.length + 1,
        });
        collectionIds[collection.$1] = actualCollectionId;
      }

      final bookId = await target.insert('tipitaka_books', {
        'collection_id': actualCollectionId,
        'code': table.toUpperCase(),
        'name_pali': table,
        'name_en': table,
        'name_vi': table,
        'order_index': ++bookOrder,
        'metadata_json': '{"source":"Pa-Auk","source_table":"$table"}',
      });

      final keyColumn = _findSourceColumn(columns, const [
        'id', 'rowid', 'paragraph_id', 'segment_id', 'para_id', 'seq', 'number',
      ]);
      final referenceColumn = _findSourceColumn(columns, const [
        'reference', 'ref', 'citation', 'section_ref', 'book_code',
      ]);
      final paragraphColumn = _findSourceColumn(columns, const [
        'paragraph_no', 'paragraph_number', 'para', 'line_no', 'segment_no', 'number',
      ]);
      final keyExpression = keyColumn == null ? 'rowid' : _quote(keyColumn);
      final referenceExpression = referenceColumn == null
          ? 'NULL'
          : _quote(referenceColumn);
      final paragraphExpression = paragraphColumn == null
          ? keyExpression
          : _quote(paragraphColumn);
      final select = 'SELECT $keyExpression AS _source_key, '
          '$referenceExpression AS _reference, '
          '$paragraphExpression AS _paragraph, ${_quote(textColumn)} AS _text '
          'FROM ${_quote(table)}';

      for (var offset = 0; offset < rowCount; offset += 500) {
        final rows = await source.rawQuery(
          '$select LIMIT ? OFFSET ?',
          [500, offset],
        );
        if (rows.isEmpty) break;
        final batch = target.batch();
        for (var index = 0; index < rows.length; index++) {
          final row = rows[index];
          final key = '${row['_source_key'] ?? offset + index + 1}';
          final reference = _plainText(row['_reference'])
                  .trim()
                  .isEmpty
              ? '$table:$key'
              : _plainText(row['_reference']).trim();
          batch.insert('tipitaka_segments', {
            'book_id': bookId,
            'reference': reference,
            'paragraph_no': _asInt(row['_paragraph'], offset + index + 1),
            'pali_text': _plainText(row['_text']),
            'order_index': imported,
            'source_table': table,
            'source_row_key': key,
          });
          imported++;
        }
        await batch.commit(noResult: true);
      }
    }
    return imported;
  }

  static Future<int> _mergeTranslationSource(
    Database target,
    Database source,
    String language,
  ) async {
    final tables = await _sourceTables(source, textLanguage: language);
    final fixedColumn = const {
      'en': 'translation_en',
      'vi': 'translation_vi',
      'my': 'translation_my',
      'th': 'translation_th',
    }[language];
    final targetRows = await target.query(
      'tipitaka_segments',
      columns: const ['id', 'source_table', 'source_row_key', 'reference'],
    );
    final targetBySource = <String, int>{};
    final targetByReference = <String, int>{};
    for (final row in targetRows) {
      final id = row['id'];
      if (id is! int) continue;
      final table = row['source_table'];
      final key = row['source_row_key'];
      if (table != null && key != null) {
        targetBySource['$table::$key'] = id;
      }
      final reference = row['reference'];
      if (reference != null) {
        targetByReference.putIfAbsent('$reference', () => id);
      }
    }
    var updated = 0;

    for (final table in tables) {
      final columns = await _sourceColumns(source, table);
      final textColumn = _findSourceColumn(columns, const [
        'translation', 'translated_text', 'translation_text', 'text', 'content', 'paragraph', 'body', 'html', 'xml', 'data',
      ]);
      if (textColumn == null) continue;
      final keyColumn = _findSourceColumn(columns, const [
        'id', 'rowid', 'paragraph_id', 'segment_id', 'ref_id', 'para_id', 'text_id', 'seq', 'number',
      ]);
      final referenceColumn = _findSourceColumn(columns, const [
        'reference', 'ref', 'citation', 'section_ref', 'book_code',
      ]);
      final sourceTableColumn = _findSourceColumn(columns, const [
        'source_table', 'table', 'book', 'book_code', 'document',
      ]);
      final keyExpression = keyColumn == null ? 'rowid' : _quote(keyColumn);
      final referenceExpression = referenceColumn == null
          ? 'NULL'
          : _quote(referenceColumn);
      final sourceTableExpression = sourceTableColumn == null
          ? 'NULL'
          : _quote(sourceTableColumn);
      final select = 'SELECT $keyExpression AS _source_key, '
          '$referenceExpression AS _reference, '
          '$sourceTableExpression AS _source_table, '
          '${_quote(textColumn)} AS _text '
          'FROM ${_quote(table)}';
      final rowCount = await _sourceRowCount(source, table);
      for (var offset = 0; offset < rowCount; offset += 500) {
        final rows = await source.rawQuery(
          '$select LIMIT ? OFFSET ?',
          [500, offset],
        );
        if (rows.isEmpty) break;
        for (final row in rows) {
          final key = '${row['_source_key'] ?? ''}';
          final reference = _plainText(row['_reference']).trim();
          final sourceTable = _plainText(row['_source_table']).trim();
          final segmentId = key.isEmpty
              ? targetByReference[reference]
              : targetBySource['${sourceTable.isEmpty ? table : sourceTable}::$key'] ??
                  targetByReference[reference];
          if (segmentId == null) continue;
          final text = _plainText(row['_text']);
          if (text.isEmpty) continue;
          if (fixedColumn != null) {
            await target.update(
              'tipitaka_segments',
              {fixedColumn: text},
              where: 'id = ?',
              whereArgs: [segmentId],
            );
          } else {
            await target.insert(
              'tipitaka_translations',
              {'segment_id': segmentId, 'language_code': language, 'text': text},
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
          updated++;
        }
      }
    }
    return updated;
  }

  static Future<List<String>> _sourceTables(
    Database db, {
    String? textLanguage,
  }) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name NOT LIKE 'sqlite_%' ORDER BY name",
    );
    final names = rows
        .map((row) => row['name'])
        .whereType<String>()
        .where((name) => !name.startsWith('tipitaka_'))
        .toList();
    if (textLanguage == null) return names;

    final candidates = textLanguage == 'pi'
        ? const [
            'pali_text', 'text', 'content', 'paragraph', 'body', 'html', 'xml', 'data',
          ]
        : const [
            'translation', 'translated_text', 'translation_text', 'text',
            'content', 'paragraph', 'body', 'html', 'xml', 'data',
          ];
    final keyCandidates = const [
      'id', 'rowid', 'reference', 'ref', 'citation', 'paragraph_id', 'segment_id',
    ];
    final result = <String>[];
    for (final name in names) {
      final columns = await _sourceColumns(db, name);
      if (_findSourceColumn(columns, candidates) == null) continue;
      // Match the Python importer: avoid treating one-column metadata tables
      // with a generic `data` field as scripture rows.
      if (columns.length >= 2 ||
          _findSourceColumn(columns, keyCandidates) != null) {
        result.add(name);
      }
    }
    return result;
  }

  static Future<List<String>> _sourceColumns(
    Database db,
    String table,
  ) async {
    final rows = await db.rawQuery('PRAGMA table_info(${_quote(table)})');
    return rows.map((row) => row['name']).whereType<String>().toList();
  }

  static Future<int> _sourceRowCount(Database db, String table) async {
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS n FROM ${_quote(table)}',
    );
    return _asInt(rows.first['n'], 0);
  }

  static String? _findSourceColumn(
    List<String> columns,
    List<String> candidates,
  ) {
    final normalized = <String, String>{
      for (final column in columns) _normalizeName(column): column,
    };
    for (final candidate in candidates) {
      final match = normalized[_normalizeName(candidate)];
      if (match != null) return match;
    }
    // Pa-Auk schemas sometimes use a descriptive column name such as
    // `pali_text_utf8` or `translation_vietnamese`.
    for (final candidate in candidates) {
      final wanted = _normalizeName(candidate);
      if (wanted.length < 3) continue;
      for (final column in columns) {
        if (_normalizeName(column).contains(wanted)) return column;
      }
    }
    return null;
  }

  static String _normalizeName(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static String _quote(String value) => '"${value.replaceAll('"', '""')}"';

  static int _asInt(Object? value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? fallback;
  }

  static String _plainText(Object? value) {
    var text = '$value';
    if (value == null || text == 'null') return '';
    text = text
        .replaceAll(RegExp(r'<\s*br\s*/?\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</\s*p\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&#39;', "'")
        .replaceAll('&quot;', '"')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .replaceAll(RegExp(r'[ \t]+'), ' ');
    return text.trim();
  }

  static (String, String, String) _collectionForTable(String table) {
    final name = table.toLowerCase();
    if (name.startsWith('vin') || name.contains('vinaya')) {
      return ('vinaya', 'Vinaya', 'Luật tạng');
    }
    if (name.startsWith('abh') ||
        name.contains('abhidham') ||
        name.contains('abhidhamma')) {
      return ('abhidhamma', 'Abhidhamma', 'Vi diệu pháp');
    }
    return ('sutta', 'Sutta', 'Kinh tạng');
  }

  static String _languageFromFilename(String path) {
    final name = p.basename(path).toLowerCase();
    const hints = <String, List<String>>{
      'vi': ['vietnamese', 'vietnam', 'viet', '_vi', '-vi'],
      'en': ['english', '_en', '-en'],
      'my': ['myanmar', 'burmese', '_my', '-my'],
      'th': ['thai', '_th', '-th'],
      'si': ['sinhala', '_si', '-si'],
      'zh': ['chinese', '_zh', '-zh'],
      'ja': ['japanese', '_ja', '-ja'],
      'ko': ['korean', '_ko', '-ko'],
      'km': ['khmer', '_km', '-km'],
      'lo': ['lao', '_lo', '-lo'],
      'fr': ['french', '_fr', '-fr'],
      'de': ['german', '_de', '-de'],
      'es': ['spanish', '_es', '-es'],
      'id': ['indonesian', '_id', '-id'],
      'pt': ['portuguese', '_pt', '-pt'],
      'hi': ['hindi', '_hi', '-hi'],
      'bn': ['bengali', '_bn', '-bn'],
      'mr': ['marathi', '_mr', '-mr'],
      'bo': ['tibetan', '_bo', '-bo'],
    };
    for (final entry in hints.entries) {
      if (entry.value.any((hint) => name.contains(hint))) return entry.key;
    }
    if (name.contains('pali') || name.contains('roman')) return 'pi';
    // The first source selected by a user is normally Pāli. For ambiguous
    // names, Pāli is the safest choice because translations require a base DB.
    return 'pi';
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

  static Future<void> _ensureColumn(
    Database db,
    String table,
    String column,
    String type,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info(${_quote(table)})');
    if (columns.any((row) => row['name'] == column)) return;
    await db.execute(
      'ALTER TABLE ${_quote(table)} ADD COLUMN ${_quote(column)} $type',
    );
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
    // These columns let translation packs join rows from the same Pa-Auk
    // source DB without relying on fragile row ordering. ALTER is intentionally
    // best-effort for databases created by older app versions.
    await _ensureColumn(db, 'tipitaka_segments', 'source_table', 'TEXT');
    await _ensureColumn(db, 'tipitaka_segments', 'source_row_key', 'TEXT');

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
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_segments_source '
      'ON tipitaka_segments(source_table, source_row_key)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_translation_language '
      'ON tipitaka_translations(language_code)',
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
