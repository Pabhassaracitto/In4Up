/// Cách lưu dữ liệu từ điển (I4U18-DICT-001).
enum DictStorageMode {
  /// import/copy toàn bộ bundle (mdx + mdd + css + asset) vào app storage.
  imported,

  /// link/index: CHỈ build index SQLite trong app, giữ nguyên file nguồn
  /// trong thư mục user — không copy dữ liệu lớn.
  linked,
}

/// Metadata cho 1 từ điển đã import.
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

  /// Thư mục/SAF tree URI nguồn khi [storageMode] == linked.
  final String? sourceFolder;

  /// File .css đi kèm set (đường dẫn tuyệt đối hoặc SAF document URI).
  final List<String> cssPaths;

  /// SAF URI của MDX chính và các file thuộc bundle, nếu nguồn nằm trong SAF.
  final String? sourceMdxUri;
  final Map<String, String> sourceUris;

  /// Basename MDX nguồn và kiểu picker, dùng cho thao tác chọn lại nguồn.
  final String? sourceFileName;
  final bool sourceWasFolder;

  /// Nguồn SAF không còn truy cập được; index SQLite vẫn được giữ.
  final bool needsReselect;

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
    this.sourceMdxUri,
    this.sourceUris = const {},
    this.sourceFileName,
    this.sourceWasFolder = true,
    this.needsReselect = false,
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
    String? sourceMdxUri,
    Map<String, String>? sourceUris,
    String? sourceFileName,
    bool? sourceWasFolder,
    bool? needsReselect,
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
        sourceMdxUri: sourceMdxUri ?? this.sourceMdxUri,
        sourceUris: sourceUris ?? this.sourceUris,
        sourceFileName: sourceFileName ?? this.sourceFileName,
        sourceWasFolder: sourceWasFolder ?? this.sourceWasFolder,
        needsReselect: needsReselect ?? this.needsReselect,
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
        'source_mdx_uri': sourceMdxUri,
        'source_uris': sourceUris,
        'source_file_name': sourceFileName,
        'source_was_folder': sourceWasFolder,
        'needs_reselect': needsReselect,
        'missing_resources': missingResources,
      };

  factory DictInfo.fromJson(Map<String, dynamic> json) {
    final rawSourceUris = json['source_uris'];
    return DictInfo(
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
      sourceMdxUri: json['source_mdx_uri'] as String?,
      sourceUris: rawSourceUris is Map
          ? rawSourceUris.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            )
          : const {},
      sourceFileName: json['source_file_name'] as String?,
      sourceWasFolder: json['source_was_folder'] as bool? ?? true,
      needsReselect: json['needs_reselect'] as bool? ?? false,
      missingResources: (json['missing_resources'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}
