import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart'
    show FlutterError, ValueNotifier, debugPrint;
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

import 'package:in4up/features/tipitaka/models/book.dart';
import 'package:in4up/features/tipitaka/models/collection.dart';
import 'package:in4up/features/tipitaka/models/highlight.dart';
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
  /// Notifies active readers after a language/Pāli pack is atomically installed.
  static final ValueNotifier<int> importRevision = ValueNotifier<int>(0);

  static void _notifyImportChanged() {
    importRevision.value++;
  }

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
    await _recoverInterruptedInstall(installedPath);
    await _cleanupStaleImportFiles(installedPath);
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

  /// Lightweight fingerprint used by Worklist anchors. It changes when the
  /// installed database is replaced without hashing a potentially huge DB on
  /// the UI thread.
  static Future<String> sourceIdentity() async {
    final path = _openPath ?? await installedDatabasePath();
    final file = File(path);
    if (!await file.exists()) return 'tipitaka:missing';
    final stat = await file.stat();
    return 'tipitaka:${p.basename(path)}:${stat.size}:${stat.modified.toUtc().millisecondsSinceEpoch}';
  }

  /// Files placed here can be discovered by the data manager without using a
  /// file picker:
  /// `<application documents>/in4up/tipitaka/imports/`.
  static Future<List<String>> discoverImportFiles({String? directoryPath}) async {
    final directory = directoryPath == null
        ? p.join(
            (await getApplicationDocumentsDirectory()).path,
            _appDirectoryName,
            'imports',
          )
        : directoryPath;
    final folder = Directory(directory);
    if (!await folder.exists()) return const [];
    final files = <String>[];
    await for (final entity in folder.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final extension = p.extension(entity.path).toLowerCase();
      if (const ['.db', '.sqlite', '.sqlite3', '.zip'].contains(extension)) {
        files.add(entity.path);
      }
    }
    files.sort();
    return files;
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
    // IN4-80: đóng connection đang mở trên file đích TRƯỚC khi thay —
    // xoá/rename file khi SQLite còn giữ handle ⇒ SQLITE_READONLY_DBMOVED.
    await close();
    if (await targetFile.exists()) await targetFile.delete();
    await temporary.rename(target);
    return target;
  }

  /// Installs either a normalized DB or a Pa-Auk source DB selected by the
  /// user/developer. Source databases are normalized in-app, so the user does
  /// not need Python just to import a downloaded language package.
  static Future<String> installDatabaseFile(
    String sourcePath, {
    String? destinationPath,
  }) {
    // IN4-80: xếp hàng — cài file cũng thay DB đích, không được chạy song
    // song với import đang chạy (cùng lý do DBMOVED).
    return _withImportLock(() => _installDatabaseFileLocked(
          sourcePath,
          destinationPath: destinationPath,
        ));
  }

  static Future<String> _installDatabaseFileLocked(
    String sourcePath, {
    String? destinationPath,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const TipitakaDatabaseException('Không tìm thấy file cơ sở dữ liệu.');
    }

    if (await _isZipFile(sourcePath)) {
      return _installDatabaseArchive(
        sourcePath,
        destinationPath: destinationPath,
      );
    }

    if (await _isUsableDatabaseFile(sourcePath)) {
      final targetPath = destinationPath ?? await installedDatabasePath();
      if (p.equals(p.normalize(p.absolute(sourcePath)),
          p.normalize(p.absolute(targetPath)))) {
        return targetPath;
      }
      return _mergeNormalizedDatabaseLocked(sourcePath, targetPath);
    }

    // Gọi bản KHÔNG khóa (đang giữ khoá rồi — gọi bản công khai sẽ tự
    // chờ khoá ⇒ DEADLOCK).
    return _importSourceDatabaseLocked(
      sourcePath,
      destinationPath: destinationPath,
    );
  }

  /// A normalized database is merged row-by-row instead of replacing the
  /// installed library. This supports user-created, single-book databases and
  /// preserves previously imported languages and reader annotations.
  static Future<String> _mergeNormalizedDatabaseLocked(
    String sourcePath,
    String targetPath,
  ) async {
    await _recoverInterruptedInstall(targetPath);
    await _cleanupStaleImportFiles(targetPath);
    if (_openPath == targetPath) await close();
    final sourceHash = await _sha256File(File(sourcePath));
    final temporaryPath = _importTemporaryPath(targetPath);
    Database? source;
    Database? target;
    try {
      source = await openDatabase(
        sourcePath,
        readOnly: true,
        singleInstance: false,
      );
      target = await _openImportTarget(targetPath, temporaryPath);
      if (await _wasImportCompleted(target, sourceHash)) {
        await target.close();
        target = null;
        final temporary = File(temporaryPath);
        if (await temporary.exists()) await temporary.delete();
        return targetPath;
      }
      await target.transaction((transaction) async {
        final count = await _mergeNormalizedRows(source!, transaction);
        if (count == 0) {
          throw const TipitakaDatabaseException(
            'Cơ sở dữ liệu không chứa đoạn kinh để nhập.',
          );
        }
        await _deduplicateCatalog(transaction);
        await _recordImport(transaction, sourceHash, sourcePath, count);
        return count;
      });
      final installed = await _installImportTarget(
        target,
        targetPath,
        temporaryPath,
      );
      target = null;
      _notifyImportChanged();
      return installed;
    } catch (_) {
      await target?.close();
      final temporary = File(temporaryPath);
      if (await temporary.exists()) await temporary.delete();
      rethrow;
    } finally {
      await source?.close();
    }
  }

  static Set<String> _catalogEntityNames(Map<String, Object?> row) => {
        for (final column in const ['name_pali', 'name_en', 'name_vi'])
          if ('${row[column] ?? ''}'.trim().isNotEmpty)
            '${row[column]}'.trim().toLowerCase(),
      };


  static Future<int> _mergeNormalizedRows(
    Database source,
    DatabaseExecutor target,
  ) async {
    final sourceCollections = await source.query('tipitaka_collections');
    final targetCollections = await target.query('tipitaka_collections');
    final collectionIdsByName = <String, int>{};
    for (final row in targetCollections) {
      final id = row['id'];
      if (id is! int) continue;
      for (final name in _catalogEntityNames(row)) {
        collectionIdsByName.putIfAbsent(name, () => id);
      }
    }
    final sourceCollectionIds = <int, int>{};
    for (final row in sourceCollections) {
      final sourceId = row['id'];
      if (sourceId is! int) continue;
      final names = _catalogEntityNames(row);
      int? destinationId;
      for (final name in names) {
        destinationId ??= collectionIdsByName[name];
      }
      if (destinationId == null) {
        destinationId = await target.insert('tipitaka_collections', {
          'name_pali': row['name_pali'] ?? '',
          'name_en': row['name_en'] ?? '',
          'name_vi': row['name_vi'] ?? '',
          'order_index': row['order_index'] ?? 0,
        });
      }
      final resolvedDestinationId = destinationId;
      if (resolvedDestinationId == null) continue;
      for (final name in names) {
        collectionIdsByName.putIfAbsent(name, () => resolvedDestinationId);
      }
      sourceCollectionIds[sourceId] = resolvedDestinationId;
    }

    final targetBooks = await target.query('tipitaka_books');
    final booksByCode = <String, int>{};
    for (final row in targetBooks) {
      final id = row['id'];
      final code = '${row['code'] ?? ''}'.trim().toUpperCase();
      if (id is int && code.isNotEmpty) booksByCode.putIfAbsent(code, () => id);
    }
    final sourceBooks = await source.query('tipitaka_books', orderBy: 'order_index, id');
    final sourceBookIds = <int, int>{};
    final sourceBookCodes = <int, String>{};
    final sourceBookRowsById = <int, Map<String, Object?>>{};
    for (final row in sourceBooks) {
      final sourceId = row['id'];
      if (sourceId is! int) continue;
      final code = '${row['code'] ?? ''}'.trim();
      final codeKey = code.toUpperCase();
      final mappedCollection = sourceCollectionIds[row['collection_id']] ??
          (sourceCollectionIds.isEmpty ? 0 : sourceCollectionIds.values.first);
      var destinationId = codeKey.isEmpty ? null : booksByCode[codeKey];
      if (destinationId == null) {
        destinationId = await target.insert('tipitaka_books', {
          'collection_id': mappedCollection,
          'code': code,
          'name_pali': row['name_pali'] ?? '',
          'name_en': row['name_en'] ?? '',
          'name_vi': row['name_vi'] ?? '',
          'order_index': row['order_index'] ?? 0,
          'metadata_json': row['metadata_json'],
        });
        if (codeKey.isNotEmpty) booksByCode[codeKey] = destinationId;
      } else {
        final existing = await target.query(
          'tipitaka_books',
          where: 'id = ?',
          whereArgs: [destinationId],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          final updates = <String, Object?>{};
          for (final column in const ['name_pali', 'name_en', 'name_vi', 'metadata_json']) {
            final current = '${existing.single[column] ?? ''}'.trim();
            final incoming = '${row[column] ?? ''}'.trim();
            if (incoming.isNotEmpty &&
                (current.isEmpty || current.toUpperCase() == codeKey)) {
              updates[column] = row[column];
            }
          }
          if (updates.isNotEmpty) {
            await target.update('tipitaka_books', updates,
                where: 'id = ?', whereArgs: [destinationId]);
          }
        }
      }
      sourceBookIds[sourceId] = destinationId;
      sourceBookCodes[sourceId] = code;
      sourceBookRowsById[sourceId] = row;
    }

    final sourceSegments = await source.query(
      'tipitaka_segments',
      orderBy: 'book_id, order_index, id',
    );
    final existingSegments = await target.query(
      'tipitaka_segments',
      columns: const ['id', 'book_id', 'reference', 'order_index', 'source_table', 'source_row_key'],
    );
    final segmentIds = <String, int>{};
    for (final row in existingSegments) {
      final id = row['id'];
      final bookId = row['book_id'];
      if (id is! int || bookId is! int) continue;
      final table = '${row['source_table'] ?? ''}'.trim();
      final key = '${row['source_row_key'] ?? ''}'.trim();
      if (table.isNotEmpty && key.isNotEmpty) {
        segmentIds['$bookId::${_sourceJoinKey(table, key)}'] = id;
      }
      final reference = '${row['reference'] ?? ''}'.trim();
      if (reference.isNotEmpty) {
        segmentIds['$bookId::ref:${_referenceJoinKey(reference)}::${row['order_index']}'] = id;
      }
    }
    final sourceToTargetSegments = <int, int>{};
    for (final row in sourceSegments) {
      final sourceId = row['id'];
      final sourceBookId = row['book_id'];
      if (sourceId is! int || sourceBookId is! int) continue;
      final bookId = sourceBookIds[sourceBookId];
      if (bookId == null) continue;
      final sourceBook = sourceBookRowsById[sourceBookId] ?? const <String, Object?>{};
      final metadata = sourceBook['metadata_json'];
      var metadataTable = '';
      if (metadata is String && metadata.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(metadata);
          if (decoded is Map && decoded['source_table'] is String) {
            metadataTable = (decoded['source_table'] as String).trim();
          }
        } on FormatException {
          // Fall back to the stable book code below.
        }
      }
      final table = '${row['source_table'] ?? ''}'.trim().isNotEmpty
          ? '${row['source_table']}'.trim()
          : metadataTable.isNotEmpty
              ? metadataTable
              : (sourceBookCodes[sourceBookId] ?? 'BOOK$sourceBookId');
      var sourceRowKey = '${row['source_row_key'] ?? ''}'.trim();
      final reference = '${row['reference'] ?? ''}'.trim();
      final orderIndex = row['order_index'] ?? 0;
      if (sourceRowKey.isEmpty) {
        sourceRowKey = reference.isNotEmpty ? reference : '$orderIndex';
      }
      sourceRowKey = _normalizedSourceRowKey(sourceRowKey);
      final stableKey = '$bookId::${_sourceJoinKey(table, sourceRowKey)}';
      final referenceKey = '$bookId::ref:${_referenceJoinKey(reference)}::$orderIndex';
      final existingId = segmentIds[stableKey] ??
          (reference.isEmpty ? null : segmentIds[referenceKey]);
      final values = <String, Object?>{
        'book_id': bookId,
        'section_id': row['section_id'],
        'reference': reference,
        'paragraph_no': row['paragraph_no'],
        'block_type': row['block_type'] ?? 'paragraph',
        'order_index': orderIndex,
        'source_table': table,
        'source_row_key': sourceRowKey,
      };
      for (final column in const [
        'pali_text', 'translation_en', 'translation_vi',
        'translation_my', 'translation_th',
      ]) {
        final value = row[column];
        if ('${value ?? ''}'.trim().isNotEmpty) values[column] = value;
      }
      int destinationSegmentId;
      if (existingId == null) {
        destinationSegmentId = await target.insert('tipitaka_segments', values);
      } else {
        await target.update(
          'tipitaka_segments',
          values,
          where: 'id = ?',
          whereArgs: [existingId],
        );
        destinationSegmentId = existingId;
      }
      segmentIds[stableKey] = destinationSegmentId;
      sourceToTargetSegments[sourceId] = destinationSegmentId;
    }

    final sourceTables = await source.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'tipitaka_translations'",
    );
    if (sourceTables.isNotEmpty) {
      final translations = await source.query('tipitaka_translations');
      for (final row in translations) {
        final sourceSegmentId = row['segment_id'];
        final language = '${row['language_code'] ?? ''}'
            .trim().toLowerCase().replaceAll('_', '-');
        final text = '${row['text'] ?? ''}';
        final segmentId = sourceToTargetSegments[sourceSegmentId];
        if (segmentId == null || language.isEmpty || text.trim().isEmpty) continue;
        final current = await target.query(
          'tipitaka_translations',
          columns: const ['text'],
          where: 'segment_id = ? AND language_code = ?',
          whereArgs: [segmentId, language],
          limit: 1,
        );
        if (current.isEmpty || '${current.first['text'] ?? ''}'.trim().isEmpty) {
          await target.insert(
            'tipitaka_translations',
            {'segment_id': segmentId, 'language_code': language, 'text': text},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    }
    return sourceToTargetSegments.length;
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

  static Future<String> _installDatabaseArchive(
    String archivePath, {
    String? destinationPath,
  }) async {
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
          // Bản KHÔNG khóa: đang giữ khoá import (bản công khai sẽ chờ
          // khoá ⇒ DEADLOCK).
          return await _installDatabaseFileLocked(
            extractedPath,
            destinationPath: destinationPath,
          );
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

  /// Imports one raw Pa-Auk package without requiring any other language.
  ///
  /// A translation-only package creates a complete, readable normalized
  /// database with an empty Pāli side. Importing Pāli later enriches matching
  /// source rows in place. Every import is built in a temporary copy and
  /// atomically installed, so an interrupted merge cannot damage user data.
  static Future<String> importSourceDatabase(
    String sourcePath, {
    String? languageCode,
    String? destinationPath,
  }) {
    // IN4-80: xếp hàng — 2 import song song làm hỏng DB đích (DBMOVED).
    return _withImportLock(() => _importSourceDatabaseLocked(
          sourcePath,
          languageCode: languageCode,
          destinationPath: destinationPath,
        ));
  }

  static Future<String> _importSourceDatabaseLocked(
    String sourcePath, {
    String? languageCode,
    String? destinationPath,
  }) async {
    await _ensureDatabaseFactory();
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw const TipitakaDatabaseException('Không tìm thấy file nguồn.');
    }

    final targetPath = destinationPath ?? await installedDatabasePath();
    await _recoverInterruptedInstall(targetPath);
    await _cleanupStaleImportFiles(targetPath);
    if (_openPath == targetPath) await close();
    final sourceHash = await _sha256File(sourceFile);
    Database? source;
    try {
      source = await openDatabase(
        sourcePath,
        readOnly: true,
        singleInstance: false,
      );
      final language = (languageCode?.trim().isNotEmpty == true
              ? languageCode!.trim()
              : await _languageFromSourceSchema(source) ??
                  _languageFromFilename(sourcePath))
          .toLowerCase()
          .replaceAll('_', '-')
          .replaceAll('zh-cn', 'zh')
          .replaceAll('zh-hant', 'zh-tw')
          .replaceAll('zh-hk', 'zh-tw');
      return language == 'pi'
          ? await _importPaliSource(
              source,
              targetPath,
              sourceHash: sourceHash,
              sourceName: sourcePath,
            )
          : await _importTranslationSource(
              source,
              language,
              targetPath,
              sourceHash: sourceHash,
              sourceName: sourcePath,
            );
    } on DatabaseException catch (error) {
      throw TipitakaDatabaseException(
        'File không phải SQLite hợp lệ hoặc không thể đọc: $error',
      );
    } finally {
      await source?.close();
    }
  }

  static Future<Database> _openImportTarget(
    String targetPath,
    String temporaryPath,
  ) async {
    final target = File(targetPath);
    final temporary = File(temporaryPath);
    if (await temporary.exists()) await temporary.delete();
    await temporary.parent.create(recursive: true);
    if (await _isUsableDatabaseFile(targetPath)) {
      await target.copy(temporaryPath);
    }
    return openDatabase(
      temporaryPath,
      version: _schemaVersion,
      singleInstance: false,
      onCreate: (db, version) => _createSchema(db),
      onUpgrade: (db, oldVersion, newVersion) => _createSchema(db),
      onOpen: (db) => _ensureSchema(db),
    );
  }

  /// IN4-80: đường dẫn tạm RIÊNG cho mỗi lần import.
  ///
  /// Trước đây MỌI import dùng chung `'$targetPath.importing'` và
  /// `_openImportTarget` XOÁ file tạm nếu tồn tại ⇒ khi 2 import chạy song
  /// song (Pāli + Việt), import thứ hai XOÁ file mà import thứ nhất đang
  /// giữ connection SQLite ⇒ cây lệnh `UPDATE` của import thứ nhất trả
  /// `SQLITE_READONLY_DBMOVED (1032)` ("attempt to write a readonly
  /// database") dù file KHÔNG hỏng.
  static String _importTemporaryPath(String targetPath) =>
      '$targetPath.importing-${DateTime.now().microsecondsSinceEpoch}';

  static Future<String> _sha256File(File file) async =>
      (await sha256.bind(file.openRead()).first).toString();

  static Future<bool> _wasImportCompleted(
    DatabaseExecutor database,
    String hash,
  ) async {
    final rows = await database.query(
      'tipitaka_import_history',
      columns: const ['source_sha256'],
      where: 'source_sha256 = ?',
      whereArgs: [hash],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  static Future<void> _recordImport(
    DatabaseExecutor database,
    String hash,
    String sourceName,
    int importedRows,
  ) async {
    await database.insert(
      'tipitaka_import_history',
      {
        'source_sha256': hash,
        'source_name': p.basename(sourceName),
        'imported_at': DateTime.now().millisecondsSinceEpoch,
        'imported_rows': importedRows,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Recovers the brief rename window used for cross-platform atomic install.
  static Future<void> _recoverInterruptedInstall(String targetPath) async {
    final destination = File(targetPath);
    final swapBackup = File('$targetPath.swap');
    if (!await swapBackup.exists()) return;
    if (!await destination.exists()) {
      await swapBackup.rename(targetPath);
    } else {
      await swapBackup.delete();
    }
  }

  /// A process killed during staging can leave a temporary SQLite copy. It is
  /// never treated as installed data; remove only files older than a day so a
  /// slow, active import is never touched.
  static Future<void> _cleanupStaleImportFiles(String targetPath) async {
    final folder = Directory(p.dirname(targetPath));
    if (!await folder.exists()) return;
    final prefix = '${p.basename(targetPath)}.importing-';
    final cutoff = DateTime.now().subtract(const Duration(days: 1));
    await for (final entity in folder.list(followLinks: false)) {
      if (entity is! File || !p.basename(entity.path).startsWith(prefix)) continue;
      try {
        if ((await entity.stat()).modified.isBefore(cutoff)) {
          await entity.delete();
          for (final suffix in const ['-journal', '-wal', '-shm']) {
            final sidecar = File('${entity.path}$suffix');
            if (await sidecar.exists()) await sidecar.delete();
          }
        }
      } on FileSystemException {
        // A stale staging file is best-effort cleanup, not a read blocker.
      }
    }
  }

  /// Khoá tuần tự hoá import (IN4-80).
  ///
  /// Mọi thao tác import + cài đặt DB đi qua hàng đợi MỘT ⇒ không bao giờ
  /// có 2 import cùng lúc (vừa tránh DBMOVED, vừa tránh 2 install tranh
  /// nhau xoá/đổi file đích).
  static Future<void> _importQueue = Future<void>.value();

  static Future<T> _withImportLock<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    final previous = _importQueue;
    _importQueue = previous.then((_) {}, onError: (_) {}).then((_) async {
      try {
        completer.complete(await action());
      } catch (error, stack) {
        completer.completeError(error, stack);
      }
    });
    return completer.future;
  }

  /// Sao lưu DB đang cài trước khi thay thế (IN4-80: "bảo toàn dữ liệu
  /// trước mọi thao tác phá hủy"). Giữ 1 bản `.bak` — nếu lần import sau hỏng,
  /// người dùng vẫn có DB tốt gần nhất để khôi phục.
  static Future<void> _backupInstalledDatabase(String targetPath) async {
    final source = File(targetPath);
    if (!await source.exists()) return;
    final backup = File('$targetPath.bak');
    try {
      if (await backup.exists()) await backup.delete();
      await source.copy(backup.path);
      debugPrint('💾 Tipitaka: đã sao lưu DB cài đặt → ${backup.path}');
    } catch (error) {
      debugPrint('⚠️ Tipitaka: không sao lưu được DB cài đặt: $error');
    }
  }

  static Future<String> _installImportTarget(
    Database target,
    String targetPath,
    String temporaryPath,
  ) async {
    await target.close();
    await close();
    // IN4-80: sao lưu bản đang chạy TRƯỚC khi thay file đích.
    await _backupInstalledDatabase(targetPath);
    final destination = File(targetPath);
    final swapBackup = File('$targetPath.swap');
    if (await swapBackup.exists()) await swapBackup.delete();
    if (await destination.exists()) await destination.rename(swapBackup.path);
    try {
      await File(temporaryPath).rename(targetPath);
      if (await swapBackup.exists()) await swapBackup.delete();
      return targetPath;
    } catch (_) {
      if (await swapBackup.exists() && !await destination.exists()) {
        await swapBackup.rename(targetPath);
      }
      rethrow;
    }
  }

  static Future<String> _importPaliSource(
    Database source,
    String targetPath, {
    required String sourceHash,
    required String sourceName,
  }) async {
    // IN4-80: đường dẫn tạm RIÊNG (tránh đụng import khác đang chạy).
    final temporaryPath = _importTemporaryPath(targetPath);
    Database? target;
    try {
      target = await _openImportTarget(targetPath, temporaryPath);
      if (await _wasImportCompleted(target, sourceHash)) {
        await target.close();
        target = null;
        final temporary = File(temporaryPath);
        if (await temporary.exists()) await temporary.delete();
        return targetPath;
      }
      await target.transaction((transaction) async {
        final count = await _copyPaliTables(source, transaction);
        if (count == 0) {
          throw const TipitakaDatabaseException(
            'Không tìm thấy bảng văn bản Pāli trong file nguồn.',
          );
        }
        await _deduplicateCatalog(transaction);
        await _recordImport(transaction, sourceHash, sourceName, count);
        return count;
      });
      final installed = await _installImportTarget(
        target,
        targetPath,
        temporaryPath,
      );
      target = null;
      _notifyImportChanged();
      return installed;
    } catch (_) {
      await target?.close();
      final temporary = File(temporaryPath);
      if (await temporary.exists()) await temporary.delete();
      rethrow;
    }
  }

  static Future<String> _importTranslationSource(
    Database source,
    String language,
    String targetPath, {
    required String sourceHash,
    required String sourceName,
  }) async {
    // IN4-80: đường dẫn tạm RIÊNG (tránh đụng import khác đang chạy).
    final temporaryPath = _importTemporaryPath(targetPath);
    Database? target;
    try {
      target = await _openImportTarget(targetPath, temporaryPath);
      if (await _wasImportCompleted(target, sourceHash)) {
        await target.close();
        target = null;
        final temporary = File(temporaryPath);
        if (await temporary.exists()) await temporary.delete();
        return targetPath;
      }
      await target.transaction((transaction) async {
        final count = await _mergeTranslationSource(
          transaction,
          source,
          language,
          createMissing: true,
        );
        if (count == 0) {
          throw TipitakaDatabaseException(
            'Không tìm thấy nội dung cho gói ngôn ngữ $language.',
          );
        }
        await _deduplicateCatalog(transaction);
        await _recordImport(transaction, sourceHash, sourceName, count);
        return count;
      });
      final installed = await _installImportTarget(
        target,
        targetPath,
        temporaryPath,
      );
      target = null;
      _notifyImportChanged();
      return installed;
    } catch (_) {
      await target?.close();
      final temporary = File(temporaryPath);
      if (await temporary.exists()) await temporary.delete();
      rethrow;
    }
  }

  /// Consolidates legacy duplicate catalogue rows before a staged import is
  /// installed. All work happens inside the caller's SQLite transaction.
  static Future<void> _deduplicateCatalog(DatabaseExecutor target) async {
    // Remove the guard while duplicate book IDs are remapped below; SQLite
    // would otherwise reject the FK remap before the duplicate segments can
    // be coalesced. The transaction recreates it after cleanup.
    await target.execute(
      'DROP INDEX IF EXISTS idx_tipitaka_segment_source_unique',
    );
    final collections = await target.query(
      'tipitaka_collections',
      orderBy: 'id ASC',
    );
    final collectionKeepers = <String, int>{};
    for (final collection in collections) {
      final id = collection['id'];
      if (id is! int) continue;
      final names = _catalogEntityNames(collection);
      int? keeper;
      for (final name in names) {
        keeper ??= collectionKeepers[name];
      }
      if (keeper == null) {
        for (final name in names) {
          collectionKeepers.putIfAbsent(name, () => id);
        }
        continue;
      }
      if (keeper != id) {
        await target.update(
          'tipitaka_books',
          {'collection_id': keeper},
          where: 'collection_id = ?',
          whereArgs: [id],
        );
        await target.delete(
          'tipitaka_collections',
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    }

    final books = await target.query('tipitaka_books', orderBy: 'id ASC');
    final bookKeepers = <String, int>{};
    for (final book in books) {
      final id = book['id'];
      if (id is! int) continue;
      final code = '${book['code'] ?? ''}'.trim().toUpperCase();
      if (code.isEmpty) continue;
      final keeper = bookKeepers.putIfAbsent(code, () => id);
      if (keeper == id) continue;
      await target.update(
        'tipitaka_segments',
        {'book_id': keeper},
        where: 'book_id = ?',
        whereArgs: [id],
      );
      await target.delete('tipitaka_books', where: 'id = ?', whereArgs: [id]);
    }

    final sourceRows = await target.query(
      'tipitaka_segments',
      columns: const ['id', 'book_id', 'source_table', 'source_row_key'],
      orderBy: 'id ASC',
    );
    final segmentKeepers = <String, int>{};
    final duplicates = <int, int>{};
    for (final row in sourceRows) {
      final id = row['id'];
      final table = '${row['source_table'] ?? ''}'.trim();
      final sourceKey = '${row['source_row_key'] ?? ''}'.trim();
      if (id is! int || table.isEmpty || sourceKey.isEmpty) continue;
      final joinKey =
          '${row['book_id']}::${_sourceJoinKey(table, sourceKey)}';
      final keeper = segmentKeepers.putIfAbsent(joinKey, () => id);
      if (keeper != id) duplicates[id] = keeper;
    }

    const textColumns = [
      'pali_text', 'translation_en', 'translation_vi', 'translation_my',
      'translation_th',
    ];
    for (final duplicate in duplicates.entries) {
      final row = await target.query(
        'tipitaka_segments',
        where: 'id = ?',
        whereArgs: [duplicate.key],
        limit: 1,
      );
      final keeperRows = await target.query(
        'tipitaka_segments',
        where: 'id = ?',
        whereArgs: [duplicate.value],
        limit: 1,
      );
      if (row.isEmpty || keeperRows.isEmpty) continue;
      final old = row.single;
      final keeper = keeperRows.single;
      final updates = <String, Object?>{};
      for (final column in textColumns) {
        final value = '${keeper[column] ?? ''}'.trim().isEmpty
            ? old[column]
            : keeper[column];
        if (value != keeper[column]) updates[column] = value;
      }
      if (updates.isNotEmpty) {
        await target.update(
          'tipitaka_segments',
          updates,
          where: 'id = ?',
          whereArgs: [duplicate.value],
        );
      }
      final translations = await target.query(
        'tipitaka_translations',
        where: 'segment_id = ?',
        whereArgs: [duplicate.key],
      );
      for (final translation in translations) {
        final language = translation['language_code'];
        final text = '${translation['text'] ?? ''}';
        if (language is! String || text.trim().isEmpty) continue;
        final existing = await target.query(
          'tipitaka_translations',
          columns: const ['text'],
          where: 'segment_id = ? AND language_code = ?',
          whereArgs: [duplicate.value, language],
          limit: 1,
        );
        if (existing.isEmpty || '${existing.first['text'] ?? ''}'.trim().isEmpty) {
          await target.insert(
            'tipitaka_translations',
            {'segment_id': duplicate.value, 'language_code': language, 'text': text},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
      await target.rawUpdate(
        'UPDATE OR IGNORE tipitaka_highlights SET segment_id = ? WHERE segment_id = ?',
        [duplicate.value, duplicate.key],
      );
      await target.rawUpdate(
        'UPDATE tipitaka_user_notes SET segment_id = ? WHERE segment_id = ?',
        [duplicate.value, duplicate.key],
      );
      await target.rawUpdate(
        'UPDATE OR IGNORE tipitaka_learning_items SET segment_id = ? WHERE segment_id = ?',
        [duplicate.value, duplicate.key],
      );
      await target.delete(
        'tipitaka_translations',
        where: 'segment_id = ?',
        whereArgs: [duplicate.key],
      );
      await target.delete(
        'tipitaka_highlights',
        where: 'segment_id = ?',
        whereArgs: [duplicate.key],
      );
      await target.delete(
        'tipitaka_learning_items',
        where: 'segment_id = ?',
        whereArgs: [duplicate.key],
      );
      await target.delete(
        'tipitaka_segments',
        where: 'id = ?',
        whereArgs: [duplicate.key],
      );
    }
    await target.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_tipitaka_segment_source_unique '
      'ON tipitaka_segments(book_id, lower(source_table), source_row_key) '
      "WHERE source_table IS NOT NULL AND source_table <> '' "
      "AND source_row_key IS NOT NULL AND source_row_key <> ''",
    );
  }

  static Future<Map<String, int>> _collectionIds(DatabaseExecutor target) async {
    final result = <String, int>{};
    for (final row in await target.query('tipitaka_collections')) {
      final id = row['id'];
      if (id is! int) continue;
      final names = '${row['name_pali']} ${row['name_en']} ${row['name_vi']}'
          .toLowerCase();
      if (names.contains('vin') || names.contains('luật')) {
        result['vinaya'] = id;
      } else if (names.contains('abh') || names.contains('diệu')) {
        result['abhidhamma'] = id;
      } else {
        result['sutta'] = id;
      }
    }
    return result;
  }

  static Future<int> _ensureCollection(
    DatabaseExecutor target,
    Map<String, int> collectionIds,
    String sourceTable,
  ) async {
    final collection = _collectionForTable(sourceTable);
    final existing = collectionIds[collection.$1];
    if (existing != null) return existing;
    final id = await target.insert('tipitaka_collections', {
      'name_pali': collection.$2,
      'name_en': collection.$2,
      'name_vi': collection.$3,
      'order_index': collectionIds.length + 1,
    });
    collectionIds[collection.$1] = id;
    return id;
  }

  static Future<Map<String, int>> _bookIds(DatabaseExecutor target) async {
    return {
      for (final row in await target.query('tipitaka_books'))
        if (row['id'] is int) '${row['code'] ?? ''}'.toUpperCase(): row['id'] as int,
    };
  }

  static Future<int> _ensureBook(
    DatabaseExecutor target,
    Map<String, int> collectionIds,
    Map<String, int> bookIds,
    String sourceTable,
  ) async {
    final code = _bookCode(sourceTable);
    final existing = bookIds[code];
    if (existing != null) return existing;
    final collectionId = await _ensureCollection(
      target,
      collectionIds,
      sourceTable,
    );
    final id = await target.insert('tipitaka_books', {
      'collection_id': collectionId,
      'code': code,
      'name_pali': '',
      'name_en': _bookDisplayName(sourceTable),
      'name_vi': _bookDisplayName(sourceTable),
      'order_index': bookIds.length + 1,
      'metadata_json':
          '{"source":"Pa-Auk","source_table":"$sourceTable"}',
    });
    bookIds[code] = id;
    return id;
  }

  static Future<int> _copyPaliTables(
    Database source,
    DatabaseExecutor target,
  ) async {
    final tables = await _sourceTables(source, textLanguage: 'pi');
    final collectionIds = await _collectionIds(target);
    final bookIds = await _bookIds(target);
    final targetRows = await target.query(
      'tipitaka_segments',
      columns: const ['id', 'source_table', 'source_row_key', 'reference'],
    );
    final targetBySource = <String, int>{};
    final targetByReference = <String, int>{};
    for (final row in targetRows) {
      final id = row['id'];
      if (id is! int) continue;
      final table = '${row['source_table'] ?? ''}';
      final key = '${row['source_row_key'] ?? ''}';
      if (table.isNotEmpty && key.isNotEmpty) {
        targetBySource[_sourceJoinKey(table, key)] = id;
      }
      final reference = '${row['reference'] ?? ''}';
      if (reference.isNotEmpty) targetByReference.putIfAbsent(_referenceJoinKey(reference), () => id);
    }

    var imported = 0;
    for (final table in tables) {
      final columns = await _sourceColumns(source, table);
      final textColumn = _findSourceColumn(columns, const [
        'pali_text', 'pali', 'roman', 'text', 'content', 'paragraph', 'body',
        'html', 'xml', 'data',
      ]);
      if (textColumn == null) continue;
      final rowCount = await _sourceRowCount(source, table);
      if (rowCount == 0) continue;
      final bookId = await _ensureBook(
        target,
        collectionIds,
        bookIds,
        table,
      );
      final keyColumn = _findSourceColumn(columns, const [
        'id', 'rowid', 'code', 'paragraph_id', 'segment_id', 'para_id',
        'seq', 'number',
      ]);
      final referenceColumn = _findSourceColumn(columns, const [
        'reference', 'ref', 'citation', 'section_ref', 'book_code',
      ]);
      final paragraphColumn = _findSourceColumn(columns, const [
        'paragraph_no', 'paragraph_number', 'para', 'line_no', 'segment_no',
        'number',
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
      String? contentTitle;
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
          final reference = _plainText(row['_reference']).trim().isEmpty
              ? '$table:$key'
              : _plainText(row['_reference']).trim();
          final rawText = row['_text'];
          final text = _plainText(rawText);
          final kind = _blockType(rawText);
          if (contentTitle == null &&
              const ['book', 'chapter'].contains(kind) &&
              text.isNotEmpty) {
            contentTitle = text;
          }
          final segmentId = targetBySource[_sourceJoinKey(table, key)] ??
              targetByReference[_referenceJoinKey(reference)];
          final values = {
            'book_id': bookId,
            'reference': reference,
            'paragraph_no': _asInt(row['_paragraph'], offset + index + 1),
            'block_type': kind,
            'pali_text': text,
            'order_index': offset + index,
            'source_table': table,
            'source_row_key': _normalizedSourceRowKey(key),
          };
          if (segmentId == null) {
            batch.insert('tipitaka_segments', values);
          } else {
            batch.update(
              'tipitaka_segments',
              values,
              where: 'id = ?',
              whereArgs: [segmentId],
            );
          }
          imported++;
        }
        await batch.commit(noResult: true);
      }
      if (contentTitle != null) {
        await target.update(
          'tipitaka_books',
          {'name_pali': contentTitle},
          where: 'id = ?',
          whereArgs: [bookId],
        );
      }
    }
    return imported;
  }

  static Future<int> _mergeTranslationSource(
    DatabaseExecutor target,
    Database source,
    String language, {
    bool createMissing = false,
  }) async {
    final tables = await _sourceTables(source, textLanguage: language);
    final fixedColumn = const {
      'en': 'translation_en',
      'vi': 'translation_vi',
      'my': 'translation_my',
      'th': 'translation_th',
    }[language];
    final collectionIds = await _collectionIds(target);
    final bookIds = await _bookIds(target);
    final targetRows = await target.query(
      'tipitaka_segments',
      columns: const ['id', 'source_table', 'source_row_key', 'reference'],
    );
    final targetBySource = <String, int>{};
    final targetByReference = <String, int>{};
    for (final row in targetRows) {
      final id = row['id'];
      if (id is! int) continue;
      final table = '${row['source_table'] ?? ''}';
      final key = '${row['source_row_key'] ?? ''}';
      if (table.isNotEmpty && key.isNotEmpty) {
        targetBySource[_sourceJoinKey(table, key)] = id;
      }
      final reference = '${row['reference'] ?? ''}';
      if (reference.isNotEmpty) targetByReference.putIfAbsent(_referenceJoinKey(reference), () => id);
    }

    var updated = 0;
    for (final table in tables) {
      final columns = await _sourceColumns(source, table);
      final textColumn = _findSourceColumn(
        columns,
        _translationTextCandidates(language),
      );
      if (textColumn == null) continue;
      final keyColumn = _findSourceColumn(columns, const [
        'id', 'rowid', 'code', 'paragraph_id', 'segment_id', 'ref_id',
        'pali_id', 'text_id', 'para_id', 'seq', 'number',
      ]);
      final referenceColumn = _findSourceColumn(columns, const [
        'reference', 'ref', 'citation', 'section_ref', 'book_code',
      ]);
      final paragraphColumn = _findSourceColumn(columns, const [
        'paragraph_no', 'paragraph_number', 'para', 'line_no', 'segment_no',
        'number',
      ]);
      final sourceTableColumn = _findSourceColumn(columns, const [
        'source_table', 'table', 'book', 'book_code', 'document',
      ]);
      final keyExpression = keyColumn == null ? 'rowid' : _quote(keyColumn);
      final referenceExpression = referenceColumn == null
          ? 'NULL'
          : _quote(referenceColumn);
      final paragraphExpression = paragraphColumn == null
          ? keyExpression
          : _quote(paragraphColumn);
      final sourceTableExpression = sourceTableColumn == null
          ? 'NULL'
          : _quote(sourceTableColumn);
      final select = 'SELECT $keyExpression AS _source_key, '
          '$referenceExpression AS _reference, '
          '$paragraphExpression AS _paragraph, '
          '$sourceTableExpression AS _source_table, '
          '${_quote(textColumn)} AS _text FROM ${_quote(table)}';
      final rowCount = await _sourceRowCount(source, table);
      final titles = <int, String>{};
      for (var offset = 0; offset < rowCount; offset += 500) {
        final rows = await source.rawQuery(
          '$select LIMIT ? OFFSET ?',
          [500, offset],
        );
        if (rows.isEmpty) break;
        for (var index = 0; index < rows.length; index++) {
          final row = rows[index];
          final key = '${row['_source_key'] ?? offset + index + 1}';
          final sourceTable = _plainText(row['_source_table']).trim();
          final effectiveTable = sourceTable.isEmpty ? table : sourceTable;
          final rawText = row['_text'];
          final text = _plainText(rawText);
          if (text.isEmpty) continue;
          final reference = _plainText(row['_reference']).trim().isEmpty
              ? '$effectiveTable:$key'
              : _plainText(row['_reference']).trim();
          var segmentId = targetBySource[_sourceJoinKey(effectiveTable, key)] ??
              targetByReference[_referenceJoinKey(reference)];
          int? bookId;
          if (segmentId == null && createMissing) {
            bookId = await _ensureBook(
              target,
              collectionIds,
              bookIds,
              effectiveTable,
            );
            final values = <String, Object?>{
              'book_id': bookId,
              'reference': reference,
              'paragraph_no': _asInt(row['_paragraph'], offset + index + 1),
              'block_type': _blockType(rawText),
              'pali_text': '',
              'order_index': offset + index,
              'source_table': effectiveTable,
              'source_row_key': _normalizedSourceRowKey(key),
              if (fixedColumn != null) fixedColumn: text,
            };
            segmentId = await target.insert('tipitaka_segments', values);
            targetBySource[_sourceJoinKey(effectiveTable, key)] = segmentId;
            targetByReference.putIfAbsent(
              _referenceJoinKey(reference),
              () => segmentId!,
            );
          }
          if (segmentId == null) continue;
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
          if (bookId != null &&
              const ['book', 'chapter'].contains(_blockType(rawText))) {
            titles.putIfAbsent(bookId, () => text);
          }
          updated++;
        }
      }
      final titleColumn = language == 'vi'
          ? 'name_vi'
          : language == 'en'
              ? 'name_en'
              : null;
      if (titleColumn != null) {
        for (final entry in titles.entries) {
          await target.update(
            'tipitaka_books',
            {titleColumn: entry.value},
            where: 'id = ?',
            whereArgs: [entry.key],
          );
        }
      }
    }
    return updated;
  }

  static List<String> _translationTextCandidates(String language) {
    const languageNames = <String, List<String>>{
      'ar': ['arabic', 'العربية'],
      'bn': ['bengali', 'bangla'],
      'bo': ['tibetan'],
      'de': ['german', 'deutsch'],
      'en': ['english', 'en'],
      'es': ['spanish', 'espanol'],
      'fr': ['french', 'francais'],
      'hi': ['hindi'],
      'id': ['indonesian', 'bahasa'],
      'it': ['italian', 'italiano'],
      'ja': ['japanese'],
      'km': ['khmer', 'cambodian'],
      'ko': ['korean'],
      'lo': ['lao'],
      'mn': ['mongolian'],
      'mr': ['marathi'],
      'my': ['myanmar', 'burmese', 'my'],
      'pt': ['portuguese'],
      'ru': ['russian'],
      'si': ['sinhala'],
      'ta': ['tamil'],
      'te': ['telugu'],
      'th': ['thai', 'th'],
      'vi': ['vietnamese', 'vietnam', 'vi'],
      'zh': ['chinese', 'simplifiedchinese'],
      'zh-tw': ['traditionalchinese', 'taiwanese', 'zh_tw'],
    };
    return [
      'translation',
      'translated',
      'translated_text',
      'translation_text',
      ...?languageNames[language],
      'text',
      'content',
      'paragraph',
      'body',
      'html',
      'xml',
      'data',
    ];
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
            'pali_text', 'pali', 'roman', 'text', 'content', 'paragraph', 'body',
            'html', 'xml', 'data',
          ]
        : _translationTextCandidates(textLanguage);
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

  /// Stable join key for source packs whose table names differ only by case,
  /// underscores, or spacing. Numeric row IDs also ignore zero-padding.
  static String _sourceJoinKey(String table, String key) {
    final trimmedKey = key.trim();
    final numericKey = int.tryParse(trimmedKey);
    final normalizedKey = numericKey?.toString() ??
        trimmedKey.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    return '${_normalizeName(table)}::$normalizedKey';
  }

  static String _normalizedSourceRowKey(String key) {
    final trimmed = key.trim();
    return int.tryParse(trimmed)?.toString() ??
        trimmed.replaceAll(RegExp(r'\s+'), ' ');
  }

  /// References are compared case-insensitively with whitespace collapsed;
  /// punctuation remains significant to avoid joining different citations.
  static String _referenceJoinKey(String reference) =>
      _plainText(reference).trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static String _quote(String value) => '"${value.replaceAll('"', '""')}"';

  static int _asInt(Object? value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? fallback;
  }

  static String _blockType(Object? value) {
    final raw = '$value'.toLowerCase();
    if (raw.contains('rend="book"') || raw.contains("rend='book'")) {
      return 'book';
    }
    if (raw.contains('rend="chapter"') || raw.contains("rend='chapter'")) {
      return 'chapter';
    }
    if (raw.contains('rend="subhead"') ||
        raw.contains('rend="heading"') ||
        raw.contains("rend='subhead'") ||
        raw.contains("rend='heading'")) {
      return 'heading';
    }
    if (raw.contains('rend="centre"') ||
        raw.contains('rend="center"') ||
        raw.contains("rend='centre'") ||
        raw.contains("rend='center'")) {
      return 'center';
    }
    return 'paragraph';
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

  static String _bookCode(String table) => table
      .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '')
      .toUpperCase();

  static String _bookDisplayName(String table) {
    final name = table.toLowerCase();
    const nikayaNames = <String, String>{
      'vin': 'Vinaya',
      'dn': 'Dīgha Nikāya',
      'mn': 'Majjhima Nikāya',
      'sn': 'Saṃyutta Nikāya',
      'an': 'Aṅguttara Nikāya',
      'khp': 'Khuddakapāṭha',
      'dhp': 'Dhammapada',
    };
    for (final entry in nikayaNames.entries) {
      final match = RegExp('^${entry.key}(\\d+)').firstMatch(name);
      if (match == null) continue;
      final number = match.group(1)!;
      final suffix = name
          .substring(match.end)
          .replaceFirst(RegExp(r'^[_-]'), '')
          .replaceFirst(RegExp(r'^[mat]_'), '');
      final suffixName = suffix
          .replaceAll(RegExp(r'^m$'), 'Mūla')
          .replaceAll(RegExp(r'^a$'), 'Aṭṭhakathā')
          .replaceAll(RegExp(r'^t$'), 'Ṭīkā')
          .replaceAll('mul', 'Mūla')
          .replaceAll('att', 'Aṭṭhakathā')
          .replaceAll('tik', 'Ṭīkā');
      return '${entry.value} $number${suffixName.isEmpty ? '' : ' · $suffixName'}';
    }
    return table
        .split(RegExp(r'[_-]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
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

  /// Detects language packs even when a user renamed the downloaded `.db`.
  /// Prefer explicit language names/codes in source tables or columns; use the
  /// filename only when the schema contains generic text columns.
  static Future<String?> _languageFromSourceSchema(Database source) async {
    const hints = <String, List<String>>{
      'ar': ['arabic', 'translationar'],
      'bn': ['bengali', 'bangla', 'translationbn'],
      'bo': ['tibetan', 'translationbo'],
      'de': ['german', 'deutsch', 'translationde'],
      'en': ['english', 'translationen'],
      'es': ['spanish', 'espanol', 'translationes'],
      'fr': ['french', 'francais', 'translationfr'],
      'hi': ['hindi', 'translationhi'],
      'id': ['indonesian', 'bahasa', 'translationid'],
      'it': ['italian', 'italiano', 'translationit'],
      'ja': ['japanese', 'translationja'],
      'km': ['khmer', 'cambodian', 'translationkm'],
      'ko': ['korean', 'translationko'],
      'lo': ['lao', 'translationlo'],
      'mn': ['mongolian', 'translationmn'],
      'mr': ['marathi', 'translationmr'],
      'my': ['myanmar', 'burmese', 'translationmy'],
      'pt': ['portuguese', 'translationpt'],
      'ru': ['russian', 'translationru'],
      'si': ['sinhala', 'translation si'],
      'ta': ['tamil', 'translationta'],
      'te': ['telugu', 'translationte'],
      'th': ['thai', 'translationth'],
      'vi': ['vietnamese', 'vietnam', 'viet', 'translationvi'],
      'zh': ['simplifiedchinese', 'chinese', 'translationzh'],
      'zh-tw': ['traditionalchinese', 'taiwanese', 'translationzhtw'],
      'pi': ['pali', 'roman'],
    };
    bool matches(String candidate, String hint) {
      final normalizedCandidate = _normalizeName(candidate);
      final normalizedHint = _normalizeName(hint);
      // Two-letter language codes are accepted only as complete identifiers;
      // matching `it` inside `citation` would misclassify a generic database.
      if (normalizedHint.length <= 2) return normalizedCandidate == normalizedHint;
      return normalizedCandidate.contains(normalizedHint);
    }

    final tables = await _sourceTables(source);
    for (final table in tables) {
      for (final entry in hints.entries) {
        if (entry.value.any((hint) => matches(table, hint))) return entry.key;
      }
      for (final column in await _sourceColumns(source, table)) {
        for (final entry in hints.entries) {
          if (entry.value.any((hint) => matches(column, hint))) return entry.key;
        }
      }
    }
    return null;
  }

  static String _languageFromFilename(String path) {
    final name = p.basename(path).toLowerCase().replaceAll(' ', '_');
    const hints = <String, List<String>>{
      'ar': ['arabic', '_ar', '-ar'],
      'bn': ['bengali', 'bangla', '_bn', '-bn'],
      'bo': ['tibetan', '_bo', '-bo'],
      'de': ['german', 'deutsch', '_de', '-de'],
      'en': ['english', '_en', '-en'],
      'es': ['spanish', '_es', '-es'],
      'fr': ['french', '_fr', '-fr'],
      'hi': ['hindi', '_hi', '-hi'],
      'id': ['indonesian', '_id', '-id'],
      'it': ['italian', '_it', '-it'],
      'ja': ['japanese', '_ja', '-ja'],
      'km': ['khmer', '_km', '-km'],
      'ko': ['korean', '_ko', '-ko'],
      'lo': ['lao', '_lo', '-lo'],
      'mn': ['mongolian', '_mn', '-mn'],
      'mr': ['marathi', '_mr', '-mr'],
      'my': ['myanmar', 'burmese', '_my', '-my'],
      'pt': ['portuguese', '_pt', '-pt'],
      'ru': ['russian', '_ru', '-ru'],
      'si': ['sinhala', '_si', '-si'],
      'ta': ['tamil', '_ta', '-ta'],
      'te': ['telugu', '_te', '-te'],
      'th': ['thai', '_th', '-th'],
      'vi': ['vietnamese', 'vietnam', 'viet', '_vi', '-vi'],
      'zh-tw': ['traditional_chinese', 'zh_tw', 'zh-tw', '_tw'],
      'zh': ['simplified_chinese', 'chinese', '_zh', '-zh'],
    };
    for (final entry in hints.entries) {
      if (entry.value.any((hint) => name.contains(hint))) return entry.key;
    }
    if (name.contains('pali') || name.contains('roman')) return 'pi';
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
      if (!counts.every((rows) => (rows.first['n'] as int? ?? 0) > 0)) {
        return false;
      }
      final columns = await db.rawQuery('PRAGMA table_info(tipitaka_segments)');
      final columnNames = columns.map((row) => row['name'] as String).toSet();
      final contentChecks = <String>[
        if (columnNames.contains('pali_text')) "COALESCE(pali_text, '') <> ''",
        if (columnNames.contains('translation_vi')) "COALESCE(translation_vi, '') <> ''",
        if (columnNames.contains('translation_en')) "COALESCE(translation_en, '') <> ''",
        if (columnNames.contains('translation_my')) "COALESCE(translation_my, '') <> ''",
        if (columnNames.contains('translation_th')) "COALESCE(translation_th, '') <> ''",
      ];
      final fixedContent = contentChecks.isEmpty
          ? const <Map<String, Object?>>[]
          : await db.rawQuery(
              'SELECT 1 FROM tipitaka_segments WHERE '
              '${contentChecks.join(' OR ')} LIMIT 1',
            );
      if (fixedContent.isNotEmpty) return true;
      if (!names.contains('tipitaka_translations')) return false;
      final extraContent = await db.rawQuery(
        "SELECT 1 FROM tipitaka_translations WHERE text <> '' LIMIT 1",
      );
      return extraContent.isNotEmpty;
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
      CREATE TABLE IF NOT EXISTS tipitaka_import_history (
        source_sha256 TEXT PRIMARY KEY,
        source_name TEXT NOT NULL DEFAULT '',
        imported_at INTEGER NOT NULL,
        imported_rows INTEGER NOT NULL DEFAULT 0
      )
    ''');
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
        block_type TEXT NOT NULL DEFAULT 'paragraph',
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
    await _ensureColumn(
      db,
      'tipitaka_segments',
      'block_type',
      "TEXT NOT NULL DEFAULT 'paragraph'",
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS tipitaka_translations (
        segment_id INTEGER NOT NULL,
        language_code TEXT NOT NULL,
        text TEXT NOT NULL DEFAULT '',
        PRIMARY KEY(segment_id, language_code)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tipitaka_highlights (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id INTEGER NOT NULL,
        segment_id INTEGER NOT NULL,
        color TEXT NOT NULL DEFAULT 'yellow',
        note TEXT NOT NULL DEFAULT '',
        updated_at INTEGER NOT NULL,
        UNIQUE(book_id, segment_id)
      )
    ''');
    await _ensureColumn(db, 'tipitaka_highlights', 'book_id', 'INTEGER');
    await _ensureColumn(db, 'tipitaka_highlights', 'segment_id', 'INTEGER');
    await _ensureColumn(
      db, 'tipitaka_highlights', 'color', "TEXT NOT NULL DEFAULT 'yellow'",
    );
    await _ensureColumn(
      db, 'tipitaka_highlights', 'note', "TEXT NOT NULL DEFAULT ''",
    );
    await _ensureColumn(
      db, 'tipitaka_highlights', 'updated_at', 'INTEGER NOT NULL DEFAULT 0',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_tipitaka_highlight_segment '
      'ON tipitaka_highlights(book_id, segment_id)',
    );

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
    final languages = <String>{};
    final columns = await db.rawQuery('PRAGMA table_info(tipitaka_segments)');
    final columnNames = columns.map((row) => row['name'] as String).toSet();
    const fixedLanguages = {
      'pali_text': 'pi',
      'translation_vi': 'vi',
      'translation_en': 'en',
      'translation_my': 'my',
      'translation_th': 'th',
    };
    for (final entry in fixedLanguages.entries) {
      if (columnNames.contains(entry.key) && await _hasText(db, entry.key)) {
        languages.add(entry.value);
      }
    }
    final extraLanguages = await db.rawQuery(
      'SELECT DISTINCT language_code FROM tipitaka_translations '
      'WHERE text <> \'\'',
    );
    languages.addAll(
      extraLanguages
          .map((row) => '${row['language_code'] ?? ''}'
              .trim()
              .toLowerCase()
              .replaceAll('_', '-'))
          .where((code) => code.isNotEmpty),
    );
    if (languages.any((code) => code == 'pi' || code.startsWith('pi-'))) {
      languages.add('pi');
    }
    var fileLength = 0;
    final path = _openPath;
    if (path != null && path.isNotEmpty && await File(path).exists()) {
      fileLength = await File(path).length();
    }
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

  /// Small, title-free index used to decide which catalogue branches exist.
  /// Full content-derived titles remain lazily loaded when a branch is opened.
  static Future<List<TipitakaBook>> getCatalogIndexBooks(Database db) async {
    final rows = await db.query('tipitaka_books', orderBy: 'order_index, id');
    return rows.map(TipitakaBook.fromMap).toList();
  }

  static Future<List<TipitakaBook>> getBooksByCollection(
    Database db,
    int collectionId, {
    String languageCode = 'en',
  }) async {
    final language = languageCode.trim().toLowerCase().replaceAll('_', '-');
    final localeColumn = const {
      'pi': 'pali_text',
      'en': 'translation_en',
      'vi': 'translation_vi',
      'my': 'translation_my',
      'th': 'translation_th',
    }[language];
    final dynamicTitleSql = '''
      (SELECT NULLIF(TRIM(lt.text), '')
         FROM tipitaka_segments ls
         JOIN tipitaka_translations lt ON lt.segment_id = ls.id
        WHERE ls.book_id = b.id
          AND LOWER(REPLACE(lt.language_code, '_', '-')) = ?
          AND ${_outlineSql('ls')}
        ORDER BY ls.order_index, ls.id LIMIT 1)
    ''';
    final localeTitleSql = localeColumn == null
        ? dynamicTitleSql
        : '''COALESCE(
            (SELECT NULLIF(TRIM(ls.$localeColumn), '')
               FROM tipitaka_segments ls
              WHERE ls.book_id = b.id AND ${_outlineSql('ls')}
              ORDER BY ls.order_index, ls.id LIMIT 1),
            $dynamicTitleSql
          )''';
    final arguments = <Object?>[language, collectionId];
    final rows = await db.rawQuery('''
      SELECT b.*,
        (SELECT NULLIF(TRIM(s.pali_text), '')
           FROM tipitaka_segments s
          WHERE s.book_id = b.id AND ${_outlineSql('s')}
          ORDER BY s.order_index, s.id LIMIT 1) AS _content_title_pali,
        (SELECT NULLIF(TRIM(s.translation_en), '')
           FROM tipitaka_segments s
          WHERE s.book_id = b.id AND ${_outlineSql('s')}
          ORDER BY s.order_index, s.id LIMIT 1) AS _content_title_en,
        (SELECT NULLIF(TRIM(s.translation_vi), '')
           FROM tipitaka_segments s
          WHERE s.book_id = b.id AND ${_outlineSql('s')}
          ORDER BY s.order_index, s.id LIMIT 1) AS _content_title_vi,
        $localeTitleSql AS _content_title_locale
      FROM tipitaka_books b
      WHERE b.collection_id = ?
      ORDER BY b.order_index ASC, b.id ASC
    ''', arguments);
    return rows.map(TipitakaBook.fromMap).toList();
  }

  static String _outlineSql(String alias) =>
      "($alias.block_type IN ('book','chapter','heading','center') OR "
      "$alias.pali_text LIKE '%rend=\"book\"%' OR "
      "$alias.pali_text LIKE '%rend=\"chapter\"%' OR "
      "$alias.pali_text LIKE '%rend=\"subhead\"%' OR "
      "$alias.pali_text LIKE '%rend=\"heading\"%')";

  /// Looks up a single book by id. Search results use this to deep-link
  /// straight into the reader workspace. Content titles are derived with the
  /// same outline subqueries as the catalogue so
  /// [TipitakaBook.displayTitle] stays consistent.
  static Future<TipitakaBook?> getBookById(
    Database db,
    int bookId, {
    String languageCode = 'en',
  }) async {
    final language = languageCode.trim().toLowerCase().replaceAll('_', '-');
    final fixedColumn = const {
      'pi': 'pali_text',
      'en': 'translation_en',
      'vi': 'translation_vi',
      'my': 'translation_my',
      'th': 'translation_th',
    }[language];
    final dynamicTitle = '''
      (SELECT NULLIF(TRIM(lt.text), '')
         FROM tipitaka_segments ls
         JOIN tipitaka_translations lt ON lt.segment_id = ls.id
        WHERE ls.book_id = b.id
          AND LOWER(REPLACE(lt.language_code, '_', '-')) = ?
          AND ${_outlineSql('ls')}
        ORDER BY ls.order_index, ls.id LIMIT 1)
    ''';
    final localeTitle = fixedColumn == null
        ? dynamicTitle
        : '''COALESCE(
            (SELECT NULLIF(TRIM(ls.$fixedColumn), '')
               FROM tipitaka_segments ls
              WHERE ls.book_id = b.id AND ${_outlineSql('ls')}
              ORDER BY ls.order_index, ls.id LIMIT 1),
            $dynamicTitle
          )''';
    final rows = await db.rawQuery('''
      SELECT b.*,
        (SELECT NULLIF(TRIM(s.pali_text), '')
           FROM tipitaka_segments s
          WHERE s.book_id = b.id AND ${_outlineSql('s')}
          ORDER BY s.order_index, s.id LIMIT 1) AS _content_title_pali,
        (SELECT NULLIF(TRIM(s.translation_en), '')
           FROM tipitaka_segments s
          WHERE s.book_id = b.id AND ${_outlineSql('s')}
          ORDER BY s.order_index, s.id LIMIT 1) AS _content_title_en,
        (SELECT NULLIF(TRIM(s.translation_vi), '')
           FROM tipitaka_segments s
          WHERE s.book_id = b.id AND ${_outlineSql('s')}
          ORDER BY s.order_index, s.id LIMIT 1) AS _content_title_vi,
        $localeTitle AS _content_title_locale
      FROM tipitaka_books b
      WHERE b.id = ?
      LIMIT 1
    ''', [language, bookId]);
    if (rows.isEmpty) return null;
    return TipitakaBook.fromMap(rows.first);
  }

  static Future<List<Map<String, dynamic>>> _withTranslations(
    Database db,
    List<Map<String, Object?>> rows,
  ) async {
    if (rows.isEmpty) return const [];
    final ids = rows.map((row) => row['id']).whereType<int>().toList();
    final placeholders = List.filled(ids.length, '?').join(',');
    final translations = await db.rawQuery(
      'SELECT segment_id, language_code, text FROM tipitaka_translations '
      'WHERE segment_id IN ($placeholders)',
      ids,
    );
    final bySegment = <int, Map<String, String>>{};
    for (final row in translations) {
      final segmentId = row['segment_id'];
      final language = row['language_code'];
      final text = row['text'];
      if (segmentId is int && language is String && text is String) {
        bySegment.putIfAbsent(segmentId, () => {})[language] = text;
      }
    }
    return [
      for (final row in rows)
        <String, dynamic>{
          ...row,
          'translations': bySegment[row['id']] ?? const <String, String>{},
        },
    ];
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
    final enriched = await _withTranslations(db, rows);
    return enriched.map(TipitakaSegment.fromMap).toList();
  }

  /// Detailed table of contents. Structural rows are real content headings;
  /// references/table codes are never promoted to the visible title.
  static Future<List<TipitakaSegment>> getBookOutline(
    Database db,
    int bookId,
  ) async {
    var rows = await db.query(
      'tipitaka_segments',
      where: 'book_id = ? AND ${_outlineSql('tipitaka_segments')}',
      whereArgs: [bookId],
      orderBy: 'order_index ASC, paragraph_no ASC, id ASC',
      limit: 600,
    );
    if (rows.isEmpty) {
      // Legacy/demo DBs may not have structural metadata. A sparse sample still
      // gives a useful in-article navigator without exposing technical IDs.
      final sample = await db.query(
        'tipitaka_segments',
        where: "book_id = ? AND (pali_text <> '' OR translation_vi <> '' "
            "OR translation_en <> '')",
        whereArgs: [bookId],
        orderBy: 'order_index ASC, id ASC',
        limit: 300,
      );
      rows = [
        for (var index = 0; index < sample.length; index++)
          if (index == 0 || index % 40 == 0) sample[index],
      ];
    }
    final enriched = await _withTranslations(db, rows);
    return enriched.map(TipitakaSegment.fromMap).toList();
  }

  /// Returns annotations whose book and segment still exist and agree.
  /// Orphan rows left by a replaced database are deliberately hidden.
  static Future<List<TipitakaHighlight>> getHighlights(
    Database db, {
    int? bookId,
  }) async {
    final rows = await db.rawQuery('''
      SELECT h.*, s.reference,
             COALESCE(NULLIF(s.pali_text, ''),
               (SELECT NULLIF(t.text, '') FROM tipitaka_translations t
                 WHERE t.segment_id = s.id
                   AND LOWER(REPLACE(t.language_code, '_', '-')) = 'pi'
                 LIMIT 1), '') AS pali_text,
             COALESCE(NULLIF(s.translation_vi, ''),
                      NULLIF(s.translation_en, ''),
               (SELECT NULLIF(t.text, '') FROM tipitaka_translations t
                 WHERE t.segment_id = s.id
                   AND LOWER(REPLACE(t.language_code, '_', '-')) = 'vi'
                 LIMIT 1),
               (SELECT NULLIF(t.text, '') FROM tipitaka_translations t
                 WHERE t.segment_id = s.id
                   AND LOWER(REPLACE(t.language_code, '_', '-')) = 'en'
                 LIMIT 1), '') AS translation,
             COALESCE(NULLIF(b.name_vi, ''), NULLIF(b.name_en, ''),
                      NULLIF(b.name_pali, ''), b.code) AS book_title
        FROM tipitaka_highlights h
        JOIN tipitaka_segments s
          ON s.id = h.segment_id AND s.book_id = h.book_id
        JOIN tipitaka_books b ON b.id = h.book_id
       ${bookId == null ? '' : 'WHERE h.book_id = ?'}
       ORDER BY h.updated_at DESC, h.id DESC
    ''', bookId == null ? const [] : [bookId]);
    return rows.map(TipitakaHighlight.fromMap).toList();
  }

  static Future<TipitakaHighlight?> getHighlight(
    Database db,
    int bookId,
    int segmentId,
  ) async {
    final rows = await getHighlights(db, bookId: bookId);
    for (final item in rows) {
      if (item.segmentId == segmentId) return item;
    }
    return null;
  }

  static Future<void> saveHighlight(
    Database db, {
    required int bookId,
    required int segmentId,
    required String color,
    String note = '',
  }) async {
    await db.insert(
      'tipitaka_highlights',
      {
        'book_id': bookId,
        'segment_id': segmentId,
        'color': color,
        'note': note.trim(),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> deleteHighlight(
    Database db,
    int bookId,
    int segmentId,
  ) async {
    await db.delete(
      'tipitaka_highlights',
      where: 'book_id = ? AND segment_id = ?',
      whereArgs: [bookId, segmentId],
    );
  }

  /// Finds another edition in the same canonical family (Mūla/ATT/Ṭīkā).
  static Future<TipitakaBook?> getParallelBook(
    Database db,
    TipitakaBook source, {
    String languageCode = 'en',
  }) async {
    final sourceIndex = source.catalogIndex;
    final books = await getBooksByCollection(
      db,
      source.collectionId,
      languageCode: languageCode,
    );
    final wanted = sourceIndex.editionCode == 'MUL'
        ? const ['ATT', 'TIK']
        : const ['MUL', 'ATT', 'TIK'];
    for (final edition in wanted) {
      for (final book in books) {
        final index = book.catalogIndex;
        if (book.id != source.id &&
            index.parallelFamilyCode == sourceIndex.parallelFamilyCode &&
            index.editionCode == edition) {
          return book;
        }
      }
    }
    return null;
  }

  static Future<int> getBookSegmentCount(Database db, int bookId) async {
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS n FROM tipitaka_segments WHERE book_id = ?',
      [bookId],
    );
    return _asInt(rows.first['n'], 0);
  }

  static Future<TipitakaSegment?> getSegmentAtOrder(
    Database db,
    int bookId,
    int orderIndex,
  ) async {
    final rows = await db.query(
      'tipitaka_segments',
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'order_index ASC, paragraph_no ASC, id ASC',
      limit: 1,
      offset: orderIndex < 0 ? 0 : orderIndex,
    );
    if (rows.isEmpty) return null;
    final enriched = await _withTranslations(db, rows);
    return TipitakaSegment.fromMap(enriched.first);
  }

  static Future<int?> getSegmentOrderIndex(Database db, int segmentId) async {
    final rows = await db.rawQuery('''
      SELECT COUNT(*) AS n
      FROM tipitaka_segments current_segment
      JOIN tipitaka_segments prior_segment
        ON prior_segment.book_id = current_segment.book_id
       AND (prior_segment.order_index < current_segment.order_index OR
            (prior_segment.order_index = current_segment.order_index AND
             prior_segment.id <= current_segment.id))
      WHERE current_segment.id = ?
    ''', [segmentId]);
    if (rows.isEmpty) return null;
    return (_asInt(rows.first['n'], 1) - 1).clamp(0, 1 << 30).toInt();
  }

  static Future<List<TipitakaSegment>> searchSegments(
    Database db,
    String query,
  ) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final like = '%$q%';
    final rows = await db.rawQuery('''
      SELECT DISTINCT s.*
      FROM tipitaka_segments s
      LEFT JOIN tipitaka_translations t ON t.segment_id = s.id
      WHERE s.pali_text LIKE ? OR s.translation_en LIKE ? OR
            s.translation_vi LIKE ? OR s.translation_my LIKE ? OR
            s.translation_th LIKE ? OR s.reference LIKE ? OR t.text LIKE ?
      ORDER BY s.order_index ASC, s.id ASC
      LIMIT 50
    ''', [like, like, like, like, like, like, like]);
    final enriched = await _withTranslations(db, rows);
    return enriched.map(TipitakaSegment.fromMap).toList();
  }
}
