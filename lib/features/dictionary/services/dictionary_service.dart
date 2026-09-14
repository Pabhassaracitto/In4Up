import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';

import '../models/dict_entry.dart';
import '../models/dict_info.dart';
import 'dict_db_service.dart';
import 'mdx_parser.dart';

/// Facade quản lý tất cả từ điển đã import
class DictionaryService {
  static DictionaryService? _instance;
  static DictionaryService get instance =>
      _instance ??= DictionaryService._();
  DictionaryService._();

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

  /// Import file .mdx
  Future<DictInfo?> importMdx(
    String mdxPath, {
    String? mddPath,
    void Function(double progress, String message)? onProgress,
  }) async {
    await ensureInitialized();
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final dictDir = Directory('${appDir.path}/dictionaries');
      if (!dictDir.existsSync()) {
        dictDir.createSync(recursive: true);
      }

      final fileName = mdxPath.split(Platform.pathSeparator).last;
      final dictId =
          md5.convert(utf8.encode(fileName)).toString().substring(0, 12);
      final dbPath = '${dictDir.path}/$dictId.dict.sqlite';
      final resourceDir = '${dictDir.path}/$dictId.resources';

      onProgress?.call(0.1, 'Đang đọc file MDX...');

      final entries = <Map<String, dynamic>>[];
      int entryCount = 0;

      await for (final entry in MdxParser.parse(mdxPath, dictId: dictId)) {
        entries.add(entry.toMap());
        entryCount++;
        if (entryCount % 1000 == 0) {
          onProgress?.call(
            0.1 + (entryCount * 0.6 / 100000).clamp(0, 0.6),
            'Đang phân tích... $entryCount entries',
          );
        }
      }

      if (entries.isEmpty) {
        onProgress?.call(1.0, 'File MDX trống hoặc không đọc được');
        return null;
      }

      onProgress?.call(0.7, 'Đang lưu vào cơ sở dữ liệu...');

      await DictDbService.createDb(dbPath);
      await DictDbService.insertBatch(dbPath, entries);

      onProgress?.call(0.85, 'Đang lưu resources...');

      String? resPath;
      if (mddPath != null && File(mddPath).existsSync()) {
        final resDir = Directory(resourceDir);
        if (!resDir.existsSync()) {
          resDir.createSync(recursive: true);
        }
        final mddDest =
            '$resourceDir/${mddPath.split(Platform.pathSeparator).last}';
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
      );

      _dicts.add(info);
      await _saveManifest();

      onProgress?.call(1.0, 'Đã import $entryCount entries');
      return info;
    } catch (e) {
      onProgress?.call(1.0, 'Lỗi import: $e');
      return null;
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
}
