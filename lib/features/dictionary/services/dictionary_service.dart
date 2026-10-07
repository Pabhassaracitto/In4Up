import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';

import '../models/dict_entry.dart';
import '../models/dict_info.dart';
import 'dict_bundle_scanner.dart';
import 'dict_db_service.dart';
import 'dict_device_channel.dart';
import 'mdx_parser.dart';
import 'random_access_source.dart';

/// Kết quả import dictionary bundle (I4U18-DICT-001) — để UI hiển thị đúng
/// phần đã import + phần phụ bị thiếu (từ điển vẫn dùng được giảm cấp).
class DictImportOutcome {
  /// Các từ điển đã đăng ký thành công (1 folder có thể chứa nhiều MDX).
  final List<DictInfo> imported;

  /// Phần phụ thiếu của MỌI set (gộp, khử trùng lặp) — nhãn file + hậu quả.
  final List<String> missingParts;

  /// Lỗi tổng (không import được gì) — null khi [imported] không rỗng.
  final String? error;

  /// File .css/.mdd lẻ không ghép được set nào (thông tin thêm cho user).
  final List<String> strayCompanions;

  /// Source SAF died during import; UI should offer to pick it again.
  final bool needsReselect;

  const DictImportOutcome({
    this.imported = const [],
    this.missingParts = const [],
    this.error,
    this.strayCompanions = const [],
    this.needsReselect = false,
  });

  bool get isSuccess => imported.isNotEmpty;
}

/// Facade quản lý tất cả từ điển đã import
class DictionaryService {
  static DictionaryService? _instance;
  static DictionaryService get instance =>
      _instance ??= DictionaryService._();
  DictionaryService._();

  final List<DictInfo> _dicts = [];
  bool _initialized = false;

  /// Test seam (DICT-001 §8): ghi đè thư mục documents — chỉ set trong test,
  /// production luôn dùng path_provider.
  @visibleForTesting
  static Directory? documentsDirectoryOverride;

  /// Injectable source probe for deterministic revoked-URI tests on host CI.
  @visibleForTesting
  static Future<bool> Function(DictInfo)? linkedSourceAccessProbeOverride;

  /// Reset singleton cho test (kèm manifest đã nạp trong lần trước).
  @visibleForTesting
  static void resetForTest() {
    _instance?._dicts.clear();
    _instance?._initialized = false;
    _instance = null;
    linkedSourceAccessProbeOverride = null;
  }

  static Future<Directory> _appDocuments() async =>
      documentsDirectoryOverride ?? await getApplicationDocumentsDirectory();

