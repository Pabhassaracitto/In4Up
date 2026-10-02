/// Cách lưu dữ liệu từ điển (I4U18-DICT-001).
enum DictStorageMode {
  /// import/copy toàn bộ bundle (mdx + mdd + css + asset) vào app storage.
  imported,

  /// link/index: CHỈ build index SQLite trong app, giữ nguyên file nguồn
  /// trong thư mục user — không copy dữ liệu lớn.
  linked,
}

/// Metadata cho 1 từ điển đã import
class DictInfo {
  final String id;
  final String name;
  final String? sourceLang;
  final String? targetLang;
  final int entryCount;
  final String dbPath;
  final String? resourcePath;
  final bool enabled;
  final DateTime importedAt;

  /// Chế độ lưu (mặc định imported cho manifest cũ).
  final DictStorageMode storageMode;

  /// Thư mục nguồn gốc khi [storageMode] == linked (để resolve asset/MDD
  /// lúc runtime và cảnh báo khi thư mục bị xoá/di chuyển).
  final String? sourceFolder;

  /// File .css đi kèm set (định dạng hiển thị) — path tuyệt đối.
  final List<String> cssPaths;

  /// Phần phụ bị thiếu lúc import (vd `.mdd (hình ảnh & âm thanh)`);
  /// từ điển vẫn tra được ở chế độ giảm cấp — UI hiện badge cảnh báo.
  final List<String> missingResources;

  const DictInfo({
    required this.id,
    required this.name,
    this.sourceLang,
    this.targetLang,
    required this.entryCount,
    required this.dbPath,
    this.resourcePath,
    this.enabled = true,
    required this.importedAt,
    this.storageMode = DictStorageMode.imported,
    this.sourceFolder,
    this.cssPaths = const [],
    this.missingResources = const [],
  });

  String get langPairLabel {
    final s = sourceLang?.toUpperCase() ?? '?';
    final t = targetLang?.toUpperCase() ?? '?';
    return '$s → $t';
  }

  bool get isLinked => storageMode == DictStorageMode.linked;

  /// Từ điển thiếu file phụ (vẫn dùng được ở chế độ giảm cấp).
  bool get hasMissingResources => missingResources.isNotEmpty;

  DictInfo copyWith({
    String? name,
    String? sourceLang,
    String? targetLang,
    int? entryCount,
    String? dbPath,
    String? resourcePath,
    bool? enabled,
    DictStorageMode? storageMode,
    String? sourceFolder,
    List<String>? cssPaths,
    List<String>? missingResources,
  }) =>
      DictInfo(
        id: id,
        name: name ?? this.name,
        sourceLang: sourceLang ?? this.sourceLang,
        targetLang: targetLang ?? this.targetLang,
        entryCount: entryCount ?? this.entryCount,
        dbPath: dbPath ?? this.dbPath,
        resourcePath: resourcePath ?? this.resourcePath,
        enabled: enabled ?? this.enabled,
        importedAt: importedAt,
        storageMode: storageMode ?? this.storageMode,
        sourceFolder: sourceFolder ?? this.sourceFolder,
        cssPaths: cssPaths ?? this.cssPaths,
        missingResources: missingResources ?? this.missingResources,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'source_lang': sourceLang,
        'target_lang': targetLang,
        'entry_count': entryCount,
        'db_path': dbPath,
        'resource_path': resourcePath,
        'enabled': enabled,
        'imported_at': importedAt.toIso8601String(),
        'storage_mode': storageMode.name,
        'source_folder': sourceFolder,
        'css_paths': cssPaths,
        'missing_resources': missingResources,
      };

  factory DictInfo.fromJson(Map<String, dynamic> json) => DictInfo(
        id: json['id'] as String,
        name: json['name'] as String,
        sourceLang: json['source_lang'] as String?,
        targetLang: json['target_lang'] as String?,
        entryCount: json['entry_count'] as int,
        dbPath: json['db_path'] as String,
        resourcePath: json['resource_path'] as String?,
        enabled: json['enabled'] as bool? ?? true,
        importedAt: DateTime.parse(json['imported_at'] as String),
        storageMode: json['storage_mode'] == 'linked'
            ? DictStorageMode.linked
            : DictStorageMode.imported,
        sourceFolder: json['source_folder'] as String?,
        cssPaths: (json['css_paths'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        missingResources: (json['missing_resources'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
      );
}
