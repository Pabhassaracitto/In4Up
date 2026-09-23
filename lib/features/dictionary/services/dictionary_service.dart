import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';

import '../models/dict_entry.dart';
import '../models/dict_import_result.dart';
import '../models/dict_info.dart';
import 'dict_db_service.dart';
import 'mdx_parser.dart';

/// Facade quản lý tất cả từ điển đã import
class DictionaryService {
  static DictionaryService? _instance;
  static DictionaryService get instance =>
      _instance ??= DictionaryService._();
  DictionaryService._();

  /// Số entry ghi vào SQLite mỗi batch — batch thay vì insert từng dòng
  /// (100k entry: từ nhiều phút xuống vài giây).
  static const int _insertBatchSize = 500;

  /// Tiền tố redirect của MDX: `@@@LINK=headword` (entry trỏ sang entry khác).
  static const String _linkPrefix = '@@@LINK=';

  final List<DictInfo> _dicts = [];
  bool _initialized = false;

  List<DictInfo> get dictionaries => List.unmodifiable(_dicts);
  List<DictInfo> get enabledDictionaries =>
      _dicts.where((d) => d.enabled).toList();

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;
    await _loadManifest();
  }

  /// Tra từ trên TẤT CẢ từ điển đang bật.
  ///
  /// Tự theo redirect `@@@LINK=` (tối đa 3 bước) — nếu không, rất nhiều entry
  /// trong MDX thật chỉ hiện đúng chuỗi `@@@LINK=…` thay vì nghĩa.
  Future<List<DictEntry>> lookup(String word) async {
    await ensureInitialized();
    final query = word.trim();
    if (query.isEmpty) return const [];

    final results = <DictEntry>[];
    for (final dict in enabledDictionaries) {
      try {
        final entries = await DictDbService.lookup(dict.dbPath, query);
        for (final entry in entries) {
          results.add(await _resolveLinks(dict, entry, 0));
        }
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
    final query = prefix.trim();
    if (query.isEmpty) return const [];
    for (final dict in enabledDictionaries) {
      try {
        final entries = await DictDbService.lookupPrefix(
          dict.dbPath,
          query,
          limit: limit,
        );
        if (entries.isEmpty) continue;
        final resolved = <DictEntry>[];
        for (final entry in entries) {
          resolved.add(await _resolveLinks(dict, entry, 0));
        }
        return resolved;
      } catch (e) {
        // skip
      }
    }
    return [];
  }

  /// Đổi `@@@LINK=đích` thành entry đích (tối đa [depth] 3 bước).
  Future<DictEntry> _resolveLinks(DictInfo dict, DictEntry entry, int depth) async {
    final raw = entry.definition.trim();
    if (depth >= 3 || !raw.startsWith(_linkPrefix)) return entry;
    final target = raw.substring(_linkPrefix.length).trim();
    if (target.isEmpty) return entry;
    try {
      final redirected = await DictDbService.lookup(dict.dbPath, target);
      if (redirected.isEmpty) return entry;
      return _resolveLinks(
        dict,
        DictEntry(
          headword: entry.headword,
          definition: redirected.first.definition,
          phonetic: redirected.first.phonetic,
          audioPath: redirected.first.audioPath,
          partOfSpeech: redirected.first.partOfSpeech,
          dictId: entry.dictId,
        ),
        depth + 1,
      );
    } catch (e) {
      return entry;
    }
  }

  /// Import file .mdx đã nằm trong bộ nhớ app (xem [DictImportService]).
  ///
  /// Trả [DictImportResult] — KHÔNG bao giờ trả null im lặng: mọi lỗi đều có
  /// thông báo để UI hiện ra (fix "chọn file xong vẫn hiện chưa có từ điển").
  Future<DictImportResult> importMdx(
    String mdxPath, {
    String? mddPath,
    String? displayName,
    void Function(double progress, String message)? onProgress,
  }) async {
    await ensureInitialized();
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final dictDir = Directory(p.join(appDir.path, 'dictionaries'));
      if (!dictDir.existsSync()) {
        dictDir.createSync(recursive: true);
      }

      final fileName = displayName ?? p.basename(mdxPath);
      final dictId =
          md5.convert(utf8.encode(fileName)).toString().substring(0, 12);
      final dbPath = p.join(dictDir.path, '$dictId.dict.sqlite');
      final resourceDir = p.join(dictDir.path, '$dictId.resources');

      onProgress?.call(0.03, 'Đang đọc header MDX…');

      // Đọc header trước: phát hiện sớm file hỏng / mã hóa / engine 3 để báo
      // lỗi rõ thay vì "parse xong mới thấy 0 entry".
      final header = await MdxParser.readHeader(mdxPath);

      onProgress?.call(0.08, 'Đang đọc mục từ…');

      final entries = <Map<String, dynamic>>[];
      var entryCount = 0;
      var lastReport = 0;

      await for (final entry in MdxParser.parse(mdxPath, dictId: dictId)) {
        entries.add(entry.toMap());
        entryCount++;
        if (entryCount - lastReport >= 2000) {
          lastReport = entryCount;
          onProgress?.call(0.1 + (0.5 * (entryCount / 200000)).clamp(0, 0.5),
              'Đang đọc mục từ… $entryCount');
        }
      }

      if (entries.isEmpty) {
        return const DictImportResult.failure(
          'File MDX không có mục từ nào (file rỗng hoặc sai định dạng).',
        );
      }

      onProgress?.call(0.65, 'Đang lưu $entryCount mục từ…');

      // Import lại cùng file ⇒ thay thế, không tạo bản trùng.
      final existingIndex = _dicts.indexWhere((d) => d.id == dictId);
      if (existingIndex >= 0) {
        await DictDbService.deleteDb(dbPath);
      }

      await DictDbService.createDb(dbPath);
      await DictDbService.insertBatch(dbPath, entries,
          batchSize: _insertBatchSize, onProgress: (done, total) {
        onProgress?.call(
          0.65 + (0.3 * (done / (total == 0 ? 1 : total))),
          'Đang lưu… $done/$total',
        );
      });

      onProgress?.call(0.95, 'Đang lưu tài nguyên…');

      String? resPath;
      if (mddPath != null && File(mddPath).existsSync()) {
        final resDir = Directory(resourceDir);
        if (!resDir.existsSync()) {
          resDir.createSync(recursive: true);
        }
        final mddDest = p.join(resourceDir, p.basename(mddPath));
        await File(mddPath).copy(mddDest);
        resPath = resourceDir;
      }

      final langInfo = await MdxParser.detectLanguage(mdxPath);

      final info = DictInfo(
        id: dictId,
        name: langInfo['name'] ?? fileName.replaceAll('.mdx', ''),
        sourceLang: langInfo['source_lang'],
        targetLang: langInfo['target_lang'],
        entryCount: entryCount,
        dbPath: dbPath,
        resourcePath: resPath,
        enabled: true,
        importedAt: DateTime.now(),
        engineVersion: header.version.toString(),
      );

      if (existingIndex >= 0) {
        _dicts[existingIndex] = info;
      } else {
        _dicts.add(info);
      }
      await _saveManifest();

      onProgress?.call(1.0, 'Đã import $entryCount mục từ');
      return DictImportResult.success(info);
    } on MdxException catch (e) {
      // Lỗi định dạng đã có thông báo rõ cho người dùng.
      return DictImportResult.failure(e.message);
    } catch (e) {
      return DictImportResult.failure('Lỗi import: $e');
    }
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

    if (dict.resourcePath != null) {
      try {
        await Directory(dict.resourcePath!).delete(recursive: true);
      } catch (e) {
        // skip
      }
    }

    _dicts.removeAt(idx);
    await _saveManifest();
  }

  Future<String> get _manifestPath async {
    final appDir = await getApplicationDocumentsDirectory();
    return p.join(appDir.path, 'dictionaries', 'manifest.json');
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
}
