import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';

import '../models/dict_info.dart';
import 'dict_db_service.dart';
import 'mdx_parser.dart';

/// Facade quản lý tất cả từ điển đã import
class DictionaryService {
  static DictionaryService? _instance;
  static DictionaryService get instance => _instance ??= DictionaryService._();
  DictionaryService._();

  final List<DictInfo> _dicts = [];
  bool _initialized = false;

  List<DictInfo> get dictionaries => List.unmodifiable(_dicts);
  List<DictInfo> get enabledDictionaries =>
      _dicts.where((d) => d.enabled).toList();

  /// Khởi tạo: đọc manifest + scan DB files
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
      } catch (_) {
        // DB lỗi → bỏ qua, không crash
      }
    }
    return results;
  }

  /// Tra prefix trên từ điển đầu tiên đang bật (autocomplete)
  Future<List<DictEntry>> lookupPrefix(String prefix, {int limit = 10}) async {
    await ensureInitialized();
    for (final dict in enabledDictionaries) {
      try {
        final entries = await DictDbService.lookupPrefix(
          dict.dbPath,
          prefix,
          limit: limit,
        );
        if (entries.isNotEmpty) return entries;
      } catch (_) {}
    }
    return [];
  }

  /// Import file .mdx (+ .mdd tùy chọn)
  /// Trả về DictInfo nếu thành công, null nếu lỗi
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

      // Tạo ID duy nhất từ tên file
      final fileName = mdxPath.split(Platform.pathSeparator).last;
      final dictId = md5.convert(utf8.encode(fileName)).toString().substring(0, 12);
      final dbPath = '${dictDir.path}/$dictId.dict.sqlite';
      final resourceDir = '${dictDir.path}/$dictId.resources';

      onProgress?.call(0.1, 'Đang đọc file MDX...');

      // Parse MDX → entries
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

      // Tạo DB + insert
      await DictDbService.createDb(dbPath);
      await DictDbService.insertBatch(dbPath, entries);

      onProgress?.call(0.85, 'Đang lưu resources...');

      // Copy MDD resources nếu có
      String? resPath;
      if (mddPath != null && File(mddPath).existsSync()) {
        final resDir = Directory(resourceDir);
        if (!resDir.existsSync()) {
          resDir.createSync(recursive: true);
        }
        // Copy MDD file vào resource dir
        final mddDest = '$resourceDir/${mddPath.split(Platform.pathSeparator).last}';
        await File(mddPath).copy(mddDest);
        resPath = resourceDir;
      }

      // Detect ngôn ngữ từ header MDX
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

      // Thêm vào danh sách + lưu manifest
      _dicts.add(info);
      await _saveManifest();

      onProgress?.call(1.0, 'Đã import $entryCount entries');
      return info;
    } catch (e) {
      onProgress?.call(1.0, 'Lỗi import: $e');
      return null;
    }
  }

  /// Bật/tắt từ điển
  Future<void> toggleDict(String dictId, bool enabled) async {
    final idx = _dicts.indexWhere((d) => d.id == dictId);
    if (idx < 0) return;
    _dicts[idx] = _dicts[idx].copyWith(enabled: enabled);
    await _saveManifest();
  }

  /// Xóa từ điển
  Future<void> deleteDict(String dictId) async {
    final idx = _dicts.indexWhere((d) => d.id == dictId);
    if (idx < 0) return;
    final dict = _dicts[idx];

    // Xóa DB file
    try {
      await DictDbService.deleteDb(dict.dbPath);
    } catch (_) {}

    // Xóa resource dir
    if (dict.resourcePath != null) {
      try {
        await Directory(dict.resourcePath!).delete(recursive: true);
      } catch (_) {}
    }

    _dicts.removeAt(idx);
    await _saveManifest();
  }

  /// Lấy manifest path
  Future<String> get _manifestPath async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/dictionaries/manifest.json';
  }

  /// Load manifest từ file
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
      // Kiểm tra DB files còn tồn tại
      _dicts.removeWhere((d) => !File(d.dbPath).existsSync());
    } catch (_) {
      // Manifest hỏng → reset
      _dicts.clear();
    }
  }

  /// Lưu manifest ra file
  Future<void> _saveManifest() async {
    try {
      final path = await _manifestPath;
      final file = File(path);
      if (!file.parent.existsSync()) {
        file.parent.createSync(recursive: true);
      }
      final json = _dicts.map((d) => d.toJson()).toList();
      await file.writeAsString(jsonEncode(json));
    } catch (_) {
      // Không crash nếu ghi lỗi
    }
  }
}