  List<DictInfo> get dictionaries => List.unmodifiable(_dicts);
  List<DictInfo> get enabledDictionaries =>
      _dicts.where((d) => d.enabled).toList();

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;
    await _loadManifest();
  }

  /// Tra từ trên TẤT CẢ từ điển đang bật
  Future<List<DictEntry>> lookup(String word) async {
    await ensureInitialized();
    final results = <DictEntry>[];
    for (final dict in enabledDictionaries) {
      try {
        final entries = await DictDbService.lookup(dict.dbPath, word);
        results.addAll(entries);
      } catch (e) {
        // DB lỗi → bỏ qua
      }
    }
    return results;
  }

  /// Tra prefix (autocomplete)
  Future<List<DictEntry>> lookupPrefix(String prefix,
      {int limit = 10}) async {
    await ensureInitialized();
    for (final dict in enabledDictionaries) {
      try {
        final entries = await DictDbService.lookupPrefix(
          dict.dbPath,
          prefix,
          limit: limit,
        );
        if (entries.isNotEmpty) return entries;
      } catch (e) {
        // skip
      }
    }
    return [];
  }

  /// Import file .mdx đơn lẻ (đường cũ — giữ tương thích).
  ///
  /// Đi qua `importDictionaryBundle` ở chế độ copy để hành vi nhất quán.
  Future<DictInfo?> importMdx(
    String mdxPath, {
    String? mddPath,
    void Function(double progress, String message)? onProgress,
  }) async {
    final files = [mdxPath, if (mddPath != null) mddPath];
    final outcome = await importDictionaryBundle(
      absoluteFilePaths: files,
      rootPath: '',
      mode: DictStorageMode.imported,
      onProgress: onProgress,
    );
    if (outcome.error != null) {
      onProgress?.call(1.0, outcome.error!);
    }
    return outcome.imported.isEmpty ? null : outcome.imported.first;
  }

  /// Link/index một tập file SAF mà không materialize chúng thành bản sao.
  /// Paths giả chỉ dùng nội bộ scanner; parser đọc MDX bằng document URI.
  Future<DictImportOutcome> importSafDictionaryBundle({
    required List<DictDeviceFile> files,
    required DictStorageMode mode,
    String? treeUri,
    required bool sourceWasFolder,
    void Function(double progress, String message)? onProgress,
  }) async {
    const root = 'saf://in4up-dictionary';
    final safeFiles = <DictDeviceFile>[];
    final sourceUris = <String, String>{};
    final sourceSizes = <String, int>{};
    for (final file in files) {
      final normalized = DictBundleScanner.normSep(file.relativePath);
      final parts = normalized
          .split('/')
          .where((part) => part.isNotEmpty && part != '.')
          .toList();
      if (file.uri.isEmpty || parts.isEmpty || parts.any((part) => part == '..')) {
        continue;
      }
      final relativePath = parts.join('/');
      safeFiles.add(DictDeviceFile(
        uri: file.uri,
        name: file.name,
        relativePath: relativePath,
        sizeBytes: file.sizeBytes,
        extension: file.extension,
      ));
      sourceUris[relativePath] = file.uri;
      sourceSizes[relativePath] = file.sizeBytes;
    }

    return importDictionaryBundle(
      absoluteFilePaths: [for (final file in safeFiles) '$root/${file.relativePath}'],
      rootPath: root,
      mode: mode,
      sourceUris: sourceUris,
      sourceSizes: sourceSizes,
      sourceFolderOverride: treeUri,
      sourceWasFolder: sourceWasFolder,
      onProgress: onProgress,
    );
  }

  /// Import một NGUỒN từ điển (folder đã walk hoặc nhóm file user chọn) —
  /// I4U18-DICT-001: hai chế độ rõ ràng.
  ///
  /// - [DictStorageMode.imported]: copy mdx + mdd + css vào
  ///   `dictionaries/<id>.bundle/` rồi index — ổn định lâu dài.
  /// - [DictStorageMode.linked]: KHÔNG copy file nguồn (tránh nhân đôi dữ
  ///   liệu lớn); chỉ index SQLite trong app, mdd/css/asset resolve từ
  ///   thư mục gốc của user.
  ///
  /// [absoluteFilePaths]: path tuyệt đối của mọi file trong nguồn.
  /// [rootPath]: gốc folder khi chọn folder (để tính path tương đối giữ cấu
  /// trúc). Để rỗng → path tương đối = basename (multi-file pick phẳng).
  Future<DictImportOutcome> importDictionaryBundle({
    required List<String> absoluteFilePaths,
    required String rootPath,
    required DictStorageMode mode,
    Map<String, String> sourceUris = const {},
    Map<String, int> sourceSizes = const {},
    String? sourceFolderOverride,
    bool sourceWasFolder = true,
    void Function(double progress, String message)? onProgress,
  }) async {
    await ensureInitialized();
    if (absoluteFilePaths.isEmpty) {
      return const DictImportOutcome(error: 'Chưa chọn file/thư mục nào');
    }

    final relRoot = _norm(rootPath);
    // Giữ map tương đối → tuyệt đối: multi-file pick làm phẳng basename
    // nên không dựng lại path tuyệt đối được nếu không có map.
    final relToAbs = <String, String>{};
    final scanned = <DictScannedFile>[];
    for (final path in absoluteFilePaths) {
      final rel = _relativeToRoot(path, relRoot);
      if (rel.isEmpty || relToAbs.containsKey(rel)) {
        continue; // thư mục gốc / trùng basename — bỏ bản sau.
      }
      relToAbs[rel] = DictBundleScanner.normSep(path);
      scanned.add(
        DictScannedFile(rel, sizeBytes: sourceSizes[rel] ?? _safeLength(path)),
      );
    }
    final report = DictBundleScanner.scan(scanned);

    if (!report.hasSets) {
      final stray = report.strayCompanions.map((f) => f.name).join(', ');
      return DictImportOutcome(
        error: 'Không tìm thấy file .mdx nào trong nguồn đã chọn'
            '${stray.isEmpty ? '' : ' (có file lẻ: $stray)'}',
        strayCompanions: [
          for (final f in report.strayCompanions) f.name,
        ],
      );
    }

    final appDir = await _appDocuments();
    final dictDir = Directory('${appDir.path}/dictionaries');
    if (!dictDir.existsSync()) {
      dictDir.createSync(recursive: true);
    }

    final imported = <DictInfo>[];
    final missingAll = <String>{};
    var setIndex = 0;
    var needsReselect = false;
    for (final set in report.sets) {
      setIndex++;
      final progressBase = 0.1 + 0.85 * (setIndex - 1) / report.sets.length;
      final progressSpan = 0.85 / report.sets.length;
      onProgress?.call(progressBase, 'Index ${set.suggestedName}…');

      try {
        final info = await _importSet(
          set,
          relToAbs: relToAbs,
          relRoot: relRoot,
          dictDir: dictDir.path,
          mode: mode,
          sourceUris: sourceUris,
          sourceFolderOverride: sourceFolderOverride,
          sourceWasFolder: sourceWasFolder,
          onFileProgress: (p, message) =>
              onProgress?.call(progressBase + progressSpan * p, message),
        );
        if (info != null) {
          // Thay thế bản cũ cùng id (re-import sau khi user thêm file phụ).
          _dicts.removeWhere((d) => d.id == info.id);
          _dicts.add(info);
          imported.add(info);
          missingAll.addAll(info.missingResources);
        } else {
          missingAll.add('${set.suggestedName}: File .mdx không có entry nào');
        }
      } catch (e) {
        if (e is MdxParseException && e.needsReselect) {
          needsReselect = true;
        }
        missingAll.add('${set.suggestedName}: $e');
      }
    }

    await _saveManifest();
    onProgress?.call(
      1.0,
      imported.isEmpty
          ? 'Không import được từ điển nào'
          : 'Đã đăng ký ${imported.length} từ điển',
    );
    return DictImportOutcome(
      imported: imported,
      missingParts: missingAll.toList(),
      // Lỗi tổng kèm lý do parse cụ thể của set đầu tiên (AT #6: báo lỗi rõ).
      error: imported.isEmpty
          ? (missingAll.isEmpty
              ? 'Không import được từ điển nào'
              : 'Không import được từ điển nào: ${missingAll.first}')
          : null,
      strayCompanions: [
        for (final f in report.strayCompanions) f.name,
      ],
      needsReselect: needsReselect,
    );
  }

  /// Import 1 set (copy hoặc link) → DictInfo; null khi MDX rỗng/đọc lỗi.
  Future<DictInfo?> _importSet(
    DictSetCandidate set, {
    required Map<String, String> relToAbs,
    required String relRoot,
    required String dictDir,
    required DictStorageMode mode,
    required Map<String, String> sourceUris,
    required String? sourceFolderOverride,
    required bool sourceWasFolder,
    void Function(double progress, String message)? onFileProgress,
  }) async {
    String absOf(DictScannedFile f) =>
        relToAbs[f.path] ?? _absoluteFromRel(f.path, relRoot);

    final fileName = set.mdx.name;
    final dictId =
        md5.convert(utf8.encode(fileName)).toString().substring(0, 12);
    final dbPath = '$dictDir/$dictId.dict.sqlite';

    final absMdx = absOf(set.mdx);

    String? resourcePath;
    String? sourceFolder;
    final cssAbs = <String>[];

    if (mode == DictStorageMode.imported) {
      // Copy bundle vào app storage (mdx + mdd + css — asset lẻ không copy:
      // tài nguyên entry nằm trong MDD; file lẻ cùng folder thường không
      // liên quan, copy sẽ phình dữ liệu ngoài ý muốn).
      final bundleDir = Directory('$dictDir/$dictId.bundle');
      if (bundleDir.existsSync()) {
        bundleDir.deleteSync(recursive: true);
      }
      bundleDir.createSync(recursive: true);
      for (final f in [set.mdx, ...set.mddFiles, ...set.cssFiles]) {
        final abs = absOf(f);
        final dest = '${bundleDir.path}/${f.name}';
        try {
          await File(abs).copy(dest);
        } catch (_) {
          // File phụ copy lỗi → ghi nhận thiếu (không chặn cả set).
          continue;
        }
        if (DictBundleScanner.isCssName(f.name)) cssAbs.add(dest);
      }
      final copiedMdx = '${bundleDir.path}/${set.mdx.name}';
      resourcePath = bundleDir.path;
      return _indexAndRegister(
        set,
        mdxToParse: copiedMdx,
        dictId: dictId,
        dbPath: dbPath,
        resourcePath: resourcePath,
        storageMode: mode,
        cssPaths: cssAbs,
        langProbe: copiedMdx,
        sourceFileName: set.mdx.name,
        sourceWasFolder: sourceWasFolder,
      );
    }

    // LINK mode — không copy; index thẳng từ nguồn.
    final mdxUri = sourceUris[set.mdx.path];
    if (mdxUri != null) {
      sourceFolder = sourceFolderOverride;
      final linkedUris = <String, String>{
        for (final file in set.allFiles)
          if (sourceUris[file.path] != null) file.path: sourceUris[file.path]!,
      };
      for (final css in set.cssFiles) {
        final uri = sourceUris[css.path];
        if (uri != null) cssAbs.add(uri);
      }
      return _indexAndRegister(
        set,
        mdxToParse: null,
        mdxUri: mdxUri,
        dictId: dictId,
        dbPath: dbPath,
        resourcePath: sourceFolder,
        storageMode: mode,
        sourceFolder: sourceFolder,
        cssPaths: cssAbs,
        langProbe: '',
        sourceUris: linkedUris,
        sourceFileName: set.mdx.name,
        sourceWasFolder: sourceWasFolder,
      );
    }

    sourceFolder = set.folder.isEmpty
        ? (relRoot.isEmpty ? _parentOf(absMdx) : relRoot)
        : (relRoot.isEmpty ? set.folder : '$relRoot/${set.folder}');
    for (final f in set.cssFiles) {
      cssAbs.add(absOf(f));
    }
    return _indexAndRegister(
      set,
      mdxToParse: absMdx,
      dictId: dictId,
      dbPath: dbPath,
      resourcePath: sourceFolder,
      storageMode: mode,
      sourceFolder: sourceFolder,
      cssPaths: cssAbs,
      langProbe: absMdx,
      sourceFileName: set.mdx.name,
      sourceWasFolder: sourceWasFolder,
    );
  }

  /// Parse MDX → SQLite index rồi đăng ký DictInfo.
  Future<DictInfo?> _indexAndRegister(
    DictSetCandidate set, {
    required String? mdxToParse,
    String? mdxUri,
    required String dictId,
    required String dbPath,
    required DictStorageMode storageMode,
    String? resourcePath,
    String? sourceFolder,
    List<String> cssPaths = const [],
    required String langProbe,
    Map<String, String> sourceUris = const {},
    String? sourceFileName,
    bool sourceWasFolder = true,
    void Function(double progress, String message)? onFileProgress,
  }) async {
    // Build a replacement beside the current index. If the linked URI has
    // been revoked or parsing fails, the user's last working SQLite index
    // must remain available for lookup/reselection.
    final buildDbPath =
        '$dbPath.rebuilding-${DateTime.now().microsecondsSinceEpoch}';
    try {
      await DictDbService.deleteDb(buildDbPath);
    } catch (_) {}

    final entries = <Map<String, dynamic>>[];
    var entryCount = 0;
    final parseStream = mdxUri != null
        ? MdxParser.parseSafDocument(
            mdxUri,
            dictId: dictId,
            onProgress: onFileProgress,
          )
        : MdxParser.parse(
            mdxToParse ?? (throw StateError('Missing MDX source')),
            dictId: dictId,
            onProgress: onFileProgress,
          );
    try {
      await for (final entry in parseStream) {
        entries.add(entry.toMap());
        entryCount++;
        // Tránh quá tải RAM với từ điển lớn: flush theo batch.
        if (entries.length >= 4000) {
          await DictDbService.createDb(buildDbPath);
          await DictDbService.insertBatch(buildDbPath, entries);
          entries.clear();
        }
      }
      if (entries.isNotEmpty) {
        await DictDbService.createDb(buildDbPath);
        await DictDbService.insertBatch(buildDbPath, entries);
      }
    } catch (_) {
      // Parse/link lỗi giữa chừng chỉ dọn index tạm, không đụng tới bản cũ.
      try {
        await DictDbService.deleteDb(buildDbPath);
      } catch (_) {}
      rethrow;
    }
    if (entryCount == 0) {
      try {
        await DictDbService.deleteDb(buildDbPath);
      } catch (_) {}
      return null;
    }

    await _promoteBuiltIndex(buildDbPath, dbPath);

    Map<String, String?> langInfo;
    try {
      langInfo = mdxUri != null
          ? await MdxParser.detectLanguageFromSource(
              await SafRandomAccessSource.open(mdxUri),
              fileName: sourceFileName ?? set.mdx.name,
            )
          : await MdxParser.detectLanguage(langProbe);
    } catch (_) {
      // Metadata is optional. Keep the successfully-built index even if the
      // provider disappears between parse completion and this small probe.
      langInfo = const {};
    }
    return DictInfo(
      id: dictId,
      name: langInfo['name'] ?? set.suggestedName,
      sourceLang: langInfo['source_lang'],
      targetLang: langInfo['target_lang'],
      entryCount: entryCount,
      dbPath: dbPath,
      resourcePath: resourcePath,
      enabled: true,
      importedAt: DateTime.now(),
      storageMode: storageMode,
      sourceFolder: sourceFolder,
      cssPaths: cssPaths,
      sourceMdxUri: mdxUri,
      sourceUris: sourceUris,
      sourceFileName: sourceFileName ?? set.mdx.name,
      sourceWasFolder: sourceWasFolder,
      missingResources: set.missingParts,
    );
  }

  /// Replace the registered index only after the rebuilt SQLite file is
  /// complete. Keep a rollback file during the rename so a failed promotion
  /// cannot discard the previous lookup index.
  Future<void> _promoteBuiltIndex(String buildDbPath, String dbPath) async {
    final built = File(buildDbPath);
    if (!await built.exists()) {
      throw StateError('Dictionary index build did not create a database.');
    }

    final current = File(dbPath);
    final backupPath =
        '$dbPath.previous-${DateTime.now().microsecondsSinceEpoch}';
    var backedUp = false;
    if (await current.exists()) {
      await current.rename(backupPath);
      backedUp = true;
    }

    try {
      await built.rename(dbPath);
    } catch (_) {
      if (backedUp && !await current.exists()) {
        try {
          await File(backupPath).rename(dbPath);
        } catch (_) {
          // Preserve the backup if rollback itself is blocked by the platform.
        }
      }
      try {
        await DictDbService.deleteDb(buildDbPath);
      } catch (_) {}
      rethrow;
    }

    if (backedUp) {
      try {
        await File(backupPath).delete();
      } catch (_) {
        // The new index is active; orphaned backup cleanup is best effort.
      }
    }
  }

  /// Rebind an existing linked dictionary to a newly selected SAF source.
  /// Its SQLite index is deliberately untouched.
  Future<bool> relinkSafSource(
    String dictId, {
    required List<DictDeviceFile> files,
    required String? treeUri,
    required bool sourceWasFolder,
  }) async {
    await ensureInitialized();
    final dictIndex = _dicts.indexWhere((dict) => dict.id == dictId);
    if (dictIndex < 0) return false;
    final dict = _dicts[dictIndex];
    final sourceName = dict.sourceFileName?.toLowerCase();
    if (sourceName == null || sourceName.isEmpty) return false;

    final normalizedFiles = <DictDeviceFile>[];
    for (final file in files) {
      final path = DictBundleScanner.normSep(file.relativePath);
      final parts = path
          .split('/')
          .where((part) => part.isNotEmpty && part != '.')
          .toList();
      if (file.uri.isEmpty || parts.isEmpty || parts.any((part) => part == '..')) {
        continue;
      }
      normalizedFiles.add(DictDeviceFile(
        uri: file.uri,
        name: file.name,
        relativePath: parts.join('/'),
        sizeBytes: file.sizeBytes,
        extension: file.extension,
      ));
    }
    final report = DictBundleScanner.scan([
      for (final file in normalizedFiles)
        DictScannedFile(file.relativePath, sizeBytes: file.sizeBytes),
    ]);
    DictSetCandidate? match;
    for (final candidate in report.sets) {
      if (candidate.mdx.name.toLowerCase() == sourceName) {
        match = candidate;
        break;
      }
    }
    if (match == null) return false;

    final uriByPath = <String, String>{
      for (final file in normalizedFiles) file.relativePath: file.uri,
    };
    final linkedUris = <String, String>{
      for (final file in match.allFiles)
        if (uriByPath[file.path] != null) file.path: uriByPath[file.path]!,
    };
    final mdxUri = uriByPath[match.mdx.path];
    if (mdxUri == null) return false;

    _dicts[dictIndex] = dict.copyWith(
      sourceFolder: treeUri,
      resourcePath: treeUri,
      cssPaths: [
        for (final css in match.cssFiles)
          if (uriByPath[css.path] != null) uriByPath[css.path]!,
      ],
      sourceMdxUri: mdxUri,
      sourceUris: linkedUris,
      sourceFileName: match.mdx.name,
      sourceWasFolder: sourceWasFolder,
      needsReselect: false,
      missingResources: match.missingParts,
    );
    await _saveManifest();
    return true;
  }

  Future<void> toggleDict(String dictId, bool enabled) async {
    final idx = _dicts.indexWhere((d) => d.id == dictId);
    if (idx < 0) return;
    _dicts[idx] = _dicts[idx].copyWith(enabled: enabled);
    await _saveManifest();
  }

  Future<void> deleteDict(String dictId) async {
    final idx = _dicts.indexWhere((d) => d.id == dictId);
    if (idx < 0) return;
    final dict = _dicts[idx];

    try {
      await DictDbService.deleteDb(dict.dbPath);
    } catch (e) {
      // skip
    }

    // Imported resourcePath is always the app-owned bundle created by
    // _importSet.  Do not check for a literal '/' here: Windows stores this
    // path with backslashes, so the old check leaked every bundle on Windows.
    if (dict.resourcePath != null && !dict.isLinked) {
      try {
        final appDir = await _appDocuments();
        final dictionariesRoot = Directory(
          '${appDir.path}${Platform.pathSeparator}dictionaries',
        ).absolute.path;
        final resourcePath = Directory(dict.resourcePath!).absolute.path;
        final isOwned = resourcePath == dictionariesRoot ||
            resourcePath.startsWith(
              '$dictionariesRoot${Platform.pathSeparator}',
            );
        if (isOwned) {
          await Directory(resourcePath).delete(recursive: true);
        }
      } catch (e) {
        // skip
      }
    }

    _dicts.removeAt(idx);
    await _saveManifest();
  }

  /// Revalidate linked sources without deleting the local SQLite index.
  /// Android links are checked by opening the persisted SAF document URI;
  /// filesystem links use the original path.
  Future<List<DictInfo>> refreshLinkedSources() async {
    await ensureInitialized();
    var changed = false;
    for (var i = 0; i < _dicts.length; i++) {
      final dict = _dicts[i];
      if (!dict.isLinked) continue;

      bool accessible;
      final testProbe = linkedSourceAccessProbeOverride;
      if (testProbe != null) {
        accessible = await testProbe(dict);
      } else if (dict.sourceMdxUri != null &&
          dict.sourceMdxUri!.startsWith('content://')) {
        accessible = await DictDeviceChannel.isDocumentAccessible(
          dict.sourceMdxUri!,
        );
      } else if (dict.sourceFolder != null &&
          dict.sourceFolder!.startsWith('content://')) {
        // Old/incomplete SAF manifest: no stable MDX URI means reselect rather
        // than guessing a filesystem path from a content URI.
        accessible = false;
      } else if (dict.sourceFolder != null && dict.sourceFileName != null) {
        accessible = File(
          '${dict.sourceFolder}${Platform.pathSeparator}${dict.sourceFileName}',
        ).existsSync();
      } else if (dict.sourceFolder != null) {
        accessible = Directory(dict.sourceFolder!).existsSync();
      } else {
        // A linked manifest without any durable source locator is unusable;
        // keep its index but ask the user to reselect a source.
        accessible = false;
      }

      if (dict.needsReselect != !accessible) {
        _dicts[i] = dict.copyWith(needsReselect: !accessible);
        changed = true;
      }
    }
    if (changed) await _saveManifest();
    return dictionaries;
  }

  Future<String> get _manifestPath async {
    final appDir = await _appDocuments();
    return '${appDir.path}/dictionaries/manifest.json';
  }

  Future<void> _loadManifest() async {
    try {
      final path = await _manifestPath;
      final file = File(path);
      if (!file.existsSync()) return;
      final content = await file.readAsString();
      final List<dynamic> json = jsonDecode(content);
      _dicts.clear();
      for (final item in json) {
        _dicts.add(DictInfo.fromJson(item as Map<String, dynamic>));
      }
      _dicts.removeWhere((d) => !File(d.dbPath).existsSync());
    } catch (e) {
      _dicts.clear();
    }
  }

  Future<void> _saveManifest() async {
    try {
      final path = await _manifestPath;
      final file = File(path);
      if (!file.parent.existsSync()) {
        file.parent.createSync(recursive: true);
      }
      final json = _dicts.map((d) => d.toJson()).toList();
      await file.writeAsString(jsonEncode(json));
    } catch (e) {
      // skip
    }
  }

  // ── Path helpers (thuần) ──────────────────────────────────────────────

  static String _norm(String path) => path.replaceAll('\\', '/');

  /// Path tương đối (posix) so với root; root rỗng ⇒ basename (flat pick).
  static String _relativeToRoot(String absolutePath, String relRoot) {
    final norm = _norm(absolutePath);
    if (relRoot.isEmpty) {
      final i = norm.lastIndexOf('/');
      return i < 0 ? norm : norm.substring(i + 1);
    }
    if (norm == relRoot) return '';
    if (norm.startsWith('$relRoot/')) {
      return norm.substring(relRoot.length + 1);
    }
    // File ngoài root (multi-file pick lạc folder) → dùng basename.
    final i = norm.lastIndexOf('/');
    return i < 0 ? norm : norm.substring(i + 1);
  }

  /// Dựng path tuyệt đối từ path tương đối của scanner.
  static String _absoluteFromRel(String relPath, String relRoot) {
    if (relRoot.isEmpty) return relPath;
    if (relPath.startsWith('/')) return relPath;
    return '$relRoot/$relPath';
  }

  static String _parentOf(String path) {
    final norm = _norm(path);
    final i = norm.lastIndexOf('/');
    return i < 0 ? '' : norm.substring(0, i);
  }

  static int _safeLength(String path) {
    try {
      return File(path).lengthSync();
    } catch (_) {
      return 0;
    }
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
