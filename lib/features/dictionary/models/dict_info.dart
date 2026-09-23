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

  /// Phiên bản engine MDX (vd "2.0") — để hiện trên thẻ từ điển + chẩn đoán
  /// khi file dùng định dạng chưa hỗ trợ. Rỗng với dữ liệu import từ bản cũ.
  final String engineVersion;

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
    this.engineVersion = '',
  });

  String get langPairLabel {
    final s = sourceLang?.toUpperCase() ?? '?';
    final t = targetLang?.toUpperCase() ?? '?';
    return '$s → $t';
  }

  DictInfo copyWith({
    String? name,
    String? sourceLang,
    String? targetLang,
    int? entryCount,
    String? dbPath,
    String? resourcePath,
    bool? enabled,
    String? engineVersion,
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
        engineVersion: engineVersion ?? this.engineVersion,
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
        'engine_version': engineVersion,
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
        engineVersion: json['engine_version'] as String? ?? '',
      );
}
